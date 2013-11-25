#!/bin/sh

# Most of these dont need to be modified
#########################################################

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Source vars
. ${PROGDIR}/pcbsd.cfg

# Where on disk is the PCBSD GIT branch
GITBRANCH="${PROGDIR}/git/pcbsd"
export GITBRANCH

# Where are the dist files
DISTDIR="${PROGDIR}/fbsd-dist" ; export DISTDIR

# Set the dist files
BASEDIST="$DISTDIR/base.txz"
KERNDIST="$DISTDIR/kernel.txz"
L32DIST="$DISTDIR/lib32.txz"
export BASEDIST KERNDIST L32DIST


# Kernel Config
PCBSDKERN="GENERIC" ; export PCBSDKERN

# Set where we wish to copy our checked out FreeBSD source
WORLDSRC="${PROGDIR}/git/freebsd"
export WORLDSRC

# Where to build the world directory
PDESTDIR="${PROGDIR}/buildworld" ; export PDESTDIR
PDESTDIR9="${PROGDIR}/buildworld9" ; export PDESTDIR9
PDESTDIRFBSD="${PROGDIR}/buildworld-fbsd" ; export PDESTDIRFBSD
PDESTDIRSERVER="${PROGDIR}/buildworld-server" ; export PDESTDIRSERVER

# Set the PC-BSD Version
export PCBSDVER="${TARGETREL}"

# Set the ISO Version
REVISION="`cat ${WORLDSRC}/sys/conf/newvers.sh 2>/dev/null | grep '^REVISION=' | cut -d '"' -f 2`"
if [ -z "$REVISION" ] ; then
   REVISION="UNKNOWN"
fi
BRANCH="`cat ${WORLDSRC}/sys/conf/newvers.sh 2>/dev/null | grep '^BRANCH=' | cut -d '"' -f 2`"
if [ -z "$BRANCH" ] ; then
   BRANCH="UNKNOWN"
fi
export ISOVER="${REVISION}-${BRANCH}"

# Where are the config files
PCONFDIR="${GITBRANCH}/build-files/conf" ; export PCONFDIR

# Where do we place the log files
PLOGFILES="${PROGDIR}/log" ; export PLOGFILES

REALARCH="`uname -m`"
export REALARCH
case $ARCH in
   i386) FARCH="x86" ; export FARCH ;;
  amd64) FARCH="x64" ; export FARCH ;;
      *) FARCH="x86" ; export FARCH ;;
esac

# Set the location of packages needed for our Meta-Packages
export METAPKGDIR="${PROGDIR}/tmp"

# Poudriere Ports tag, change to use multiple ports trees
if [ -z "$POUDPORTS" ] ; then
   POUDPORTS="pcbsdports" ; export POUDPORTS
fi


# Poudriere Ports tag, change to use multiple ports trees
if [ -z "$POUDPORTS" ] ; then
   POUDPORTS="pcbsdports" ; export POUDPORTS
fi

# Poudriere variables
PBUILD="pcbsd-`echo $TARGETREL | sed 's|\.||g'`"
PJDIR="$POUD/jails/$PBUILD"
PPKGDIR="$POUD/data/packages/$PBUILD-$POUDPORTS"
PJPORTSDIR="$POUD/ports/$POUDPORTS"
export PBUILD PJDIR PJPORTSDIR PPKGDIR

# Check for required dirs
rDirs="/log /git /iso /fbsd-dist /tmp"
for i in $rDirs
do
  if [ ! -d "${PROGDIR}/${i}" ] ; then
     mkdir -p ${PROGDIR}/${i}
  fi
done

################
# Functions
################

exit_err() {
   echo "ERROR: $@"
   exit 1
}

clean_wrkdir()
{
  if [ -z "$1" ] ; then exit_err "Missing wrkdir..."; fi
  if [ -e "${1}" ]; then
    echo "Cleaning up ${1}"
    umount -f ${1}/dev >/dev/null 2>/dev/null
    umount -f ${1}/mnt >/dev/null 2>/dev/null
    umount -f ${1}/usr/src >/dev/null 2>/dev/null
    umount -f ${1} >/dev/null 2>/dev/null
    rmdir ${1}
  fi
}

mk_tmpfs_wrkdir()
{
  if [ -z "$1" ] ; then exit_err "Missing wrkdir..."; fi

  clean_wrkdir "$1"

  mkdir -p "${1}"
  mount -t tmpfs tmpfs "${1}"
}

extract_dist()
{
  if [ -z "$1" -o -z "$2" ] ; then exit_err "Missing variables..." ; fi
  if [ ! -e "$1" ] ; then exit_err "Invalid DISTFILE $1" ; fi
  if [ ! -d "$2" ] ; then exit_err "Invalid DESTDIR $2" ; fi

  echo "Extracting $1 to $2"
  tar xvf $1 -C $2 2>/dev/null
}

