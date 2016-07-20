/*
 * Spdylay - SPDY Library
 *
 * Copyright (c) 2012 Tatsuhiro Tsujikawa
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */
/*
 * This program is written to show how to use Spdylay API in C and
 * intentionally made simple.
 */
#include <stdint.h>
#include <stdarg.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <assert.h>
#include <pthread.h>
#include <time.h>
#include <sys/time.h>
#include <spdylay/spdylay.h>

#include <openssl/ssl.h>
#include <openssl/err.h>

#include <sys/times.h>
#include <sys/resource.h>

/**
 * quick start: for full register and listen mode.
 *    ./spdycli -v -n1 -f -l
 * To push:
 *    appserver/pushcurl.py cli-id push-id "hello world"
 */

/*
 * lib/spdylay_session.c
 *  spdylay_session_process_ctrl_frame()
 *  spdylay_session_on_syn_stream_received()
    spdylay_session_get_stream_user_data(session, stream_id);
 *
 * recv data:
 *  spdylay_session_mem_recv
 */

/**
 * server push stream,
 *   spdylay_session_open_stream, stream_user_data is set to NULL.
 *   as server push stream is considered one shot transaction.
 */

/* spdy_frame_type
    SPDYLAY_SYN_STREAM = 1,
    SPDYLAY_SYN_REPLY = 2,
    SPDYLAY_RST_STREAM = 3,
    SPDYLAY_SETTINGS = 4,
    SPDYLAY_NOOP = 5,
    SPDYLAY_PING = 6,
    SPDYLAY_GOAWAY = 7,
    SPDYLAY_HEADERS = 8,
    SPDYLAY_WINDOW_UPDATE = 9,
    SPDYLAY_CREDENTIAL = 10
*/


/**
 * this section contains global flag to indicate how client should behave.
 * different unit test uses different flags.
 */
int localhost = 0;
int unitmode = 0;
int registermode = 0;
int listenmode = 0;
int fullmode = 0;  // indicate client will do full flow from registration to push listen to push ack
int refreshmode = 0; // refresh api.
// -1, no retry; default 0 = exponential, 1 = random, >1 fix at value
int backoff = -1;

int sequentialId = 0; // use sequential Id for app push test, when this enabled, can only run one instance
int unauthorizedlisten = 0;  // client should perform unauthorized listen test

int verbose = 0;      // default not verbose
#define vbprintf(format, ...) do {  \
  if(verbose) {                     \
    fprintf(stdout, format, ##__VA_ARGS__); \
  }                                 \
}while(0)


enum {
  IO_NONE,
  WANT_READ,
  WANT_WRITE
};

struct Connection {
  SSL *ssl;
  spdylay_session *session;
  /* WANT_READ if SSL connection needs more input; or WANT_WRITE if it
     needs more output; or IO_NONE. This is necessary because SSL/TLS
     re-negotiation is possible at any time. Spdylay API offers
     similar functions like spdylay_session_want_read() and
     spdylay_session_want_write() but they do not take into account
     SSL connection. */
  int want_io;
};

struct Request {
  char *host;
  uint16_t port;
  /* In this program, path contains query component as well. */
  char *path;
  /* This is the concatenation of host and port with ":" in
     between. */
  char *hostport;
  /* Stream ID for this request. */
  int32_t stream_id;
  /* The gzip stream inflater for the compressed response. */
  spdylay_gzip *inflater;
};

struct URI {
  const char *host;
  size_t hostlen;
  uint16_t port;
  /* In this program, path contains query component as well. */
  const char *path;
  size_t pathlen;
  const char *hostport;
  size_t hostportlen;
};


/**
 * struct to encapsulate more thread local data
 */
struct ThreadUri {
    int retries;            // num of retries
    int pingFrames;
    struct Connection * connection;
    struct Request req;
    int32_t assoc_stream_id;
    struct URI uri;  // per client uri struct
    char url[256];   // parse_uri(&uri, url)
    char clientId[256];  // clientId
    char pushId[256];    // pushId
    char pushData[1024];
};
// common thread local key namespace.
pthread_key_t tkey;
int32_t stream_id = 0;
static void initSpdySession(struct ThreadUri* pthrduri);
static char* getClientId(char * data, char *retbuf);
static char* getPushId(char * data, char *retbuf);
static void submit_request_pushack(spdylay_session *session, struct Request *req, char * pushdata, int len);
static void submit_request_listen(struct Connection *connection, struct Request *req, char *clientId, char *pushId);
static void submit_request_listenV2(struct Connection *connection, struct Request *req, char *clientId, char *pushId);
static void submit_request_refresh(struct Connection *connection, struct Request *req, char *clientId, char *pushId);
static void updateClientPushId(struct ThreadUri *, char * );
static void listenAfterObtainPuid(struct ThreadUri *);
static void submitPingOrRefresh();   // submit the ping frame
static void request_init(struct Request *req, const struct URI *uri);
static void retryBackoff(int retries, int max);
static int randSleep(int max);



static char* register_meta = "{ \
  \"buildVersion\":\"1.4.1\", \
  \"fingerprint\":\"...\", \
  \"model\":\"M9300\", \
  \"network\":\"sprint\", \
  \"osVersion\":\"Android_2.1\", \
  \"releaseVersion\":3 \
}";


/**
 * sleep randomly within max seconds
 * we need to disable sleep for load test.
 */
static int randSleep(int max){
    int sleeptm;
    sleeptm = rand()/(RAND_MAX/max+1);
    //sleeptm = 5;   // 5 seconds
    //vbprintf("sleeping randomly %d before doing anything\n", sleeptm);
    //sleep(sleeptm);   // sleep random between [1-5] seconds to cause timeout
    return sleeptm;
}

/**
 * retry connection backoff strategy.
 */
static void retryBackoff(int retries, int max){  // max 10 seconds ?
    int base = 1;   // wait base 1 waiting for server
    int sleeptm;

    if(backoff == 0){   // exponential backoff, use triangular number.
        sleeptm = (retries+1)*retries/2;
    }else if(backoff == 1){  // random backoff
        sleeptm = rand()/(RAND_MAX/max+1);
    }else if(backoff == 2){     // 2, no backoff
        sleeptm = 0;
    }else{                      // fixed backoff
        sleeptm = backoff;
    }

    if(sleeptm == 0)
        return;

    sleeptm += base;
    vbprintf("----- retry connection after backoff %d -------\n", sleeptm);
    // sleep int seconds
    sleep(sleeptm);   // sleep random between [1-5] seconds to cause timeout
}

/**
 * submit ping frame
 */
static void submitPingOrRefresh(){
  int rv;
  struct ThreadUri * pthrduri = NULL;
  pthrduri = (struct ThreadUri*)pthread_getspecific(tkey);

  // XXX deprecated send refresh request; refresh should not be sent
  // when we already connected to server.
  // if(pthrduri->pingFrames % 2 && pthrduri->pingFrames < 2){
  //   vbprintf("%s\t submit refresh request \n", pthrduri->clientId);
  //   submit_request_refresh(pthrduri->connection, &pthrduri->req, pthrduri->clientId, pthrduri->pushId);
  // }
  // connection has sessions.
  rv = spdylay_submit_ping(pthrduri->connection->session);
  pthrduri->pingFrames += 1;

  vbprintf("%s\t submit ping frame : %d ret=%d\n", pthrduri->clientId, pthrduri->pingFrames, rv);
}


/**
 * get client id from json returned
 * {"client_id":"clid-3-1","push_id":"puid-3-1"}
 */
