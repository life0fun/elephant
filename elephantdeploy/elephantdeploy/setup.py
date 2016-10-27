#!/usr/bin/env python

from setuptools import setup, find_packages

__version__ = '1.2'

# Jenkins will replace __build__ with a unique value.
__build__ = ''

setup(name='elephantdeploy',
      version=__version__ + __build__,
      description='Deploy project for elephant',
      author='Location Labs',
      author_email='info@locationlabs.com',
      url='http://locationlabs.com',
      packages=find_packages(exclude=['*.tests']),
      setup_requires=[
          'nose>=1.0'
      ],
      install_requires=[
          'elmer>=1.2.dev',
          'fabware>=1.0',
          'lvsdeploy>=1.0.dev',
      ],
      include_package_data=True,
      entry_points={
          'confab.extensions': [
              'elephant = elephantdeploy.extension:componentdefs',
          ],
      },
      )
