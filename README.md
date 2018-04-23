<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Jenkins build framework for iX projects](#jenkins-build-framework-for-ix-projects)
- [Requirements](#requirements)
- [Getting Started](#getting-started)
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
sudo /ixbuild/jenkins.sh freenas freenas-9.10
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
sudo /ixbuild/jenkins.sh freenas-tests freenas-9.10
```
TrueOS
```
sudo /ixbuild/jenkins.sh ports-tests
```

Use Jenkins FreeNAS or TrueNAS update servers (iX Internal only)
=======

If you are on the iXsystems corporate network you can switch to using
the FreeNAS or TrueNAS update servers with the following files:

https://github.com/iXsystems/ixbuild/blob/master/prepnode/truenas-update.conf

https://github.com/iXsystems/ixbuild/blob/master/prepnode/freenas-update.conf

Simply download and rename the file to "update.conf" and upload it to the /data/
directory on your FreeNAS or TrueNAS box. The next time you check for updates it
will begin pulling from the Jenkins builds. 