static char* getClientId(char * data, char *retbuf){
    char *p, *q;
    int offset;

    p = strstr(data, "client_id\":");
    offset = strlen("client_id\":\"");
    p += offset;  // mov to the beg of json value

    q = strstr(p, "\"");  // idx to the end of
    snprintf(retbuf, q-p+1, "%s", p);  // sz = ptr(idx)-diff + 1

    vbprintf("on server data, get clientId: %s data: %s\n", retbuf, data);
    return retbuf;
}

/**
 * get push id from json returned
 * {"client_id":"clid-3-1","push_id":"puid-3-1"}
 */
static char* getPushId(char * data, char *retbuf){
    char *p, *q;
    int offset;

    p = strstr(data, "push_id\":");
    offset = strlen("push_id\":\"");
    p += offset;  // mov to the beg of json value

    q = strstr(p, "\"");  // idx to the end of
    snprintf(retbuf, q-p+1, "%s", p);  // sz = ptr(idx)-diff + 1

    vbprintf("on server data, get pushId: %s data: %s\n", retbuf, data);
    return retbuf;
}

/**
 * after register request API, we get push id in on_data_chunk_recv_callback.
 * {"client_id":"clid-3-1","push_id":"puid-3-1"}
 */
static void updateClientPushId(struct ThreadUri * pthrduri, char * data) {
    int offset;
    char *p, *q;

    // when used for unit test, do not parse client id
    if(unitmode){ exit(0); }

    if(fullmode){
        // do I need to reset pthrduri->url ?
        // already got client id and push id from register api.
        if(strlen(pthrduri->clientId) > 0){
            vbprintf("on server data, already got clientId: %s  thread_id %lld \n", pthrduri->clientId, pthread_self());
            return;
        }

        // first, get client_id and push_id
        getClientId(data, pthrduri->clientId);
        getPushId(data, pthrduri->pushId);
        listenAfterObtainPuid(pthrduri);
        return;
    }

    // refresh mode, the same as register, call listen after getting push id
    if(refreshmode){
        if(strlen(pthrduri->pushId) > 0){
            vbprintf("on server data, already got pushId: %s  %lld \n", pthrduri->pushId, pthread_self());
            return;
        }

        // first, get client_id and push_id
        getClientId(data, pthrduri->clientId);
        getPushId(data, pthrduri->pushId);
        listenAfterObtainPuid(pthrduri);
        return;
    }
}

/**
 * submit listen request after getting pushId
 */
static void listenAfterObtainPuid(struct ThreadUri *pthrduri ){
    submit_request_listenV2(pthrduri->connection,
                          &pthrduri->req,
                          pthrduri->clientId,
                          pthrduri->pushId);
}


/**
 * callback to be invoked when assemble frame along with spdy request.
 */
static ssize_t data_source_read_callback(
        spdylay_session *session,
        int32_t stream_id,
        uint8_t *buf,
        size_t len,
        int *eof,
        spdylay_data_source *source,
        void *user_data) {

  size_t wlen;
  struct ThreadUri * pthrduri = NULL;
  char *p = NULL;
  char *pdata = NULL;
  char ack[1024];
  int offset, sz;

  memset(ack, 0, sizeof(ack));
  pthrduri = (struct ThreadUri*)pthread_getspecific(tkey);
  pdata = pthrduri->pushData;
  pdata = source->ptr;

  p = strstr(pdata, "\"data\":");
  offset = p - pdata;
  offset += 7;  // len("data":)

  p = ack;
  snprintf(ack, offset+1, "%s", pdata);  // incl trailing null
  p += offset;
  //sprintf(p, "\"[ %d %s ]\"}", stream_id, pthrduri->pushId);
  sprintf(p, "\"[ %d ]\"}", stream_id);

  // passed in buf is a block len=4096
  memset(buf, 0, len);
  wlen = strlen(ack);
  strcpy(buf, ack);
  *eof = 1;

  vbprintf("submit_request_paushack : filling data with read_callback : stream_id : %d, ack %s \
            cliId %s pushId %s pushData %s ack %s\n", \
            stream_id, ack, pthrduri->clientId, pthrduri->pushId, pdata, buf);

  free(source->ptr);  // free mem to avoid leak
  return wlen;
}

/**
 * callback to be invoked when assemble frame along with spdy request.
 */
static ssize_t register_data_source_read_callback(
        spdylay_session *session,
        int32_t stream_id,
        uint8_t *buf,
        size_t len,
        int *eof,
        spdylay_data_source *source,
        void *user_data) {

  size_t wlen;
  struct ThreadUri * pthrduri = NULL;
  char *p = NULL;
  char *pdata = NULL;
  char ack[1024];
  int offset, sz;

  // memset(ack, 0, sizeof(ack));
  //pthrduri = (struct ThreadUri*)pthread_getspecific(tkey);
 
  pdata = source->ptr;
  
  // passed in buf is a block len=4096
  //memset(buf, 0, len);
  wlen = strlen(pdata);
  strcpy(buf, pdata);
  *eof = 1;

  // vbprintf("register_data_source_read_callback : filling data with read_callback : \
  //           stream_id : %d, post data %s buf %s \n", \
  //           stream_id, pdata, buf);

  free(source->ptr);  // free mem to avoid leak
  return wlen;
}


/**
 * refresh data source provider.
 */
static ssize_t refresh_data_source_read_callback(
        spdylay_session *session,
        int32_t stream_id,
        uint8_t *buf,
        size_t len,
        int *eof,
        spdylay_data_source *source,
        void *user_data) {

  size_t wlen = 0;
  struct ThreadUri * pthrduri = NULL;
  char *p = NULL;
  char *pdata = NULL;
  char ack[1024];
  int offset, sz;

  pthrduri = (struct ThreadUri*)pthread_getspecific(tkey);
  memset(ack, 0, sizeof(ack));
  pdata = pthrduri->pushData;
  char * jsonstr = "{\"push_id\":\"";

  strcpy(ack, jsonstr);
  strcat(ack, pthrduri->pushId);
  strcat(ack, "\"}");
  vbprintf("refresh pushId : %s\n", ack);

  memset(buf, 0, len);
  wlen = strlen(ack);
  strcpy(buf, ack);
  *eof = 1;

  return wlen;
}

/**
 * create timer to periodically submit PING frame to server
 */
#define CLOCKID CLOCK_REALTIME
#define SIG SIGRTMIN

#define errExit(msg)  do { perror(msg); exit(EXIT_FAILURE); \
                      } while (0)


static void print_siginfo(siginfo_t *si) {
    timer_t *tidp;
    int or;

    tidp = si->si_value.sival_ptr;
    //vbprintf("    sival_ptr = %p; ", si->si_value.sival_ptr);
    vbprintf(" timer_id  *sival_ptr = 0x%lx\n", (long) *tidp);

    or = timer_getoverrun(*tidp);
    if (or == -1)
        errExit("timer_getoverrun");
    else
        vbprintf("    overrun count = %d\n", or);
}


static void timerhandler(int sig, siginfo_t *si, void *uc) {
    /* Note: calling printf() from a signal handler is not
        strictly correct, since printf() is not async-signal-safe;
        see signal(7) */

    struct ThreadUri * pthrduri = NULL;
    print_siginfo(si);

    //signal(sig, SIG_IGN);   // ack the signal will clear the timer
    pthrduri = (struct ThreadUri*)pthread_getspecific(tkey);
    vbprintf("timeout signal : %d at %lld %x\n", sig, pthread_self(), pthrduri);
}

