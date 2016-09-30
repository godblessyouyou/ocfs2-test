#!/bin/bash
#
PATH=$PATH:/sbin	# Add /sbin to the path for ocfs2 tools
RUNTIME=600		# 600 Seconds
USERNAME=`/usr/bin/whoami`
DATE=`/bin/date +%F-%H-%M`
NODE=`hostname`
SUDO="`which sudo` -u root"
DEBUGFS_BIN="`which sudo` -u root `which debugfs.ocfs2`"
TUNEFS_BIN="`which sudo` -u root `which tunefs.ocfs2`"
MKFS_BIN="`which sudo` -u root `which mkfs.ocfs2`"
GREP=`which grep`
CUT=`which cut`
DF=`which df`
ECHO="`which echo` -e"
AWK=`which awk`
MV=`which mv`
RM=`which rm`
Usage()
{
${ECHO} "Usage: ${0} <directory> <kernel source tarfile>\n";
exit 1;
}
#
# LogRC
#
LogRC()
{
if [ ${1} -ne 0 ]; then
	${ECHO} "Failed." >> ${LOGFILE};
else
	${ECHO} "Passed." >> ${LOGFILE};
fi;
END=$(date +%s);
DIFF=$(( ${END} - ${START} ));
${ECHO} "Runtime ${DIFF} seconds.\n" >> ${LOGFILE};
}
#
# LogMsg
#
LogMsg()
{
${ECHO} `date` >> ${LOGFILE};
${ECHO} "${1}\c" >> ${LOGFILE};
i=${#1};
while (( i < 60 ))
do
	${ECHO} ".\c" >> ${LOGFILE};
	(( ++i ));
done;
}
#
# GetDevInfo
#
GetDevInfo()
{
line=`${DF} -h ${DIRECTORY} | ${GREP} -v Filesystem`
DEVICE=`echo ${line} | ${AWK} -F" " '{print $1}'`
MOUNTPOINT=`echo ${line} | ${AWK} -F" " '{print $6}'`
if [ ${MOUNTPOINT} == "/" -o  ${MOUNTPOINT} == "" ]; then
	${ECHO} "Specified partition is not mounted.\n"
	${ECHO} "Aborting....\n"
	exit 1;
fi;
UUID=`${TUNEFS_BIN} -q -Q "uuid=%U\n" ${DEVICE}|${CUT} -f2 -d"="`
LABEL=`${TUNEFS_BIN} -q -Q "label=%V\n" ${DEVICE}|${CUT} -f2 -d"="`
if [ "X${LABEL}" == "X" ]; then
	LABEL="testlabel";
fi;
SLOTS=`${TUNEFS_BIN} -q -Q "slots=%N\n" ${DEVICE}|${CUT} -f2 -d"="`
CLUSTERSIZE_BITS=`${DEBUGFS_BIN} -R stats ${DEVICE} | grep Bits|\
	${AWK} -F" " '{print $8}'`;
BLOCKSIZE_BITS=`${DEBUGFS_BIN} -R stats ${DEVICE} | grep Bits|\
	${AWK} -F" " '{print $4}'`;
CLUSTERSIZE=`echo 2^${CLUSTERSIZE_BITS} |bc`;
BLOCKSIZE=`echo 2^${BLOCKSIZE_BITS} |bc`;
#
}
#
# aio-stress
#
run_aiostress()
{
LogMsg "aio-stress";
FILE1="aiostress1.dat";
FILE2="aiostress2.dat";
FILE3="aiostress3.dat";
FILE4="aiostress4.dat";
${BINDIR}/aio-stress -a 4k -b 32 -i 16 -O -l -L -t 8 -v ${DIRECTORY}/${FILE1} \
	${DIRECTORY}/${FILE2} ${DIRECTORY}/${FILE3} ${DIRECTORY}/${FILE4};
LogRC $?;
}
#
# Buildkernel
#
run_buildkernel()
{
LogMsg "buildkernel";
${BINDIR}/buildkernel.py -c -d ${DIRECTORY} -l ${O2TDIR}/log/build_${BUILD}.log \
	-n ${NODE} -t ${KERNELSRC};
${BINDIR}/buildkernel.py -e -d ${DIRECTORY} -l ${O2TDIR}/log/build_${BUILD}.log \
	-n ${NODE} -t ${KERNELSRC};
${BINDIR}/buildkernel.py -d ${DIRECTORY} -l ${O2TDIR}/log/build_${BUILD}.log \
	-n ${NODE} -t ${KERNELSRC};
LogRC $?;
}
#
# file_size_limits
#
run_filesizelimits()
{
LogMsg "check_file_size_limits";
if [ `uname -m` == "i686" ]; then
	BITSPERLONG=32;
else
	BITSPERLONG=64;
fi;
FILE="check_filesizelimits.dat";
${BINDIR}/check_file_size_limits -B ${BITSPERLONG} -b ${BLOCKSIZE_BITS} \
	-c ${CLUSTERSIZE_BITS} ${DIRECTORY}/${FILE};
LogRC $?;
}
#
# enospc
#
run_enospc()
{
LOOP=11
while true
do
	${SUDO} umount ${MOUNTPOINT};
	if [ $? -eq 0 ]; then
		break;
	fi;
	sleep 5;
done;
#
for((xx=1; xx<${LOOP}; xx++ ))
do
	START=$(date +%s)
	LogMsg "enospc ${xx}";
	${BINDIR}/enospc.sh ${O2TDIR}/log ${DEVICE};
	LogRC $?;
done;
#
${MKFS_BIN} -x -C ${CLUSTERSIZE} -b ${BLOCKSIZE} -N ${SLOTS} -L ${LABEL} \
	${DEVICE}
UUID=`${TUNEFS_BIN} -q -Q "uuid=%U\n" ${DEVICE}| ${CUT} -f2 -d"="`
${SUDO} mount -t ocfs2 ${DEVICE} ${MOUNTPOINT}
if [ $? -eq 0 ]; then
	${SUDO} mkdir -p ${DIRECTORY}
	${SUDO} chown ${USERNAME}  ${DIRECTORY}
else
	${ECHO} "Mount failed."
	exit 1;
fi;
}
#
# run_fill_verify_holes
#
run_fillverifyholes()
{
LogMsg "run_fill_verify_holes";
${BINDIR}/burn-in.sh -b ${BINDIR} -l ${O2TDIR}/log -c 10 -d ${DIRECTORY} \
	-i 100 -s 5000000 2>&1 >> /dev/null;
LogRC $?;
}
#
# logwriter
#
run_logwriter()
{
LogMsg "logwriter";
${BINDIR}/logwriter ${DIRECTORY}/logwriter.txt 100 100000;
LogRC $?;
}
#
# mmap_test
#
run_mmaptest()
{
LogMsg "mmap_test";
${BINDIR}/mmap_test ${DIRECTORY}/logwriter.txt;
LogRC $?;
}
#
# mmap_truncate
#
run_mmaptruncate()
{
LogMsg "mmap_truncate";
${BINDIR}/mmap_truncate -c ${CLUSTERSIZE_BITS} -s ${RUNTIME} \
	${DIRECTORY}/logwriter.txt;
LogRC $?;
}
#
# rename_write_race.sh
#
run_renamewriterace()
{
LogMsg "rename_write_race.sh";
${BINDIR}/rename_write_race.sh -d ${DIRECTORY} -i 10000;
LogRC $?;
}
#
#
# MAIN
#
#
. `dirname ${0}`/config.sh
#
if [ $# -ne 2 ]; then
	Usage;
fi;
DIRECTORY=${1};		# ocfs2 test directory
KERNELSRC=${2};		# gzipped kernel source tarfile
LOGFILE=${O2TDIR}/log/single_run_${DATE}.log;
#
# First check if the directory exists and is writable.
#
if [ ! -d ${DIRECTORY} -o ! -w ${DIRECTORY} ]; then
	${ECHO} "Directory ${DIRECTORY} does not exist or is not writable." \
		|tee -a ${LOGFILE};
fi;
#
# Second, check if the tar file exists.
#
if [ ! -f ${KERNELSRC} ]; then
	${ECHO} "Kernel Source tarfile ${KERNELSRC} does not exist.\n" \
		|tee -a ${LOGFILE};
fi;
#
STARTRUN=$(date +%s)
${ECHO} "`date` - Starting Single Node Regress test" > ${LOGFILE}
GetDevInfo;
#
START=$(date +%s)
run_enospc; 	# this needs sudo.
#
START=$(date +%s)
run_buildkernel;
#
START=$(date +%s)
run_filesizelimits;
#
START=$(date +%s)
run_aiostress;
#
START=$(date +%s)
run_fillverifyholes;
#
START=$(date +%s)
run_logwriter;
#
START=$(date +%s)
run_mmaptest;
#
START=$(date +%s)
run_mmaptruncate;
#
START=$(date +%s)
run_renamewriterace;
#
# Clean up the directory.
#
${RM} -f ${DIRECTORY}/iter*.txt
${RM} -f ${DIRECTORY}/check_filesizelimits.dat
${RM} -f ${DIRECTORY}/logwriter.txt
${RM} -f ${DIRECTORY}/mmap_test.txt
${RM} -f ${DIRECTORY}/_renametest*
END=$(date +%s);
DIFF=$(( ${END} - ${STARTRUN} ));
${ECHO} "Total Runtime ${DIFF} seconds.\n" >> ${LOGFILE};
${ECHO} "`date` - Ended Single Node Regress test" >> ${LOGFILE}
