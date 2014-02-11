#!/bin/sh
#        Author: Kris Moore
#   Description: Creates the ISO file
#     Copyright: 2009 PC-BSD Software / iXsystems
############################################################################

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Source the config file
. ${PROGDIR}/pcbsd.cfg

cd ${PROGDIR}/scripts

# Source our functions
. ${PROGDIR}/scripts/functions.sh


# Make sure we have our freebsd sources
if [ ! -d "${WORLDSRC}" ]; then
   rc_halt "git clone ${GITFBSDURL} ${WORLDSRC}"
   git_fbsd_up "${WORLDSRC}" "${WORLDSRC}"
else
  if [ -d "${WORLDSRC}/.git" ]; then
    echo "Updating FreeBSD sources..."
    git_fbsd_up "${WORLDSRC}" "${WORLDSRC}"
  fi
fi

# Make sure we have our pcbsd sources
if [ ! -d "${GITBRANCH}" ] ; then
   rc_halt "git clone ${GITPCBSDURL} ${GITBRANCH}"
else
  if [ -d "${GITBRANCH}/.git" ] ; then
    echo "Updating PC-BSD sources..."
    git_up "${GITBRANCH}" "${GITBRANCH}"
  fi
fi

# create_vnode ${UFSFILE} ${PARTITION} 
#
# Create a loop filesystem in file ${UFSFILE} containing files under
# ${PARTITION} directory (relative path from /)
create_vnode() {
    UFSFILE=$1; shift
    PARTITION=$1; shift

    SOURCEDIR=${PDESTDIR9}/${PARTITION}
    DESTMOUNTPOINT=${PDESTDIR9}/${PARTITION}

    cd $SOURCEDIR

    echo ${DEVICE}
}

# Unmount list of md devices
umount_md_devices() {
    for i in $@; do
	echo "Unmounting ${i}"
	rc_halt "umount -f ${i}"
	rc_halt "mdconfig -d -u ${i}"
    done
}

# uzip ${UFSFILE} ${UZIPFILE}
#
# makes an uzip fs on ${UZIPFILE} starting from ${UFSFILE} and removes
# ${UFSFILE}
uzip() {
    UFSFILE=$1; shift
    UZIPFILE=$1;

    echo -n "Compressing ${UFSFILE}..."
    rc_halt "mkuzip -v -s 65536 -o ${UZIPFILE} ${UFSFILE}"

    UFSSIZE=$(ls -l ${UFSFILE} | awk '{print $5}')
    UZIPSIZE=$(ls -l ${UZIPFILE} | awk '{print $5}')

    PERCENT=$(awk -v ufs=${UFSSIZE} -v uzip=${UZIPSIZE} 'BEGIN{print (100 - (100 * (uzip/ufs)));}')
    rm -f ${UFSFILE}
        
    echo " ${PERCENT}% saved"
}

prune_fs()
{
    rc_halt "cd ${PDESTDIR9}/"

    # If PRUNE_LIST file exists, delete files and dir listed in it
    PRUNE_LIST="${GITBRANCH}/build-files/conf/installcd-prunelist"

    if [ -f ${PRUNE_LIST} ]; then
      echo "Deleting files listed in ${PRUNE_LIST}"
      set +e
      while read line
      do
         if [ "$line" = "" -o "${line}" = " " ]; then continue; fi
         #echo "deleting ${PDESTDIR9}/$line"
         chflags -R noschg ${PDESTDIR9}/$line >/dev/null 2>/dev/null
         rm -rf ${PDESTDIR9}/$line >/dev/null 2>/dev/null
      done < ${PRUNE_LIST}
    fi
}
   