static void createTimer() {
    timer_t timerid;
    struct sigevent sev;
    struct itimerspec its;
    long long freq_nanosecs;
    sigset_t mask;
    struct sigaction sa;

    /* Establish handler for timer signal */
    //vbprintf("Establishing handler for signal %d\n", SIG);
    sa.sa_flags = SA_SIGINFO;
    sa.sa_sigaction = timerhandler;
    sigemptyset(&sa.sa_mask);
    if (sigaction(SIG, &sa, NULL) == -1)
        errExit("sigaction");

    /* Block timer signal temporarily */
    //vbprintf("Blocking signal %d\n", SIG);
    sigemptyset(&mask);
    sigaddset(&mask, SIG);
    if (sigprocmask(SIG_SETMASK, &mask, NULL) == -1)
        errExit("sigprocmask");

    /* Create the timer */
    sev.sigev_notify = SIGEV_SIGNAL;
    sev.sigev_signo = SIG;
    sev.sigev_value.sival_ptr = &timerid;
    if (timer_create(CLOCKID, &sev, &timerid) == -1)
        errExit("timer_create");

    vbprintf("created timer ID is 0x%lx by thread %lld\n", (long) timerid, pthread_self());

    /* Start the timer */
    its.it_value.tv_sec = 5;   // 5 seconds
    its.it_value.tv_nsec = 0;
    its.it_interval.tv_sec = its.it_value.tv_sec;
    its.it_interval.tv_nsec = its.it_value.tv_nsec;

    if (timer_settime(timerid, 0, &its, NULL) == -1)
        errExit("timer_settime");

    /* Unlock the timer signal, so that timer notification
       can be delivered */

    //vbprintf("Unblocking signal %d\n", SIG);
    if (sigprocmask(SIG_UNBLOCK, &mask, NULL) == -1)
        errExit("sigprocmask");
}


/*
 * Returns copy of string |s| with the length |len|. The returned
 * string is NULL-terminated.
 */
static char* strcopy(const char *s, size_t len)
{
  char *dst;
  dst = malloc(len+1);
  memcpy(dst, s, len);
  dst[len] = '\0';
  return dst;
}

/*
 * Prints error message |msg| and exit.
 */
static void die(const char *msg)
{
  fprintf(stderr, "FATAL: %s\n", msg);
  //exit(EXIT_FAILURE);
}

/*
 * Prints error containing the function name |func| and message |msg|
 * and exit.
 */
static void dief(const char *func, const char *msg)
{
  fprintf(stderr, "FATAL: %s: %s\n", func, msg);
  //exit(EXIT_FAILURE);
}

static void diethread(const char *func, const char *msg){
  fprintf(stderr, "FATAL: %s: %s\n", func, msg);
  pthread_exit(EXIT_FAILURE);
  abort();
  //int * p = NULL;
  //*p = 1;
}

/*
 * Prints error containing the function name |func| and error code
 * |error_code| and exit.
 */
static void diec(const char *func, int error_code)
{
  fprintf(stderr, "FATAL: %s: error_code=%d, msg=%s\n", func, error_code,
          spdylay_strerror(error_code));
  //exit(EXIT_FAILURE);
}

/**
 * print debug info
 */
static void dumpRequest(struct Request* req) {
    fprintf(stdout, " %s : streamId : %d\n", req->hostport, req->stream_id);
}

static void dumpURI(struct URI* uri) {
    fprintf(stdout, " %s : path : %s\n", uri->hostport, uri->path);
}

/*
 * Check response is content-encoding: gzip. We need this because SPDY
 * client is required to support gzip.
 */
static void check_gzip(struct Request *req, char **nv)
{
  int gzip = 0;
  size_t i;
  for(i = 0; nv[i]; i += 2) {
    if(strcmp("content-encoding", nv[i]) == 0) {
      gzip = strcmp("gzip", nv[i+1]) == 0;
      break;
    }
  }
  if(gzip) {
    int rv;
    if(req->inflater) {
      return;
    }
    rv = spdylay_gzip_inflate_new(&req->inflater);
    if(rv != 0) {
      die("Can't allocate inflate stream.");
    }
  }
}


/*
 * The implementation of spdylay_send_callback type. Here we write
 * |data| with size |length| to the network and return the number of
 * bytes actually written. See the documentation of
 * spdylay_send_callback for the details.
 */
static ssize_t send_callback(spdylay_session *session,
                             const uint8_t *data, size_t length, int flags,
                             void *user_data)
{
  struct Connection *connection;
  ssize_t rv;
  connection = (struct Connection*)user_data;
  connection->want_io = IO_NONE;
  ERR_clear_error();
  rv = SSL_write(connection->ssl, data, length);
  if(rv < 0) {
    int err = SSL_get_error(connection->ssl, rv);
    if(err == SSL_ERROR_WANT_WRITE || err == SSL_ERROR_WANT_READ) {
      connection->want_io = (err == SSL_ERROR_WANT_READ ?
                             WANT_READ : WANT_WRITE);
      rv = SPDYLAY_ERR_WOULDBLOCK;
    } else {
      rv = SPDYLAY_ERR_CALLBACK_FAILURE;
    }
  }
  return rv;
}

/*
 * The implementation of spdylay_recv_callback type. Here we read data
 * from the network and write them in |buf|. The capacity of |buf| is
 * |length| bytes. Returns the number of bytes stored in |buf|. See
 * the documentation of spdylay_recv_callback for the details.
 */
static ssize_t recv_callback(spdylay_session *session,
                             uint8_t *buf, size_t length, int flags,
                             void *user_data)
{
  struct Connection *connection;
  ssize_t rv;
  connection = (struct Connection*)user_data;
  connection->want_io = IO_NONE;
  ERR_clear_error();
  rv = SSL_read(connection->ssl, buf, length);
  if(rv < 0) {
    int err = SSL_get_error(connection->ssl, rv);
    if(err == SSL_ERROR_WANT_WRITE || err == SSL_ERROR_WANT_READ) {
      connection->want_io = (err == SSL_ERROR_WANT_READ ?
                             WANT_READ : WANT_WRITE);
      rv = SPDYLAY_ERR_WOULDBLOCK;
    } else {
      rv = SPDYLAY_ERR_CALLBACK_FAILURE;
    }
  } else if(rv == 0) {
    rv = SPDYLAY_ERR_EOF;
  }
  return rv;
}

/*
 * The implementation of spdylay_before_ctrl_send_callback type.  We
 * use this function to get stream ID of the request. This is because
 * stream ID is not known when we submit the request
 * (spdylay_submit_request).
 */
static void before_ctrl_send_callback(spdylay_session *session,
                                      spdylay_frame_type type,
                                      spdylay_frame *frame,
                                      void *user_data)
{
  if(type == SPDYLAY_SYN_STREAM) {
    struct Request *req;
    int stream_id = frame->syn_stream.stream_id;
    req = spdylay_session_get_stream_user_data(session, stream_id);
    if(req && req->stream_id == -1) {
      req->stream_id = stream_id;
      vbprintf("[INFO] Stream ID = %d\n", stream_id);
    }
  }else{
    vbprintf("before control frame send: stream_id %d frame type: %d\n", frame->headers.stream_id, type);
  }
}

static void on_ctrl_send_callback(spdylay_session *session,
                                  spdylay_frame_type type,
                                  spdylay_frame *frame, void *user_data)
{
  char **nv;
  const char *name = NULL;
  int32_t stream_id;
  size_t i;
  switch(type) {
  case SPDYLAY_SYN_STREAM:
    nv = frame->syn_stream.nv;
    name = "SYN_STREAM";
    stream_id = frame->syn_stream.stream_id;
    break;
  default:
    break;
  }
  if(name && spdylay_session_get_stream_user_data(session, stream_id)) {
    vbprintf("[INFO] C ----------------------------> S (%s)\n", name);
    for(i = 0; nv[i]; i += 2) {
      vbprintf("       %s: %s\n", nv[i], nv[i+1]);
    }
  }
}

