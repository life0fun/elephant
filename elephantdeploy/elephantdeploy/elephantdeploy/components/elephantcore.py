from elmer.packages import packages, InstallOptions


packagedefs = packages(("artifactory:elephant,{{version}}",
                        InstallOptions(force=True, clean_cache=True)))
