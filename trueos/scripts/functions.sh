#!/bin/sh

# Most of these dont need to be modified
#########################################################

# Where is the build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Source vars
. ${PROGDIR}/trueos.cfg

# Where on disk is the TRUEOS GIT branch
TRUEOSSRC="${PROGDIR}/git/trueos"
export TRUEOSSRC

# Where are the dist files
DISTDIR="${PROGDIR}/fbsd-dist" ; export DISTDIR

# Set the dist files
BASEDIST="$DISTDIR/base.txz"
KERNDIST="$DISTDIR/kernel.txz"
L32DIST="$DISTDIR/lib32.txz"
export BASEDIST KERNDIST L32DIST

# Location of FreeBSD sources
WORLDSRC="${PROGDIR}/git/freebsd"
export WORLDSRC

# Where to build the world directory
PDESTDIR="${PROGDIR}/buildworld" ; export PDESTDIR
PDESTDIR9="${PROGDIR}/buildworld9" ; export PDESTDIR9
PDESTDIRFBSD="${PROGDIR}/buildworld-fbsd" ; export PDESTDIRFBSD
PDESTDIRSERVER="${PROGDIR}/buildworld-server" ; export PDESTDIRSERVER

# Set the TrueOS Version
export TRUEOSVER="${TARGETREL}"

# Set the ISO Version
REVISION="`cat ${WORLDSRC}/sys/conf/newvers.sh 2>/dev/null | grep '^REVISION=' | cut -d '"' -f 2`"
if [ -z "$REVISION" ] ; then
   REVISION="UNKNOWN"
fi
BRANCH="`cat ${WORLDSRC}/sys/conf/newvers.sh 2>/dev/null | grep '^BRANCH=' | cut -d '"' -f 2`"
if [ -z "$BRANCH" ] ; then
   BRANCH="UNKNOWN"
fi
if [ -z "$ISOVER" ] ; then
  # This can be overridden via trueos.cfg
  export ISOVER="${REVISION}-${BRANCH}"
fi

# Where are the config files
PCONFDIR="${TRUEOSSRC}/build-files/conf/desktop" ; export PCONFDIR
if [ "$SYSBUILD" = "trueos" ] ; then
  PCONFDIR="${TRUEOSSRC}/build-files/conf/server" ; export PCONFDIR
fi
# Use the PICO config files
if [ "$PACKAGE_ARCH" = "armv6" ] ; then
  PCONFDIR="${TRUEOSSRC}/build-files/conf/pico" ; export PCONFDIR
fi

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

if [ -z "$JAILVER" ] ; then
  JAILVER="$TARGETREL"
fi
if [ -z "$PKGVERUPLOAD" ] ; then
  PKGVERUPLOAD="$JAILVER"
fi

# Poud variables
if [ "$SYSBUILD" = "trueos" -a -z "$DOINGSYSBOTH" ] ; then
  PBUILD="trueos-`echo $JAILVER | sed 's|\.||g'`"
  if [ "$ARCH" = "i386" ] ; then PBUILD="${PBUILD}-i386"; fi
else
  PBUILD="trueos-`echo $JAILVER | sed 's|\.||g'`"
  if [ "$ARCH" = "i386" ] ; then PBUILD="${PBUILD}-i386"; fi
fi
PPORTS="trueosports"
if [ -z "$PPKGDIR" ] ; then
  PPKGDIR="$POUD/data/packages/${JAILVER}-${PPORTS}"
fi
PJAILNAME="`echo $JAILVER | sed 's|\.||g'`"
PJPORTSDIR="/poud/ports/${PPORTS}"
export PBUILD JPORTSDIR PPKGDIR PPORTS PJAILNAME
if [ ! -e "$PPKGDIR" ] ; then
  mkdir -p ${PPKGDIR}
fi

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
  if [ -d "${PROGDIR}/tmp/repo" ] ; then
    rm -rf ${PROGDIR}/tmp/repo
  fi
  mkdir ${PROGDIR}/tmp/repo
  if [ -d "${PROGDIR}/tmp/sysrel" ] ; then
    rm -rf ${PROGDIR}/tmp/sysrel
  fi
  mkdir ${PROGDIR}/tmp/sysrel

  ABIVER=`echo $FREEBSDVER | cut -d '-' -f 1 | cut -d '.' -f 1`
  echo "PKG_CACHEDIR: ${PROGDIR}/tmp" > ${PROGDIR}/tmp/pkg.conf
  echo "ALTABI: freebsd:${ABIVER}:x86:64" >> ${PROGDIR}/tmp/pkg.conf
  echo "ABI: FreeBSD:${ABIVER}:amd64" >> ${PROGDIR}/tmp/pkg.conf


  # Doing a local package build
  echo "localrepo: {
           url: \"file://${PPKGDIR}\",
           enabled: true
        }" >  ${PROGDIR}/tmp/repo/local.conf
}

create_installer_pkg_conf()
{
   if [ -d "${PROGDIR}/tmp/repo-installer" ] ; then
      rm -rf ${PROGDIR}/tmp/repo-installer
   fi
   mkdir ${PROGDIR}/tmp/repo-installer

   echo "trueos-build: {
               url: \"file:///mnt\",
               enabled: true
              }" >  ${PROGDIR}/tmp/repo-installer/repo.conf
}