static void on_ctrl_recv_callback(spdylay_session *session,
                                  spdylay_frame_type type,
                                  spdylay_frame *frame, void *user_data)
{
  struct Request *req;
  char **nv;
  const char *name = NULL;

  struct ThreadUri *pthrduri = (struct ThreadUri*)pthread_getspecific(tkey);

  size_t i;
  switch(type) {
  case SPDYLAY_SYN_REPLY:
    nv = frame->syn_reply.nv;
    name = "SYN_REPLY";
    stream_id = frame->syn_reply.stream_id;
    break;
  case SPDYLAY_HEADERS:
    nv = frame->headers.nv;
    name = "HEADERS";
    stream_id = frame->headers.stream_id;
    break;
  case SPDYLAY_SYN_STREAM:
    name = "SYN_STREAM";
    nv = frame->syn_stream.nv;
    stream_id = frame->headers.stream_id;
    pthrduri->assoc_stream_id = frame->syn_stream.assoc_stream_id;
    break;
  default:
    vbprintf("on_ctrl_recv_callback : stream %d type %d\n", frame->headers.stream_id, type);
    break;
  }
  if(!name) {
    return;
  }
  req = spdylay_session_get_stream_user_data(session, stream_id);
  if(req) {
    check_gzip(req, nv);
    vbprintf("[INFO] C <---------------------------- S (%s)\n", name);
    for(i = 0; nv[i]; i += 2) {
      vbprintf("       %s: %s\n", nv[i], nv[i+1]);
    }
  }else{
    req = spdylay_session_get_stream_user_data(session, pthrduri->assoc_stream_id);
    if(req) {
        check_gzip(req, nv);
        vbprintf("[INFO] C <---- server push ------------- S (%s)\n", name);
        for(i = 0; nv[i]; i += 2) {
            vbprintf("       %s: %s\n", nv[i], nv[i+1]);
        }
    }
  }
}

/*
 * The implementation of spdylay_on_stream_close_callback type. We use
 * this function to know the response is fully received. Since we just
 * fetch 1 resource in this program, after reception of the response,
 * we submit GOAWAY and close the session.
 */
static void on_stream_close_callback(spdylay_session *session,
                                     int32_t stream_id,
                                     spdylay_status_code status_code,
                                     void *user_data)
{
  struct Request *req;
  req = spdylay_session_get_stream_user_data(session, stream_id);
  if(req) {
    int rv;
    //vbprintf("on stream close : stream_id %d, status %d, do not submit goaway!!\n", stream_id, status_code);
    //rv = spdylay_submit_goaway(session, SPDYLAY_GOAWAY_OK);
    //if(rv != 0) {
    //  diec("spdylay_submit_goaway", rv);
    //}
  }
  vbprintf("on stream close : server closed even stream id %d. status 5 is CANCEL. status %d\n", stream_id, status_code);
}

#define MAX_OUTLEN 4096

/**
 * callback upon data send
 */
static void on_data_send_callback(spdylay_session *session, uint8_t flags,
                                  int32_t stream_id, int32_t length, void *user_data) {
  vbprintf("[INFO] C ------- stream id %d ------------------> S (DATA)\n", stream_id);
  if(stream_id >= 3){
    spdylay_session_close_stream(session, stream_id);
    vbprintf("on_data_send_callback spdy close_stream %d\n", stream_id);
  }
}


/*
 * The implementation of spdylay_on_data_chunk_recv_callback type. We
 * use this function to print the received response body.
 */
static void on_data_chunk_recv_callback(spdylay_session *session, uint8_t flags,
                                        int32_t stream_id,
                                        const uint8_t *data, size_t len,
                                        void *user_data)
{
  int sleeptm;
  struct Request *req;
  struct ThreadUri * pthrduri = (struct ThreadUri*)pthread_getspecific(tkey);

  req = spdylay_session_get_stream_user_data(session, stream_id);
  if(req) {
    vbprintf("[INFO] C <---------------------------- S (DATA)\n");
    vbprintf("       %lu bytes\n", (unsigned long int)len);

    vbprintf("on data chunk recv: stream %d inflater: %lx\n", stream_id, req->inflater);
    if(req->inflater && 0) {// shall never be set. Not sure why sometime it was set.
      while(len > 0) {
        uint8_t out[MAX_OUTLEN];
        size_t outlen = MAX_OUTLEN;
        size_t tlen = len;
        int rv;
        rv = spdylay_gzip_inflate(req->inflater, out, &outlen, data, &tlen);
        if(rv == -1) {
          spdylay_submit_rst_stream(session, stream_id, SPDYLAY_INTERNAL_ERROR);
          break;
        }
        if(verbose){
          fwrite(out, 1, outlen, stdout);
        }
        data += tlen;
        len -= tlen;
      }
      fprintf(stdout, "done with inflater recvd data chunk %s\n", data);
    } else {
      vbprintf("on data chunk recv callback req not inflated, chunksize %d\n", len);
      // TODO add support gzip
      if(verbose) fwrite(data, 1, len, stdout);
      printf("\n");   // fwrite does not new line.
      updateClientPushId(pthrduri, (char*)data);
    }

  }else if(len > 0){   // only send push ack back when we have valid data
    // on server push stream, spdylay_session_open_stream stream_user_data = NULL
    vbprintf("[INFO] C <---------------------------- S (DATA)\n");
    vbprintf(" on_data_chunk_recv_callback, got push data with stream_id : %d assoc_stream_id: %d   %lu bytes\n", stream_id, pthrduri->assoc_stream_id, (unsigned long int)len);
    if(verbose) fwrite(data, 1, len, stdout);

    // upon server push, ack back
    req = spdylay_session_get_stream_user_data(session, pthrduri->assoc_stream_id);
    if(req) {
        sleeptm = randSleep(5);   // randomly sleep within 5 seconds.
        if(sleeptm && 0){         // to test server handle rst frame.
            vbprintf("submit rst when push ack stream_id : %d assoc_stream_id: %d \n", stream_id, pthrduri->assoc_stream_id);
            spdylay_submit_rst_stream(session, stream_id, SPDYLAY_INTERNAL_ERROR);
        }else{
            submit_request_pushack(session, req, (char*)data, len);
        }
    }
    // close this stream after push
    // XXX, no, recver does not close push stream. Push stream init by server and must be even.
    // stream must be closed by its creator.
    // node-spdy is able to close the push stream it inited.
    //vbprintf("on_data_chunk_recv_callback, close push stream after ack stream_id : %d assoc_stream_id: %d \n", stream_id, pthrduri->assoc_stream_id);
    //spdylay_session_close_stream(session, stream_id, 5);  // status code is 5
  }else{
    vbprintf(stdout, "on data chunk recv : nothing: %lu bytes\n", (unsigned long int)len);
  }
}

/*
 * Setup callback functions. Spdylay API offers many callback
 * functions, but most of them are optional. The send_callback is
 * always required. Since we use spdylay_session_recv(), the
 * recv_callback is also required.
 */
static void setup_spdylay_callbacks(spdylay_session_callbacks *callbacks)
{
  memset(callbacks, 0, sizeof(spdylay_session_callbacks));
  callbacks->send_callback = send_callback;
  callbacks->recv_callback = recv_callback;
  callbacks->before_ctrl_send_callback = before_ctrl_send_callback;
  callbacks->on_ctrl_send_callback = on_ctrl_send_callback;
  callbacks->on_ctrl_recv_callback = on_ctrl_recv_callback;
  callbacks->on_stream_close_callback = on_stream_close_callback;
  callbacks->on_data_chunk_recv_callback = on_data_chunk_recv_callback;
  callbacks->on_data_send_callback = on_data_send_callback;
}