cp_overlay()
{
  echo "Copying overlay $1 -> $2"
  tar cvf - --exclude .svn -C ${1} .  2>/dev/null | tar xvmf - -C ${2} 2>/dev/null
}

git_fbsd_up()
{
  local lDir=${1}
  local rDir=${2}
  local oDir=`pwd`
  cd "${lDir}"

  echo "GIT checkout $GITFBSDBRANCH"
  git checkout ${GITFBSDBRANCH}

  echo "GIT pull: ${GITFBSDBRANCH}"
  git pull origin ${GITFBSDBRANCH}
  if [ $? -ne 0 ] ; then
     exit_err "Failed doing a git pull"
  fi

  cd "${oDir}"
  return 0
}

git_up()
{
  local lDir=${1}
  local rDir=${2}
  local oDir=`pwd`
  cd "${lDir}"

  local gbranch="$GITPCBSDBRANCH"
  if [ -z "$gbranch" ] ; then
     gbranch="master"
  fi

  echo "GIT checkout: ${gbranch}"
  git checkout ${gbranch}
  if [ $? -ne 0 ] ; then
     exit_err "Failed doing a git checkout"
  fi

  echo "GIT pull: ${1}"
  git pull 
  if [ $? -ne 0 ] ; then
     exit_err "Failed doing a git pull"
  fi

  cd "${oDir}"
  return 0
}

# Run-command, don't halt if command exits with non-0
rc_nohalt()
{
  local CMD="$1"

  if [ -z "${CMD}" ]
  then
    exit_err "Error: missing argument in rc_nohalt()"
  fi

  ${CMD} 2>/dev/null >/dev/null

};

# Run-command, halt if command exits with non-0
rc_halt()
{
  local CMD="$1"
  if [ -z "${CMD}" ]; then
    exit_err "Error: missing argument in rc_halt()"
  fi

  echo "Running command: $CMD"
  ${CMD}
  if [ $? -ne 0 ]; then
    exit_err "Error ${STATUS}: ${CMD}"
  fi
};

rtn()
{
  echo "Press ENTER to continue"
  read tmp
};

create_pkg_conf()
{
   cp ${PROGDIR}/pkg.conf ${PROGDIR}/tmp/pkg.conf
   cp ${PROGDIR}/pkg-pubkey.cert ${PROGDIR}/tmp/pkg-pubkey.cert
   sed -i '' "s|%RELVERSION%|$TARGETREL|g" ${PROGDIR}/tmp/pkg.conf
   sed -i '' "s|%ARCH%|$ARCH|g" ${PROGDIR}/tmp/pkg.conf
   sed -i '' "s|%PROGDIR%|$PROGDIR|g" ${PROGDIR}/tmp/pkg.conf

   if [ "$PKGREPO" = "local" ]; then
      cat ${PROGDIR}/tmp/pkg.conf | grep -v "packagesite:" > ${PROGDIR}/tmp/pkg.conf.local
      mv ${PROGDIR}/tmp/pkg.conf.local ${PROGDIR}/tmp/pkg.conf
      echo "packagesite: file://${PPKGDIR}" >> ${PROGDIR}/tmp/pkg.conf
   fi
}

create_installer_pkg_conf()
{
   cp ${PROGDIR}/pkg-pubkey.cert ${PROGDIR}/tmp/pkg-pubkey.cert

   echo "packagesite: file:///mnt" > ${PROGDIR}/tmp/pkg.conf
   echo "PUBKEY: /mnt/pkg-pubkey.cert" >> ${PROGDIR}/tmp/pkg.conf
   echo "PKG_CACHEDIR: /usr/local/tmp" >> ${PROGDIR}/tmp/pkg.conf

}

