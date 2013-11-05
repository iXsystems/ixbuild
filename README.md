pcbsd-build
===========

Scripts to build PC-BSD world / kernel / ISO files

This program will do the compile of a FreeBSD world / kernel, 
fetch packages from the PC-BSD PKGNG CDN and assemble an ISO file. 

Requirements:

 - FreeBSD 9.2 or higher
 - A PKGNG repo for the target version / arch
 - git
 - zip
 - grub-mkrescue
 - xorriso

Getting Started:

To start a build, run "make" in the source directory. FreeBSD sources will be 
downloaded from GIT automatically, and then a world / kernel built. Once
this build finishes, the builder will begin fetching packages from the 
pkgng repo specified in pkg.conf. Lastly the ISO will be built in the ~/iso
directory. 