/*
 * Callback function for SSL/TLS NPN. Since this program only supports
 * SPDY protocol, if server does not offer SPDY protocol the Spdylay
 * library supports, we terminate program.
 */
static int select_next_proto_cb(SSL* ssl,
                                unsigned char **out, unsigned char *outlen,
                                const unsigned char *in, unsigned int inlen,
                                void *arg)
{
  int rv;
  uint16_t *spdy_proto_version;
  /* spdylay_select_next_protocol() selects SPDY protocol version the
     Spdylay library supports. */
  rv = spdylay_select_next_protocol(out, outlen, in, inlen);
  if(rv <= 0) {
    die("Server did not advertise spdy/2 or spdy/3 protocol.");
  }
  spdy_proto_version = (uint16_t*)arg;
  *spdy_proto_version = rv;
  return SSL_TLSEXT_ERR_OK;
}

/*
 * Setup SSL context. We pass |spdy_proto_version| to get negotiated
 * SPDY protocol version in NPN callback.
 */
static void init_ssl_ctx(SSL_CTX *ssl_ctx, uint16_t *spdy_proto_version)
{
  /* Disable SSLv2 and enable all workarounds for buggy servers */
  SSL_CTX_set_options(ssl_ctx, SSL_OP_ALL|SSL_OP_NO_SSLv2);
  SSL_CTX_set_mode(ssl_ctx, SSL_MODE_AUTO_RETRY);
  SSL_CTX_set_mode(ssl_ctx, SSL_MODE_RELEASE_BUFFERS);
  /* Set NPN callback */
  SSL_CTX_set_next_proto_select_cb(ssl_ctx, select_next_proto_cb,
                                   spdy_proto_version);
}

static int ssl_handshake(SSL *ssl, int fd)
{
  int rv;
  if(SSL_set_fd(ssl, fd) == 0) {
    dief("SSL_set_fd", ERR_error_string(ERR_get_error(), NULL));
    return -1;
  }
  ERR_clear_error();
  rv = SSL_connect(ssl);
  if(rv <= 0) {
    dief("SSL_connect", ERR_error_string(ERR_get_error(), NULL));
  }
  return rv;
}

/*
 * Connects to the host |host| and port |port|.  This function returns
 * the file descriptor of the client socket.
 */
static int connect_to(const char *host, uint16_t port)
{
  struct addrinfo hints;
  int fd = -1;
  int rv;
  char service[NI_MAXSERV];
  struct addrinfo *res, *rp;
  snprintf(service, sizeof(service), "%u", port);
  memset(&hints, 0, sizeof(struct addrinfo));
  hints.ai_family = AF_UNSPEC;
  hints.ai_socktype = SOCK_STREAM;
  rv = getaddrinfo(host, service, &hints, &res);
  if(rv != 0) {
    dief("getaddrinfo", gai_strerror(rv));
  }
  for(rp = res; rp; rp = rp->ai_next) {
    fd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
    if(fd == -1) {
      continue;
    }
    while((rv = connect(fd, rp->ai_addr, rp->ai_addrlen)) == -1 &&
          errno == EINTR);
    if(rv == 0) {
      break;
    }
    close(fd);
    fd = -1;
  }
  freeaddrinfo(res);
  return fd;
}

static void make_non_block(int fd)
{
  int flags, rv;
  while((flags = fcntl(fd, F_GETFL, 0)) == -1 && errno == EINTR);
  if(flags == -1) {
    dief("fcntl", strerror(errno));
  }
  while((rv = fcntl(fd, F_SETFL, flags | O_NONBLOCK)) == -1 && errno == EINTR);
  if(rv == -1) {
    dief("fcntl", strerror(errno));
  }
}

/*
 * Setting TCP_NODELAY is not mandatory for the SPDY protocol.
 */
static void set_tcp_nodelay(int fd)
{
  int val = 1;
  int rv;
  rv = setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &val, (socklen_t)sizeof(val));
  if(rv == -1) {
    dief("setsockopt", strerror(errno));
  }
}

/**
 * Setting TCP no timeout so we got persistent socket
 */
static void set_tcp_notimeout(int fd)
{
  struct timeval timeout;
  timeout.tv_sec = 100000;   // make is large enough
  timeout.tv_usec = 0;

  int rv = 0;
  //rv = setsockopt(fd, SOL_SOCKET, SO_RECVTIMEO, (char*)&timeout, (socklen_t)sizeof(timeout));
  if(rv == -1) {
    dief("setsockopt timeout", strerror(errno));
  }
}

/*
 * Update |pollfd| based on the state of |connection|.
 */
static void ctl_poll(struct pollfd *pollfd, struct Connection *connection)
{
  pollfd->events = 0;
  if(spdylay_session_want_read(connection->session) ||
     connection->want_io == WANT_READ) {
    pollfd->events |= POLLIN;
  }
  if(spdylay_session_want_write(connection->session) ||
     connection->want_io == WANT_WRITE) {
    pollfd->events |= POLLOUT;
  }
}

/*
 * Submits the request |req| to the connection |connection|.  This
 * function does not send packets; just append the request to the
 * internal queue in |connection->session|.
 */
static void submit_request(struct Connection *connection, struct Request *req)
{
  int pri = 0;
  int rv;
  const char *nv[15];
  /* We always use SPDY/3 style header even if the negotiated protocol
     version is SPDY/2. The library translates the header name as
     necessary. Make sure that the last item is NULL! */
  nv[0] = ":method";     nv[1] = "GET";
  nv[2] = ":path";       nv[3] = req->path;
  nv[4] = ":version";    nv[5] = "HTTP/1.1";
  nv[6] = ":scheme";     nv[7] = "https";
  nv[8] = ":host";       nv[9] = req->hostport;
  nv[10] = "accept";     nv[11] = "*/*";
  nv[12] = "user-agent"; nv[13] = "spdylay/"SPDYLAY_VERSION;
  nv[14] = NULL;
  rv = spdylay_submit_request(connection->session, pri, nv, NULL, req);
  if(rv != 0) {
    diec("spdylay_submit_request", rv);
  }
}

static void submit_request_registrate(struct Connection *connection, struct Request *req)
{
  int pri = 0;
  int rv;
  const char *nv[15];
  /* We always use SPDY/3 style header even if the negotiated protocol
     version is SPDY/2. The library translates the header name as
     necessary. Make sure that the last item is NULL! */
  nv[0] = ":method";     nv[1] = "POST";
  nv[2] = ":path";       nv[3] = req->path;
  nv[4] = ":version";    nv[5] = "HTTP/1.1";
  nv[6] = ":scheme";     nv[7] = "https";
  nv[8] = ":host";       nv[9] = req->hostport;
  nv[10] = "accept";     nv[11] = "application/json";
  nv[12] = "user-agent"; nv[13] = "spdylay/"SPDYLAY_VERSION;
  nv[14] = NULL;
  rv = spdylay_submit_request(connection->session, pri, nv, NULL, req);
  if(rv != 0) {
    diec("spdylay_submit_request", rv);
  }
}


