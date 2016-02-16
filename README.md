<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Jenkins build framework for iX projects](#jenkins-build-framework-for-ix-projects)
- [Getting Started](#getting-started)
- [FreeNAS Builds](#freenas-builds)
  - [freenas](#freenas)
  - [freenas-combo](#freenas-combo)
  - [freenas-tests](#freenas-tests)
- [Manually running test framework](#manually-running-test-framework)
- [FreeNAS Testing Framework](#freenas-testing-framework)
  - [Adding New tests](#adding-new-tests)
  - [Where are tests run?](#where-are-tests-run)
- [PC-BSD Builds](#pc-bsd-builds)
  - [all](#all)
  - [world](#world)
  - [ports](#ports)
  - [ports-meta-only](#ports-meta-only)
  - [ports-update-all](#ports-update-all)
  - [ports-update-pcbsd](#ports-update-pcbsd)
  - [image](#image)
  - [menu](#menu)
  - [clean](#clean)
  - [vm](#vm)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

Jenkins build framework for iX projects
===========

The scripts in this repo will allow you to build PC-BSD or FreeNAS, either
as an automated job from Jenkins or manually. It includes support to build
the following:

 * PC-BSD Builds -  world/pkg/iso/vm
 * FreeNAS Builds - iso/test
 * Jenkins automation


Getting Started
============

To prep a new system for building, first download the repo and install with
the following:

```
% git clone --depth=1 https://github.com/iXsystems/ixbuild.git
% cd ixbuild
% sudo make jenkins
```

With the install complete, you can now start builds of PC-BSD or FreeNAS with
the following commands:

 "/ixbuild/jenkins.sh <command> <target>"

A list of the possible build targets are located in the [builds directory.](https://github.com/iXsystems/ixbuild/tree/master/builds)

The various commands which can be called are listed in their respective FreeNAS
or PC-BSD sections below.

Example: (As root)
```
# /ixbuild/jenkins.sh freenas freenas-9 (Build FreeNAS 9.x)
or
# /ixbuild/jenkins.sh pkg pcbsd-current (Build PC-BSD -CURRENT)
```


FreeNAS Builds
============

The following commands are available to build FreeNAS:

freenas
---
Build FreeNAS ISOs / update files from sources, this may take a while.

freenas-combo
---
Create the ISO files and run the testing framework to check for regressions

freenas-tests
---
Run the regression testing framework. Will generate auto-install ISOs and
install them into a VM for testing purposes.

Manually running test framework
=======

Tests are located in the freenas/scripts/9.3-tests.sh and
freenas/scripts/10-tests.sh files. These scripts can also be run directly
by pointing them at a FreeNAS instance with the following syntax:

```
 # cd freenas/scripts && ./9.3-tests.sh
```

```
 *Optional* arguments to 9.3-tests.sh

 testset={smoke|complete|benchmark}

     smoke - Basic tests to check core functionality
  complete - More in-depth testing to check edge cases
 benchmark - Run tests which measure speeds

 module={smb|nfs|ftp|etc|etc}

   The various modules you want to run, multiple module= lines allowed. If not specified all
tests will be run.

 ip=<hostip>

 FreeNAS host/IP address

 user=<FreeNASUsername>

 FreeNAS username for REST auth

 password=<FreeNASpassword>

 FreeNAS password for REST auth
```


FreeNAS Testing Framework
============

Adding New tests
---

New tests can be written for FreeNAS 9.3.X by adding a test "module" to the 9.3 testing directory:

https://github.com/iXsystems/ixbuild/tree/master/freenas/9.3-tests

By setting REQUIRES="storage" you can list other testing modules which must be run before yours, I.E. "storage"
may be required to setup a zpool / dataset to perform testing of shares.


Where are tests run?
---

The tests for FreeNAS 9.3.X are currently being run on-commit. Committers will automatically get
an e-mail with results and log files on testing failures.

Tests / log output can be viewed at the following location:
https://builds.pcbsd.org/jenkins/view/FreeNAS%20ATF/



PC-BSD Builds
============

The following commands are available to build PC-BSD:

all
---

Will create the FreeBSD world, fetch packages or build ports from poudriere,
and then assemble an ISO file.

world
---

Will update the FreeBSD git repo and rebuild the FreeBSD world environment

ports
---

Will rebuild the local ports / pkgng repo, using poudriere, if enable in
pcbsd.cfg

ports-meta-only
---

Will do a poudriere build of just the PC-BSD specific meta-ports for creating
an ISO file, not the entire ports tree

ports-update-all
---

Will update the ports tree used by poudriere with portsnap and the pcbsd
build-files/ports-overlay directory in git.

ports-update-pcbsd
---

Will update the ports tree used by poudriere with the latest in the pcbsd
build-files/ports-overlay directory in git.

image
---

Will create a new ISO file from the local FreeBSD dist files and packages
from either local poudreire or remote PKGNG repo.

menu
---

Will launch a dialog-based menu with access to all the listed make targets

clean
---

Will cleanup any temp files in ${PROGDIR}/tmp

vm
---

Will create VM images of PC-BSD / TrueOS for VirtualBox / VMWare and raw disk