# Copy the ISO package files to a new location
cp_iso_pkg_files()
{
   if [ -d "$METAPKGDIR" ] ; then
     rm -rf ${METAPKGDIR}
   fi
   mkdir ${METAPKGDIR}

   create_pkg_conf

   echo "Fetching PC-BSD ISO packages... Please wait, this may take several minutes..."

   haveWarn=0

   # Pkgs to skip for now
   skipPkgs="misc/pcbsd-meta-gnome-games misc/pcbsd-meta-kde-education misc/pcbsd-meta-kde-games misc/pcbsd-meta-kde-toys misc/pcbsd-meta-kde-webdevkit misc/pcbsd-meta-mythtv misc/pcbsd-meta-xbmc misc/pcbsd-meta-kde-calligra misc/pcbsd-meta-kde-sdk misc/pcbsd-meta-rekonq misc/pcbsd-meta-development-embedded misc/pcbsd-meta-development-science"

   # Build a list of packages we need to fetch
   cd ${GITBRANCH}/build-files/ports-overlay
   local pkgList="ports-mgmt/pkg sysutils/pcbsd-utils sysutils/pcbsd-utils-qt4 `ls -d misc/pcbsd*` `ls -d misc/trueos*`"

   # Now fetch these packages
   for pkgName in $pkgList
   do
      # See if this is something we can skip for now
      skip=0
      for j in $skipPkgs
      do
        if [ "$pkgName" = "${j}" ] ; then skip=1; break; fi
      done
      if [ $skip -eq 1 ] ; then echo "Skipping $pkgBase.."; continue ; fi

      # Fetch the packages
      rc_halt "pkg-static -C ${PROGDIR}/tmp/pkg.conf fetch -y -d ${pkgName}"
    done

    # Copy pkgng
    cp ${PROGDIR}/tmp/All/pkg-*.txz ${PROGDIR}/tmp/All/pkg.txz

    # Now we need to grab the digests / packagesite / repo
    PSITE="`grep 'packagesite:' ${PROGDIR}/tmp/pkg.conf | cut -d ' ' -f 2`"
    rc_halt "fetch -o ${PROGDIR}/tmp/digests.txz ${PSITE}/digests.txz"
    rc_halt "fetch -o ${PROGDIR}/tmp/packagesite.txz ${PSITE}/packagesite.txz"
    rc_halt "fetch -o ${PROGDIR}/tmp/repo.txz ${PSITE}/repo.txz"
    create_installer_pkg_conf
}

update_poudriere_jail()
{
  # Setup fake poudriere file URL
  mkdir -p /fakeftp/pub/FreeBSD/releases/${ARCH}/${ARCH}/$PCBSDVER >/dev/null 2>/dev/null
  dfiles="src.txz base.txz doc.xz games.txz kernel.txz"
  if [ "$ARCH" = "amd64" ] ; then dfiles="$dfiles lib32.txz" ; fi
  for i in $dfiles
  do
    ln -sf "${DISTDIR}/$i" /fakeftp/pub/FreeBSD/releases/${ARCH}/${ARCH}/${PCBSDVER}/$i
  done

  echo "FREEBSD_HOST=file:///fakeftp/" >> /usr/local/etc/poudriere.conf

  # Clean old poudriere dir
  poudriere jail -d -j $PBUILD >/dev/null 2>/dev/null

  poudriere jail -c -j $PBUILD -v ${PCBSDVER} -a $ARCH
  if [ $? -ne 0 ] ; then
    cat /usr/local/etc/poudriere.conf | grep -v "^FREEBSD_HOST=file:///fakeftp/" >/tmp/.pconf.$$
    mv /tmp/.pconf.$$ /usr/local/etc/poudriere.conf
    echo "Failed to create poudriere jail"
    exit 1
  fi

  # Cleanup the hostname
  cat /usr/local/etc/poudriere.conf | grep -v "^FREEBSD_HOST=file:///fakeftp/" >/tmp/.pconf.$$
  mv /tmp/.pconf.$$ /usr/local/etc/poudriere.conf

  rm -rf /fakeftp
}

get_last_rev()
{
   oPWD=`pwd`
   rev=0
   cd "$1"
   rev=`git log -n 1 --date=raw ${1} | grep 'Date:' | awk '{print $2}'`
   cd $oPWD
   if [ $rev -ne 0 ] ; then
     echo "$rev"
     return 0
   fi
   return 1
}

check_essential_pkgs()
{
   echo "Checking essential pkgs..."
   haveWarn=0

   # Check all our PC-BSD meta-pkgs, warn if some of them don't exist
   # or cannot be determined
   chkList=`ls -d ${PJPORTSDIR}/sysutils/pcbsd-util* ${PJPORTSDIR}/misc/pcbsd-* ${PJPORTSDIR}/misc/trueos-*`
   for i in $chkList
   do

     # Get the pkgname
     pkgName=""
     pkgName=`make -C ${i} -V PKGNAME PORTSDIR=${PJPORTSDIR} __MAKE_CONF=/usr/local/etc/poudriere.d/$PBUILD-make.conf`
     if [ -z "${pkgName}" ] ; then
        echo "Could not get PKGNAME for ${i}"
        haveWarn=1
     fi

     # Check the arch type
     pArch=`make -C ${i} -V ONLY_FOR_ARCHS PORTSDIR=${PJPORTSDIR}`
     if [ -n "$pArch" -a "$pArch" != "$ARCH" ] ; then continue; fi

     if [ ! -e "${PPKGDIR}/All/${pkgName}.txz" ] ; then
        echo "WARNING: Missing package ${pkgName} for port ${i}"
        haveWarn=1
     else
     fi
   done
   if [ $haveWarn -ne 0 -a "$1" != "NO" ] ; then
      echo "Warning: Packages are missing! Continue?"
      echo -e "(Y/N)\c"
      read tmp
      if [ "$tmp" != "y" -a "$tmp" != "Y" ] ; then
         rtn
         exit 1
      fi
   fi

   return $haveWarn
}