setup_usr_uzip() {
    echo "#### Creating /usr uzip file ####"
   
    # Preparing loop filesystem to be compressed
    mkdir -p ${PDESTDIR9}/uzip 2>/dev/null
    rc_halt "cd ${PDESTDIR9}/usr"

    # Figure out disk size and set up a vnode
    UFSFILE=${PDESTDIR9}/uzip/usr.ufs
    USRMNT=${PDESTDIR9}/usrmnt
    DIRSIZE=$(($(du -kd 0 | cut -f 1)))
    FSSIZE=$(($DIRSIZE + $DIRSIZE + 500))
    rc_halt "dd if=/dev/zero of=${UFSFILE} bs=1k count=${FSSIZE}"

    USRDEVICE=/dev/$(mdconfig -a -t vnode -f ${UFSFILE})
    rc_halt "newfs -b 4096 -n -o space ${USRDEVICE}"
    mkdir -p ${USRMNT} 2>/dev/null
    rc_halt "mount -o noatime ${USRDEVICE} ${USRMNT}"

    # Now copy the usr filesystem
    rc_halt "cd ${PDESTDIR9}/usr"
    find . -print -depth 2>/dev/null | cpio -dump -v ${USRMNT} 2>/dev/null

    # Remove old usrmnt and remount
    sleep 9
    rc_halt "umount -f ${USRDEVICE}"
    rc_halt "cd ${PDESTDIR9}/"
    rm -rf ${PDESTDIR9}/usr 2>/dev/null
    chflags -R noschg ${PDESTDIR9}/usr >/dev/null 2>/dev/null
    rm -rf ${PDESTDIR9}/usr
    rc_halt "mkdir ${PDESTDIR9}/usr"
    rmdir ${USRMNT}
    rc_halt "mount -o noatime ${USRDEVICE} ${PDESTDIR9}/usr"
    
    DEVICES=${USRDEVICE}

    trap "umount_md_devices ${DEVICES}; exit 1" INT

    rc_halt "cd ${PDESTDIR9}/"
	    
    echo "Filling the uncompressed fs with zeros to compress better"
    echo "Don't worry if you see a 'filesystem full' message here"
    zerofile=$(env TMPDIR=${PDESTDIR9}/usr mktemp -t zero)
    dd if=/dev/zero of=${zerofile} >/dev/null 2>/dev/null
    rm ${zerofile}
    set -e

    umount_md_devices ${DEVICES}
    trap "" INT
    uzip ${PDESTDIR9}/uzip/usr.ufs ${PDESTDIR9}/uzip/usr.uzip
    md5 -q ${PDESTDIR9}/uzip/usr.uzip > ${PDESTDIR9}/uzip/usr.uzip.md5

}

    
if [ -z ${PDESTDIR} ]
then
  echo "ERROR: PDESTDIR is still unset!"
  exit 1
fi

# Copy over a fresh set of package files for DVD
cp_iso_pkg_files

if [ -e "${PDESTDIR9}" ]; then
  echo "Removing ${PDESTDIR9}"
  umount -f ${PDESTDIR9}/mnt >/dev/null 2>/dev/null
  umount -f ${PDESTDIR9}/tmp/packages >/dev/null 2>/dev/null
  umount -f ${PDESTDIR9} >/dev/null 2>/dev/null
fi
    
# Create the tmp dir we will be using
mk_tmpfs_wrkdir ${PDESTDIR9}
extract_dist "${BASEDIST}" "${PDESTDIR9}"
extract_dist "${KERNDIST}" "${PDESTDIR9}"
if [ "$ARCH" = "amd64" ] ; then
  extract_dist "${L32DIST}" "${PDESTDIR9}"
fi

# Make sure GIT is updated
cd ${GITBRANCH}
git_up "${GITBRANCH}" "${GITBRANCH}"

# Lets install the packages we will be needing
mkdir ${PDESTDIR9}/mnt >/dev/null 2>/dev/null
rc_halt "mount_nullfs ${METAPKGDIR} ${PDESTDIR9}/mnt"
rc_halt "cp ${GITBRANCH}/build-files/conf/installcd-packages ${PDESTDIR9}/installcd-packages"
rc_halt "mount -t devfs devfs ${PDESTDIR9}/dev"

# Bootstrap PKGNG
rc_halt "pkg-static -c ${PDESTDIR9} add /mnt/All/pkg.txz"

echo '#!/bin/sh
cd /mnt/All
while read pkg
do
  echo "Adding PACKAGE: $pkg"
  pkg-static add -f ${pkg} >/tmp/pkg-log 2>/tmp/pkg-log
  if [ $? -ne 0 ] ; then
     echo "FAILED adding: $pkg"
     echo "Output:"
     cat /tmp/pkg-log
  fi
done </installcd-packages
rm /installcd-packages
cd /
rm /tmp/pkg-log

# Now lets setup our fonts
for i in `ls -d /usr/local/lib/X11/fonts/*`
do
  mkfontdir ${i}
  ln -fs ${i} /usr/local/share/fonts/`basename $i`
done

' > ${PDESTDIR9}/.insPkgs.sh
chmod 755 ${PDESTDIR9}/.insPkgs.sh
chroot ${PDESTDIR9} /.insPkgs.sh
rm ${PDESTDIR9}/.insPkgs.sh
umount -f ${PDESTDIR9}/mnt
umount -f ${PDESTDIR9}/dev

# Copy over the overlays/install-overlay directory to the pcbsdcd directory
##########################################################################
tar cvf - -C ${GITBRANCH}/overlays/install-overlay --exclude .svn . 2>/dev/null | tar xvpf - -C ${PDESTDIR9}/ 2>/dev/null

