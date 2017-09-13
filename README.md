<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Jenkins build framework for iX projects](#jenkins-build-framework-for-ix-projects)
- [Requirements](#requirements)
- [Getting Started](#getting-started)
- [Manually running test framework](#manually-running-test-framework)
- [FreeNAS Testing Framework](#freenas-testing-framework)
  - [Adding New tests](#adding-new-tests)
  - [Where are tests run?](#where-are-tests-run)
- [Use Jenkins FreeNAS or TrueNAS update servers (iX Internal only)](#use-jenkins-freenas-or-truenas-update-servers-ix-internal-only)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

Jenkins automation framework for iX projects
===========

The scripts in this repo will allow you to build TrueOS or FreeNAS, either
as an automated job from Jenkins or manually. It includes support to build
the following:

 * FreeNAS
 * TrueOS
 * iocage


Requirements
============

A system running TrueOS, with at minimum 16GB of memory.
(Building TrueOS packages in a reasonable time works best with 48GB or more)

Recommended:
* CPU: 8 Cores or more
* Memory: 16GB (For FreeNAS) 48GB (For TrueOS)
* Disk: 20GB (For FreeNAS) 200GB (For TrueOS)

[TrueOS Download Site](http://download.trueos.org/master/amd64/)


Getting Started
============

To prep a new system for building, first download the repo and install with
the following:

```
% git clone --depth=1 https://github.com/iXsystems/ixbuild.git
% cd ixbuild
% sudo make jenkins
```

During the installation you will be asked if you want to make this a "node" or "master",
the "master" setup will install and configure Jenkins. If you already have Jenkins
installed, using the "node" setup will prep the system to act as new builder for
your existing Jenkins service.

Once a new "master" is deployed, you can access your Jenkins interface from:

[http://localhost:8180/jenkins/](http://localhost:8180/jenkins/)

Using Resty client example
============

For bash edit ~/.bashrc and add the following line:

```
source /home/rishabh/ixbuild/utils/resty -W "http://10.211.1.139:80/" -H "Accept: application/json" -H "Content-Type: application/json" -u root:abcd1234
```

For csh/sh edit ~/.profile and add the following line:

```
. /home/rishabh/ixbuild/utils/resty -W "http://10.211.1.139:80/" -H "Accept: application/json" -H "Content-Type: application/json" -u root:abcd1234
```

Running resty client example

```
GET /api/v1.0/system/version/
```

For more examples see https://api.freenas.org


Setting options for jenkins
============

A few common options for FreeNAS builds:
```
export BUILDINCREMENTAL=true
export ARTIFACTONFAIL=yes
export ARTIFACTONSUCCESS=yes
```

For more options including VM backends for QA tests see:

https://github.com/iXsystems/ixbuild/blob/master/build.conf.dist

Build iX projects with jenkins
============

FreeNAS
```
sudo /ixbuild/jenkins.sh freenas freenas
```
TrueOS
```
sudo /ixbuild/jenkins.sh trueos-world trueos-current production
sudo /ixbuild/jenkins.sh trueos-pkg trueos-current production
sudo /ixbuild/jenkins.sh trueos-iso-pkg trueos-current production
sudo /ixbuild/jenkins.sh trueos-iso trueos-current production
```
iocage
```
sudo /ixbuild/jenkins.sh iocage_pkgs
```

Running test framework from jenkins
============

FreeNAS
```
sudo /ixbuild/jenkins.sh freenas-tests freenas
```
TrueOS
```
sudo /ixbuild/jenkins.sh ports-tests
```

Running test framework with pre-existing install from jenkins
============

FreeNAS
```
sudo /ixbuild/jenkins.sh freenas-run-tests freenas
```

Manually running test framework
=======

To prep a new system for running tests manually, first create a freenas.cfg 
before executing checkprogs:

```
 # cp freenas/freenas.cfg.dist freenas/freenas.cfg
 # cd freenas/scripts && ./checkprogs.sh
```

Tests are located in the freenas/scripts directory.  These scripts can also be run 
directly by pointing them at a FreeNAS instance with the following syntax:

FreeNAS

```
 # cd freenas/scripts && ./create-tests.sh
 # cd freenas/scripts && ./update-tests.sh
 # cd freenas/scripts && ./delete-tests.sh
```

```
 *Optional* arguments for test scripts

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

A create, update, delete directory exists for each directory of tests.  Tests which create an object should be added
to the create folder.  Tests which update an object should be added to the update folder.  Tests which delete an object 
should be added to delete folder.

New tests can be written for FreeNAS by adding a test "module" to the testing directories:

https://github.com/iXsystems/ixbuild/tree/master/freenas/tests/create

https://github.com/iXsystems/ixbuild/tree/master/freenas/tests/update

https://github.com/iXsystems/ixbuild/tree/master/freenas/tests/delete

By setting REQUIRES="storage" you can list other testing modules which must be run before yours, I.E. "storage"
may be required to setup a zpool / dataset to perform testing of shares.

Where are tests run?
---

The tests for FreeNAS are currently being run on-commit. Committers will automatically get
an e-mail with results and log files on testing failures.

Tests / log output can be viewed at the following location:

https://builds.ixsystems.com/jenkins/view/QA%20Tests/


Use Jenkins FreeNAS or TrueNAS update servers (iX Internal only)
=======

If you are on the iXsystems corporate network you can switch to using
the FreeNAS or TrueNAS update servers with the following files:

https://github.com/iXsystems/ixbuild/blob/master/prepnode/truenas-update.conf

https://github.com/iXsystems/ixbuild/blob/master/prepnode/freenas-update.conf

Simply download and rename the file to "update.conf" and upload it to the /data/
directory on your FreeNAS or TrueNAS box. The next time you check for updates it
will begin pulling from the Jenkins builds. 
