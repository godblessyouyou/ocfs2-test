#!/bin/bash
#
# enospc.sh <outdir> <DEVICE>
#
if [ `dirname ${0}` == '.' ]; then
	if [ -f config.sh ]; then
		. `dirname ${0}`/config.sh
	fi;
else
	if [ -f `dirname ${0}`/config.sh ]; then
		. `dirname ${0}`/config.sh
	fi;
fi;

if [ $# != 2 ]
then
	echo "usage: enospc.sh <outdir> <DEVICE>"
	exit 0
fi

SUDO=/usr/bin/sudo
MOUNT_DIR="/enospc_test"
OUT=${1}/enospc_test.log
DEVICE=${2}
PRG=${BINDIR}/enospc_test
MKFS_BIN='/sbin/mkfs.ocfs2'
MKDIR=`which mkdir`
RMDIR=`which rmdir`
MOUNT=`which mount`
UMOUNT=`which umount`
ECHO=`which echo`
CHOWN=`which chown`
USERID=`/usr/bin/whoami`

${ECHO} "starting test at ${DATE}" > ${OUT}

${ECHO} "formating DEVICE ${DEVICE}" >> ${OUT}
${SUDO} ${MKFS_BIN} -x ${DEVICE} -b 4096 -C 4096 524288 >> ${OUT} 2>&1

if [ -d "${MOUNT_DIR}" ]
then 
	${ECHO} "directory ${MOUNT_DIR} exist" >> ${OUT}
else
	${SUDO} ${MKDIR} ${MOUNT_DIR}
fi

${ECHO} "mounting ${DEVICE} ..." >> ${OUT}
${SUDO} ${MOUNT} -t ocfs2 -o datavolume ${DEVICE} ${MOUNT_DIR}
${SUDO} ${CHOWN} --recursive ${USERID} ${MOUNT_DIR}
${PRG} ${MOUNT_DIR}
${SUDO} ${UMOUNT} ${MOUNT_DIR}
${SUDO} ${RMDIR} ${MOUNT_DIR}