static void submit_request_registrateV2(struct Connection *connection, struct Request *req)
{
  int pri = 0;
  int rv;
  const char *nv[19];

  spdylay_session_callbacks callbacks;
  spdylay_data_provider data_prd;
  char *datacopy; 
  int metalen, datalen;
  //char* meta = "{\"a\": 1, \"b\": 2}";
  char* meta = register_meta;
  char sz[12];

  metalen = strlen(meta);
  datalen = metalen+1;
  datacopy = malloc(datalen);
  memset(datacopy, 0, datalen);
  strcpy(datacopy, meta);
  sprintf(sz, "%d", datalen);
 
  /* We always use SPDY/3 style header even if the negotiated protocol
     version is SPDY/2. The library translates the header name as
     necessary. Make sure that the last item is NULL! */
  nv[0] = ":method";     nv[1] = "POST";
  nv[2] = ":path";       nv[3] = req->path;
  nv[4] = ":version";    nv[5] = "HTTP/1.1";
  nv[6] = ":scheme";     nv[7] = "https";
  nv[8] = ":host";       nv[9] = req->hostport;
  nv[10] = "accept";     nv[11] = "application/json";
  nv[12] = "user-agent"; nv[13] = "spdylay/"SPDYLAY_VERSION;
  nv[14] = "authorization"; nv[15] = "Basic ZGVmYXVsdDpzZWNyZXQ=";
  nv[16] = "content-type"; nv[17] = "application/json";
  nv[18] = "Content-Length"; nv[19] = sz;
  nv[20] = NULL;


  memset(&callbacks, 0, sizeof(spdylay_session_callbacks));
  data_prd.source.ptr = datacopy;
  data_prd.read_callback = register_data_source_read_callback;

  vbprintf("\nsubmit register v2 : data %s \t %d\n", datacopy, datalen);
  
  rv = spdylay_submit_request(connection->session, pri, nv, &data_prd, req);
  if(rv != 0) {
    diec("spdylay_submit_request", rv);
  }
}


static void submit_request_listen(struct Connection *connection, struct Request *req, char *clientId, char *pushId)
{
  int pri = 0;
  int rv;
  const char *nv[17];
  char path[256];
  char clid[256];

  // make up listen req path.
  memset(path,0, 256);
  memset(clid,0, 256);
  strcat(path, "/client/v1/");
  strcat(path, pushId);
  strcat(clid, "Basic  ");
  strcat(clid, clientId);

  if(unauthorizedlisten){
      strcpy(clid, "wrong-client-id");
  }
  vbprintf("\nsubmit request_listen : clientId %s \t %s\n", clid, path);

  /* We always use SPDY/3 style header even if the negotiated protocol
     version is SPDY/2. The library translates the header name as
     necessary. Make sure that the last item is NULL! */
  nv[0] = ":method";     nv[1] = "GET";
  nv[2] = ":path";       nv[3] = path;
  nv[4] = ":version";    nv[5] = "HTTP/1.1";
  nv[6] = ":scheme";     nv[7] = "https";
  nv[8] = ":host";       nv[9] = req->hostport;
  nv[10] = "accept";     nv[11] = "text/plain";
  nv[12] = "user-agent"; nv[13] = "spdylay/"SPDYLAY_VERSION;
  nv[14] = "authorization"; nv[15] = clid;
  nv[16] = NULL;
  rv = spdylay_submit_request(connection->session, pri, nv, NULL, req);
  if(rv != 0) {
    diec("spdylay_submit_request", rv);
  }
}

static void submit_request_listenV2(struct Connection *connection, struct Request *req, char *clientId, char *pushId)
{
  int pri = 0;
  int rv;
  const char *nv[17];
  char path[256];
  char clid[256];

  // make up listen req path.
  memset(path,0, 256);
  memset(clid,0, 256);
  strcat(path, "/client/v2/");
  strcat(path, pushId);
  strcat(path, "?min_ping_interval_sec=30");
  strcat(clid, "Basic  ");
  strcat(clid, clientId);

  if(unauthorizedlisten){
      strcpy(clid, "wrong-client-id");
  }
  vbprintf("\nsubmit request_listen : clientId %s \t %s\n", clid, path);

  /* We always use SPDY/3 style header even if the negotiated protocol
     version is SPDY/2. The library translates the header name as
     necessary. Make sure that the last item is NULL! */
  nv[0] = ":method";     nv[1] = "GET";
  nv[2] = ":path";       nv[3] = path;
  nv[4] = ":version";    nv[5] = "HTTP/1.1";
  nv[6] = ":scheme";     nv[7] = "https";
  nv[8] = ":host";       nv[9] = req->hostport;
  nv[10] = "accept";     nv[11] = "application/json";
  nv[12] = "user-agent"; nv[13] = "spdylay/"SPDYLAY_VERSION;
  nv[14] = "authorization"; nv[15] = clid;
  nv[16] = NULL;
  rv = spdylay_submit_request(connection->session, pri, nv, NULL, req);
  if(rv != 0) {
    diec("spdylay_submit_request", rv);
  }
}


/**
 * attach data to push ack with data provider callback.
 * data and len is the data pushed to client from server.
 */
static void submit_request_pushack(spdylay_session *session, struct Request *req, char * data, int len)
{
  int pri = 0;
  int rv;
  const char *nv[19];
  char clid[256];
  char *datacopy;

  struct ThreadUri * pthrduri = (struct ThreadUri*)pthread_getspecific(tkey);
  memset(pthrduri->pushData, 0, sizeof(pthrduri->pushData));
  strncpy(pthrduri->pushData, data, len);   // store the push data to thrd local

  vbprintf("submit_request_pushack: pushId %s pushData %s\n",
            pthrduri->pushId, pthrduri->pushData);

  // exit server ask me to diehard
  if(strstr(pthrduri->pushData, "diehard")){
    vbprintf("submit_request_pushack: server ask me to die %s\n", pthrduri->pushData);
    diethread("submit_request_pushack", "server ask me to die");
  }
  struct URI *uri = (struct URI *)&(pthrduri->uri);   // typecast void * back to proper type

  memset(clid, 0, 256);
  strcat(clid, "Basic  ");
  strcat(clid, pthrduri->clientId);

  /* We always use SPDY/3 style header even if the negotiated protocol
     version is SPDY/2. The library translates the header name as
     necessary. Make sure that the last item is NULL! */
  nv[0] = ":method";     nv[1] = "POST";
  nv[2] = ":path";       nv[3] = "/client/v2/ack";
  nv[4] = ":version";    nv[5] = "HTTP/1.1";
  nv[6] = ":scheme";     nv[7] = "https";
  nv[8] = ":host";       nv[9] = req->hostport;
  nv[10] = "accept";     nv[11] = "application/json";
  nv[12] = "user-agent"; nv[13] = "spdylay/"SPDYLAY_VERSION;
  nv[14] = "authorization"; nv[15] = clid;
  nv[16] = "content-type"; nv[17] = "application/json";
  nv[18] = NULL;

  spdylay_data_provider data_prd = {-1, NULL};

  datacopy = (char*)malloc(len+1);
  memset(datacopy, 0, len+1);
  strncpy(datacopy, data, len);
  data_prd.source.ptr = datacopy;
  data_prd.read_callback = data_source_read_callback;
  rv = spdylay_submit_request(session, pri, nv, &data_prd, req);
  //rv = spdylay_submit_request(session, pri, nv, NULL, req);
  if(rv != 0) {
    diec("spdylay_submit_request_pushack", rv);
  }
}

/**
 * refresh request
 */