# Copy the ISO package files to a new location
cp_iso_pkg_files()
{
   if [ -d "$METAPKGDIR" ] ; then
     rm -rf ${METAPKGDIR}
   fi
   mkdir ${METAPKGDIR}

   create_pkg_conf

   echo "Fetching TrueOS ISO packages... Please wait, this may take several minutes..."

   haveWarn=0

   # Packages to fetch / include on install media
   local eP="${PCONFDIR}/iso-packages"

   # Use the version of pkgng for the target
   get_pkgstatic

   # Now fetch these packages
   while read pkgLine
   do
      pkgName=`echo $pkgLine | cut -d ' ' -f 1`
      pkgLocal=`echo $pkgLine | cut -d ' ' -f 2`
      localFlg=""
      pConf="-C ${PROGDIR}/tmp/pkg.conf"

      # See if this is something we can skip for now
      skip=0
      for j in $skipPkgs
      do
        if [ "$pkgName" = "${j}" ] ; then skip=1; break; fi
      done
      if [ $skip -eq 1 ] ; then echo "Skipping $pkgBase.."; continue ; fi

      # Fetch the packages
      rc_halt "${PKGSTATIC} ${pConf} -R ${PROGDIR}/tmp/repo/ fetch -y -o ${PROGDIR}/tmp $localFlg -d ${pkgName}"
      sync
      sleep 0.5
    done < $eP

    # Grab all the FreeBSD base packages
    rc_halt "cp ${PROGDIR}/fbsd-pkg/* ${PROGDIR}/tmp/All/"

    # Remove the FreeBSD Debug Packages
    rc_halt "rm ${PROGDIR}/tmp/All/FreeBSD*-debug-*.txz"

    # Copy pkgng
    rc_halt "cp ${PROGDIR}/tmp/All/pkg-*.txz ${PROGDIR}/tmp/All/pkg.txz"

    # Now we need to create the new repo files for DVD / USB
    rc_halt "cd ${PROGDIR}/tmp"
    rc_halt "${PKGSTATIC} repo ."
    rc_halt "cd ${PROGDIR}"

    # Cleanup PKGSTATIC
    rc_halt "rm ${PKGSTATIC}"

    create_installer_pkg_conf
}

update_poud_world()
{
  echo "Removing old jail - $PJAILNAME"
  poudriere jail -d -j $PJAILNAME
  rm -rf /poud/jails/$PJAILNAME

  # Nuke the built-in manifests from poudriere, since they don't match ours
  rm /usr/local/share/poudriere/MANIFESTS/* 2>/dev/null

  if [ "$PACKAGE_ARCH" = "armv6" ] ; then
    echo "Creating new ARM jail: $PJAILNAME - $JAILVER"
    poudriere jail -c -j $PJAILNAME -v $JAILVER -a arm.armv6 -m tar=file://${DISTDIR}/fbsd-dist.txz
    if [ $? -ne 0 ] ; then
      exit_err "Failed creating poudriere ARM jail"
    fi
    return 0
  fi

  echo "Creating new jail: $PJAILNAME - $JAILVER"
  poudriere jail -c -j $PJAILNAME -v $JAILVER -m url=file://${DISTDIR}
  if [ $? -ne 0 ] ; then
    exit_err "Failed creating poudriere jail"
  fi
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

   # Build the list of packages to check
   cat ${1} ${2} ${3} > /tmp/.pkgList.$$
   chkList=""
   while read line
   do
       # See if these dirs exist
       ls -d ${PJPORTSDIR}/${line} >/dev/null 2>/dev/null
       if [ $? -ne 0 ] ; then
          echo "Warning: No such port ($line) to check..."
          continue
       fi
       for i in `ls -d ${PJPORTSDIR}/${line}`
       do
          chkList="$chkList $i"
       done
   done < /tmp/.pkgList.$$
   rm /tmp/.pkgList.$$

   # Check all our TrueOS meta-pkgs, warn if some of them don't exist
   # or cannot be determined
   for i in $chkList
   do

     # Get the pkgname
     pkgName=""
     pkgName=`make -C ${i} -V PKGNAME PORTSDIR=${PJPORTSDIR} __MAKE_CONF=/usr/local/etc/poudriere.d/${PJAILNAME}-make.conf`
     if [ -z "${pkgName}" ] ; then
        echo "Could not get PKGNAME for ${i}"
        haveWarn=1
     fi

     # Check the arch type
     pArch=`make -C ${i} -V ONLY_FOR_ARCHS PORTSDIR=${PJPORTSDIR}`
     if [ -n "$pArch" -a "$pArch" != "$ARCH" ] ; then continue; fi

     if [ ! -e "${PPKGDIR}/All/${pkgName}.txz" ] ; then
        echo "Checked: ${PPKGDIR}/All/${pkgName}.txz"
        echo "WARNING: Missing package ${pkgName} for port ${i}"
        haveWarn=1
     else
     fi
   done

   return $haveWarn
}

get_pkgstatic()
{
  if [ "$1" = "EXTRACTONLY" ] ; then
    echo "Extracting pkg-static..."
  else
    echo "Setting up pkg-static.."
    create_pkg_conf
  fi

  rm /tmp/pkg-static >/dev/null 2>/dev/null
  rc_halt "tar xv --strip-components 4 -f ${PPKGDIR}/Latest/pkg.txz -C /tmp /usr/local/sbin/pkg-static" >/dev/null 2>/dev/null
  rc_halt "mv /tmp/pkg-static /tmp/pkg-static.$$" >/dev/null 2>/dev/null

  PKGSTATIC="/tmp/pkg-static.$$" ; export PKGSTATIC
  if [ "$1" = "EXTRACTONLY" ] ; then return; fi

  # Update the repo schema files before using
  rc_halt "${PKGSTATIC} -C ${PROGDIR}/tmp/pkg.conf -R ${PROGDIR}/tmp/repo/ update -f"
}
