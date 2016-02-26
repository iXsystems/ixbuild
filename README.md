<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Jenkins build framework for iX projects](#jenkins-build-framework-for-ix-projects)
- [Requirements](#requirements)
- [Getting Started](#getting-started)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

Jenkins build framework for iX projects
===========

The scripts in this repo will allow you to build PC-BSD or FreeNAS, either
as an automated job from Jenkins or manually. It includes support to build
the following:

 * FreeNAS 9.3 / 9.10 / 10.0
 * PC-BSD 10.2 / 10.3 / 11.0-CURRENT


Requirements
============

A system running PC-BSD/FreeBSD 11.0-CURRENT, with at minimum 16GB of memory.
(Building PC-BSD packages in a reasonable time works best with 48GB or more)

Recommended:
CPU: 8 Cores or more
Memory: 16GB (For FreeNAS) 48GB (For PC-BSD)
Disk: 20GB (For FreeNAS) 200GB (For PC-BSD)

[PC-BSD Download](http://download.pcbsd.org/iso/)


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
