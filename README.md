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
 - poudriere (optional)
 - unicode.pf2 (required for grub-mkrescue)
Getting Started:

First, you will need to copy the following *.dist files in the root directory

pcbsd.cfg.dist -> pcbsd.cfg
pkg-pubkey.cert.dist -> pkg-pubkey.cert
pkg.conf.dist -> pkg.conf

Next, you will want to edit pcbsd.cfg and check that the options are correct
for the version of PC-BSD you plan on building.

If you are going to be pulling PKGNG packages from repo other than the
default PC-BSD repo, you will need to replace pkg.conf / pkg-pubkey.cert
with your own versions.

To start a build, run "make" in the source directory. FreeBSD sources will be 
downloaded from GIT automatically, and then a world / kernel built. Once
this build finishes, the builder will begin fetching packages from the 
pkgng repo specified in pkg.conf. Lastly the ISO will be built in the ~/iso
directory.

Before you can run "make image" you must have unicode.pf2 in /usr/local/share/grub/.
You can copy /boot/grub/pcbsdfont.pf2 if you have PC-BSD installed.  

/boot/grub/pcbsdfont.pf2 -> /usr/local/share/grub/unicode.pf2

Alternatively you may fetch pcbsdfont.pf2 from PC-BSD github.


Advanced Usage:

The following "make" targets are available:

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

