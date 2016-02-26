<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Jenkins build framework for iX projects](#jenkins-build-framework-for-ix-projects)
- [Getting Started](#getting-started)

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

During the installation you will be asked if you want to make this a "node" or "master",
the "master" setup will install and configure Jenkins. If you already have Jenkins
installed, using the "node" setup will prep the system to act as new builder for
your existing Jenkins service.

Once a new "master" is deployed, you can access your Jenkins interface from:

[http://localhost:8180/jenkins/](http://localhost:8180/jenkins/)