# Since GIT is stupid and doesn't allow tracking empty dirs, lets make them here
mkdir ${PDESTDIR9}/bin 2>/dev/null
mkdir ${PDESTDIR9}/dev 2>/dev/null
mkdir ${PDESTDIR9}/home 2>/dev/null
mkdir ${PDESTDIR9}/liveroot 2>/dev/null
mkdir ${PDESTDIR9}/media 2>/dev/null
mkdir ${PDESTDIR9}/memfs 2>/dev/null
mkdir ${PDESTDIR9}/mnt 2>/dev/null
mkdir ${PDESTDIR9}/mntuzip 2>/dev/null
mkdir ${PDESTDIR9}/tmp 2>/dev/null
mkdir -p ${PDESTDIR9}/var/lib/xkb 2>/dev/null
mkdir ${PDESTDIR9}/uzip 2>/dev/null

# Copy over the amd64 overlays if we need to
##########################################################################
if [ "$ARCH" = "amd64" ] ; then
  tar cvf - -C ${GITBRANCH}/overlays/install-overlay64 --exclude .svn . 2>/dev/null | tar xvpf - -C ${PDESTDIR9} 2>/dev/null
fi

# Set the PCBSDVERSION on the install disk
echo "${PCBSDVER}" > ${PDESTDIR9}/pcbsd-media

# Now set the FreeBSD version on disk
REVISION="`cat ${WORLDSRC}/sys/conf/newvers.sh | grep '^REVISION=' | cut -d '"' -f 2`"
if [ -z "$REVISION" ] ; then
   exit_err "Could not determine REVISION..."
fi
BRANCH="`cat ${WORLDSRC}/sys/conf/newvers.sh | grep '^BRANCH=' | cut -d '"' -f 2`"
if [ -z "$BRANCH" ] ; then
   exit_err "Could not determine BRANCH..."
fi
FBSDVER="${REVISION}-${BRANCH}"
echo "$FBSDVER" > ${PDESTDIR9}/fbsd-version


# Setup the root password on in PDESTDIR9 which we will copy later
echo '#!/bin/sh
echo "pcbsd" | pw usermod root -h 0'>${PDESTDIR9}/.setPass.sh
chmod 755 ${PDESTDIR9}/.setPass.sh
chroot ${PDESTDIR9} /.setPass.sh
rm ${PDESTDIR9}/.setPass.sh

# Lets prune the file-system before we start archving
prune_fs

# Compress the /root directory for extraction into a memory fs
rc_halt "tar cvJf ${PDESTDIR9}/uzip/root-dist.txz -C ${PDESTDIR9}/root ."
rm -rf ${PDESTDIR9}/root >/dev/null 2>/dev/null
mkdir ${PDESTDIR9}/root >/dev/null 2>/dev/null

# Compress the /var directory for extraction into a memory fs
rm -rf ${PDESTDIR9}/var/db/pkg
mkdir ${PDESTDIR9}/var/db/pkg
rc_halt "tar cvJf ${PDESTDIR9}/uzip/var-dist.txz -C ${PDESTDIR9}/var ."
rm -rf ${PDESTDIR9}/var >/dev/null 2>/dev/null
mkdir ${PDESTDIR9}/var >/dev/null 2>/dev/null

# Compress the /etc directory for extraction into a memory fs
rm -rf ${PDESTDIR9}/var/db/pkg
rc_halt "tar cvJf ${PDESTDIR9}/uzip/etc-dist.txz -C ${PDESTDIR9}/etc ."

# Symlink the /boot/zfs directory
rm -rf ${PDESTDIR9}/boot/zfs >/dev/null 2>/dev/null
rc_halt "ln -s /tmp/zfs ${PDESTDIR9}/boot/zfs"

# Copy over some /usr/bin utilities that we need before mounting /usr
cp ${PDESTDIR9}/usr/bin/cut ${PDESTDIR9}/bin/
chmod 755 ${PDESTDIR9}/bin/cut
cp ${PDESTDIR9}/usr/bin/du ${PDESTDIR9}/bin/
chmod 755 ${PDESTDIR9}/bin/du
cp ${PDESTDIR9}/usr/bin/cmp ${PDESTDIR9}/bin/
chmod 755 ${PDESTDIR9}/bin/cmp

# Cleanup
rm ${PROGDIR}/iso/* >/dev/null 2>/dev/null

# Make the uzip file
setup_usr_uzip

cd ${PROGDIR}/scripts

echo "Making DVD/USB Install Images"
${PROGDIR}/scripts/9.3.makedvd.sh
if [ $? -ne 0 ] ; then
   exit_err "Failed running 9.3.makedvd.sh"
fi

# Make the net install file directory now
echo "Making Net Files"
${PROGDIR}/scripts/9.6.makenetfiles.sh
if [ $? -ne 0 ] ; then
   exit_err "Failed running 9.6.makenetfiles.sh"
fi

umount -f ${PDESTDIR9} 2>/dev/null
rmdir ${PDESTDIR9}

exit 0