static void submit_request_refresh(struct Connection *connection, struct Request *req, char *clientId, char *pushId)
{
  int pri = 0;
  int rv;
  const char *nv[21];
  char path[256];
  char clid[256];
  char *datacopy;
  spdylay_data_provider data_prd = {-1, NULL};

  // make up listen req path.
  memset(path,0, 256);
  memset(clid,0, 256);
  strcat(path, "/client/v1/refresh");
  strcat(clid, "Basic ");
  strcat(clid, clientId);
  vbprintf("\nsubmit request_refresh : %s \t %s\n", path, clid);

  /* We always use SPDY/3 style header even if the negotiated protocol
     version is SPDY/2. The library translates the header name as
     necessary. Make sure that the last item is NULL! */
  nv[0] = ":method";     nv[1] = "POST";
  nv[2] = ":path";       nv[3] = path;
  nv[4] = ":version";    nv[5] = "HTTP/1.1";
  nv[6] = ":scheme";     nv[7] = "https";
  nv[8] = ":host";       nv[9] = req->hostport;
  nv[10] = "accept";     nv[11] = "application/json";
  nv[12] = "user-agent"; nv[13] = "spdylay/"SPDYLAY_VERSION;
  nv[14] = "authorization"; nv[15] = clid;
  nv[16] = "content-type"; nv[17] = "application/json";
  nv[18] = "Content-Length"; nv[19] = "0";
  nv[20] = NULL;

  // if client has pushId, send as json with the request
  if(pushId && 0){
    //datacopy = (char*)malloc(128);
    //memset(datacopy, 0, len+1);
    //strncpy(datacopy, data, len);

    //data_prd.source.ptr = datacopy;
    nv[19] = "24";
    data_prd.read_callback = refresh_data_source_read_callback;
    rv = spdylay_submit_request(connection->session, pri, nv, &data_prd, req);
  }else{
    nv[19] = "0";
    rv = spdylay_submit_request(connection->session, pri, nv, NULL, req);
  }

  if(rv != 0) {
    diec("spdylay_submit_request", rv);
  }
}


/*
 * Performs the network I/O.
 */
static int exec_io(struct Connection *connection)
{
  int rv;
  rv = spdylay_session_recv(connection->session);
  if(rv != 0) {
    //diec("spdylay_session_recv", rv);
    return rv;
  }
  rv = spdylay_session_send(connection->session);
  if(rv != 0) {
    //diec("spdylay_session_send", rv);
    return rv;
  }
  return rv;
}

static void request_init(struct Request *req, const struct URI *uri)
{
  req->host = strcopy(uri->host, uri->hostlen);
  req->port = uri->port;
  req->path = strcopy(uri->path, uri->pathlen);
  req->hostport = strcopy(uri->hostport, uri->hostportlen);
  req->stream_id = -1;
  req->inflater = NULL;
}

static void request_free(struct Request *req)
{
  free(req->host);
  free(req->path);
  free(req->hostport);
  spdylay_gzip_inflate_del(req->inflater);
}

/*
 * Fetches the resource denoted by |uri|.
 */
//static void fetch_uri(const struct URI *uri)
static void * createSpdyClient(void * arg)
{

  struct ThreadUri * pthrduri = (struct ThreadUri*)arg;
  pthread_setspecific(tkey, pthrduri);
  vbprintf("create spdy client : %s\n", pthrduri->clientId);

  struct URI *uri = (struct URI *)&(pthrduri->uri);   // typecast void * back to proper type

  while(1){
    initSpdySession(pthrduri);
    pthrduri->retries += 1;
    // for scalability test, we do not want retry.
    if(backoff >= 0){
        vbprintf("\n\n\n >>>>>>> session died, retry backoff %d <<<<< \n\n\n", pthrduri->retries);
        retryBackoff(pthrduri->retries, 10);  // max 10 seconds ?
    }else{
        break;  // client quit without backoff.
    }
  }
}


/**
 * init a ssl spdy session to server
 */
static void initSpdySession(struct ThreadUri* pthrduri) {
  spdylay_session_callbacks callbacks;
  int fd;
  SSL_CTX *ssl_ctx;
  SSL *ssl;
  struct Connection connection;
  int rv;
  nfds_t npollfds = 1;
  struct pollfd pollfds[1];
  uint16_t spdy_proto_version;

  // init request with host/port/path etc
  request_init(&pthrduri->req, &(pthrduri->uri));

  // setup spdylay callbacks
  setup_spdylay_callbacks(&callbacks);

  /* Establish connection and setup SSL */
  fd = connect_to(pthrduri->req.host, pthrduri->req.port);
  ssl_ctx = SSL_CTX_new(SSLv23_client_method());
  if(ssl_ctx == NULL) {
    dief("SSL_CTX_new", ERR_error_string(ERR_get_error(), NULL));
  }
  init_ssl_ctx(ssl_ctx, &spdy_proto_version);
  ssl = SSL_new(ssl_ctx);
  if(ssl == NULL) {
    dief("SSL_new", ERR_error_string(ERR_get_error(), NULL));
  }
  /* To simplify the program, we perform SSL/TLS handshake in blocking
     I/O. */
  rv = ssl_handshake(ssl, fd);
  if(rv < 0){
    return;
  }

  connection.ssl = ssl;
  connection.want_io = IO_NONE;

  /* Here make file descriptor non-block */
  make_non_block(fd);
  set_tcp_nodelay(fd);

  vbprintf("[INFO] SPDY protocol version = %d\n", spdy_proto_version);
  rv = spdylay_session_client_new(&connection.session, spdy_proto_version,
                                  &callbacks, &connection);
  if(rv != 0) {
    diec("spdylay_session_client_new", rv);
  }

  // init a session and store into thread specific, setting the specific
  pthrduri->connection = &connection;
  vbprintf("pthread_setspecific ret: %d thread_id %ld\n", rv, pthread_self());

  // now switch to different request, priority water down
  // listen when client has both clientid and pushid
  // refresh when client only has clientid
  // register when req.path is register
  if(strlen(pthrduri->clientId) && strlen(pthrduri->pushId)){
    // if client has both client id and push id, just listen
    vbprintf("submit listen request: %s %s thread_id %ld\n", pthrduri->clientId, pthrduri->pushId, pthread_self());
    submit_request_listenV2(&connection, &pthrduri->req, pthrduri->clientId, pthrduri->pushId);
  }else if(strlen(pthrduri->clientId)){
    // if only client id, submit refresh request
    vbprintf("submit refresh request: %s thread_id %ld\n", pthrduri->clientId, pthread_self());
    submit_request_refresh(&connection, &pthrduri->req, &pthrduri->clientId, &pthrduri->pushId);
  }else if(strstr(pthrduri->req.path, "register")){
    memset(pthrduri->clientId, 0, sizeof(pthrduri->clientId));
    submit_request_registrateV2(&connection, &pthrduri->req);
  }else if(strstr(pthrduri->req.path, "puid")){   // path = /client/v1/puid-0
    submit_request_listenV2(&connection, &pthrduri->req, pthrduri->clientId, pthrduri->pushId);
  }else{
      /* Submit the HTTP request to the outbound queue. */
      submit_request(&connection, &pthrduri->req);
  }

  // setup timer and handler
  //createTimer();

  pollfds[0].fd = fd;
  ctl_poll(pollfds, &connection);

  /* Event loop */
  while(spdylay_session_want_read(connection.session) ||
        spdylay_session_want_write(connection.session)) {
    //int nfds = poll(pollfds, npollfds, -1);
    int nfds = poll(pollfds, npollfds, 1000*60*15);  // server timeout 15 min
    if(nfds == -1) {
      vbprintf("poll timed out with return value -1!!");
      dief("poll", strerror(errno));
      //continue;
    }
    if(pollfds[0].revents & (POLLIN | POLLOUT)) {
      rv = exec_io(&connection);
      if(rv != 0){
        //goto newClient;
        break;   // session died, break out blocking on this spdy session.
      }
    }
    if((pollfds[0].revents & POLLHUP) || (pollfds[0].revents & POLLERR)) {
      die("Connection error");
    }

    // epoll timed out, return val is 0.
    // we can set ping frame.
    if(nfds == 0){
        submitPingOrRefresh(); // now submit the ping frame.
    }
    ctl_poll(pollfds, &connection);
  }

  /* Resource cleanup */
  spdylay_session_del(connection.session);
  SSL_shutdown(ssl);
  SSL_free(ssl);
  SSL_CTX_free(ssl_ctx);
  shutdown(fd, SHUT_WR);
  close(fd);
  request_free(&pthrduri->req);
}

