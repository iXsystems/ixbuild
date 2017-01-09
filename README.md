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

Jenkins build framework for iX projects
===========

The scripts in this repo will allow you to build PC-BSD or FreeNAS, either
as an automated job from Jenkins or manually. It includes support to build
the following:

 * FreeNAS 9.10 / 10.0
 * PC-BSD 10.2 / 10.3 / 11.0-CURRENT


Requirements
============

A system running PC-BSD/FreeBSD 11.0-CURRENT, with at minimum 16GB of memory.
(Building PC-BSD packages in a reasonable time works best with 48GB or more)

Recommended:
* CPU: 8 Cores or more
* Memory: 16GB (For FreeNAS) 48GB (For PC-BSD)
* Disk: 20GB (For FreeNAS) 200GB (For PC-BSD)

[PC-BSD Download Site](http://download.pcbsd.org/iso/)


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

FreeNAS 9.10

```
 # cd freenas/scripts && ./9.10-create-tests.sh
 # cd freenas/scripts && ./9.10-update-tests.sh
 # cd freenas/scripts && ./9.10-delete-tests.sh
````

FreeNAS 10.0

````
 # cd freenas/scripts && ./10-create-tests.sh
 # cd freenas/scripts && ./10-update-tests.sh
 # cd freenas/scripts && ./10-delete-tests.sh
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

New tests can be written for FreeNAS 9.10.X by adding a test "module" to the 9.10 testing directories:

https://github.com/iXsystems/ixbuild/tree/master/freenas/9.10-tests/create
https://github.com/iXsystems/ixbuild/tree/master/freenas/9.10-tests/update
https://github.com/iXsystems/ixbuild/tree/master/freenas/9.10-tests/delete

By setting REQUIRES="storage" you can list other testing modules which must be run before yours, I.E. "storage"
may be required to setup a zpool / dataset to perform testing of shares.

For more details, click the link above and checkout the README file.


Where are tests run?
---

The tests for FreeNAS 9.10.X are currently being run on-commit. Committers will automatically get
an e-mail with results and log files on testing failures.

Tests / log output can be viewed at the following location:
https://builds.ixsystems.com/jenkins/view/FreeNAS%20ATF/


Use Jenkins FreeNAS or TrueNAS update servers (iX Internal only)
=======

If you are on the iXsystems corporate network you can switch to using
the FreeNAS or TrueNAS update servers with the following files:

https://github.com/iXsystems/ixbuild/blob/master/prepnode/truenas-update.conf

https://github.com/iXsystems/ixbuild/blob/master/prepnode/freenas-update.conf

Simply download and rename the file to "update.conf" and upload it to the /data/
directory on your FreeNAS or TrueNAS box. The next time you check for updates it
will begin pulling from the Jenkins builds. 