static int parse_uri(struct URI *res, const char *uri)
{
  /* We only interested in https */
  size_t len, i, offset;
  memset(res, 0, sizeof(struct URI));
  len = strlen(uri);
  if(len < 9 || memcmp("https://", uri, 8) != 0) {
    return -1;
  }
  offset = 8;
  res->host = res->hostport = &uri[offset];
  res->hostlen = 0;
  if(uri[offset] == '[') {
    /* IPv6 literal address */
    ++offset;
    ++res->host;
    for(i = offset; i < len; ++i) {
      if(uri[i] == ']') {
        res->hostlen = i-offset;
        offset = i+1;
        break;
      }
    }
  } else {
    const char delims[] = ":/?#";
    for(i = offset; i < len; ++i) {
      if(strchr(delims, uri[i]) != NULL) {
        break;
      }
    }
    res->hostlen = i-offset;
    offset = i;
  }
  if(res->hostlen == 0) {
    return -1;
  }
  /* Assuming https */
  res->port = 443;
  if(offset < len) {
    if(uri[offset] == ':') {
      /* port */
      const char delims[] = "/?#";
      int port = 0;
      ++offset;
      for(i = offset; i < len; ++i) {
        if(strchr(delims, uri[i]) != NULL) {
          break;
        }
        if('0' <= uri[i] && uri[i] <= '9') {
          port *= 10;
          port += uri[i]-'0';
          if(port > 65535) {
            return -1;
          }
        } else {
          return -1;
        }
      }
      if(port == 0) {
        return -1;
      }
      offset = i;
      res->port = port;
    }
  }
  res->hostportlen = uri+offset-res->host;
  for(i = offset; i < len; ++i) {
    if(uri[i] == '#') {
      break;
    }
  }
  if(i-offset == 0) {
    res->path = "/";
    res->pathlen = 1;
  } else {
    res->path = &uri[offset];
    res->pathlen = i-offset;
  }
  return 0;
}

int main(int argc, char **argv)
{
  struct URI uri;
  struct sigaction act;
  int rv;

#define MAX_CLIENTS 40000
  int numclients = 1;   // default one client
  int i;
  int err;
  pthread_t* tid;   // how many threads per one instance of spdy client
  pthread_attr_t tattr;
  int c;
  struct timespec tim;
  //char *ele_url = "https://elephant-dev.colorcloud.com";
  //char *ele_url = "https://elephant-cte.colorcloud.com";
  char *ele_url = "https://elephant-cte1:9443";
  char *local_url = "https://localhost.colorcloud.com:9443";
  char url[256];
  char apiurl[256];
  time_t now;
  struct timeval tv;
  clock_t clk;
  struct ThreadUri *pthrduri;
  pid_t pid;
  struct rlimit rlmt;

  while ((c = getopt (argc, argv, "auvslrpmifb:n:")) != -1)
    switch (c){
      case 'v':
        verbose = 1;
        break;
      case 'l':     // test to localhost
        localhost = 1;
        break;
      case 'n':
        numclients = atoi(optarg);   // args is in char string. use atoi
        break;
      case 'r':  // registration endpoint
        registermode = 1;
        sprintf(apiurl, "/client/v2/register");
        break;
      case 'p':  // push listen end point
        listenmode = 1;
        sprintf(apiurl, "/client/v1/puid-0");
        break;
      case 'm':   // cause mem profile
        sprintf(apiurl, "/profile");
        break;
      case 'f':   // full client, do registration and push listen
        fullmode = 1;
        sprintf(apiurl, "/client/v2/register");  // full flow started from register.
        break;
      case 's':
        refreshmode = 1;
        sprintf(apiurl, "/client/v1/refresh");  // refesh API
        break;
      case 'u':   // unit test mode, end immediately after getting response
        unitmode = 1;
        localhost = 1;
        break;
      case 'a':   // unit test of un-authorized request
        unauthorizedlisten = 1;
        break;
      case 'b':   // back off settings
        backoff = atoi(optarg);
        break;
      case 'i':   // generate sequential id for test
        sequentialId = 1;
        break;
      default:
        abort();
  }

  getrlimit(RLIMIT_NPROC, &rlmt);
  vbprintf("rlimit_nproc soft %d hard %d\n", rlmt.rlim_cur, rlmt.rlim_max);

  //fprintf(stdout, "verbose %d num-clients %d optind %d argv %s\n", verbose, numclients, optind, argv[optind]);
  fprintf(stdout, "verbose %d num-clients %d optind %d api %s argv %s\n",
          verbose, numclients, optind, apiurl, argv[optind]);

  memset(&act, 0, sizeof(struct sigaction));
  act.sa_handler = SIG_IGN;
  sigaction(SIGPIPE, &act, 0);

  SSL_load_error_strings();
  SSL_library_init();

  if(argc < 2){
    fprintf(stdout, "Usage : ./spdyclient -v -l -n num-clients -r -p -m\n");
    exit(0);
  }

  if(localhost){
    strcpy(url, local_url);
  }else{
    strcpy(url, ele_url);
  }
  strcat(url, apiurl);
  vbprintf("url :%s\n", url);

  //rv = parse_uri(&uri, argv[optind]);

  tid = (pthread_t*)malloc(sizeof(pthread_t)*numclients);
  memset(tid, 0, sizeof(pthread_t)*numclients);
  memset(&tattr, 0, sizeof(pthread_attr_t));
  pthread_attr_setstacksize(&tattr, 2*16*1024);

  pthread_key_create(&tkey, NULL);   // create common thread local key for all

  for(i=0;i<numclients;i++){
      now = time(0);
      gettimeofday(&tv, NULL);
      pid = getpid();

      // create thread local key, malloc for each thread
      // init all the fields with zero and init url end point
      pthrduri = (struct ThreadUri*)malloc(sizeof(struct ThreadUri));
      memset(pthrduri->clientId, 0, sizeof(pthrduri->clientId));
      memset(pthrduri->pushId, 0, sizeof(pthrduri->pushId));
      memset(pthrduri->pushData, 0, sizeof(pthrduri->pushData));
      memset(pthrduri, 0, sizeof(struct ThreadUri));

      // parse url into thread local uri
      rv = parse_uri(&pthrduri->uri, url);
      if(rv != 0) {
        die("parse_uri failed");
      }
      strcpy(pthrduri->url, url);

    // listen mode, populate client id and push id
    if(listenmode){
        vbprintf("now : sec: %ld, usec %ld, pid %d \n", tv.tv_sec, tv.tv_usec, pid);
        sprintf(pthrduri->clientId, "%d-%d-%ld-%ld", i, pid, tv.tv_sec, tv.tv_usec);
        sprintf(pthrduri->pushId, pthrduri->clientId);
    }

    // refresh mode, fake a client id
    if(refreshmode){
        sprintf(pthrduri->clientId, "%s", "refresh-test-client-1");
    }

    err = pthread_create(tid+i, NULL, createSpdyClient, (void*)pthrduri);
    if( err != 0){
        printf("pthread_create err: %d  [%s]\n", i, strerror(err));
    }else{
        printf("pthread_create successfully : %d\n", i);
    }

    if( numclients > 10){
        tim.tv_sec = 0;
        tim.tv_nsec = 80*1000*1000;    // 80 ms
        nanosleep(&tim, NULL);
    }
  }

  // wait for the thread
  for(i=0;i<numclients;i++){
      pthread_join((pthread_t)*(tid+i), NULL);   // wait for thread join
      printf(" joining thread %d...\n", i);
  }

  return EXIT_SUCCESS;
}
