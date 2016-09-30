#!/bin/bash
#
# Copyright (C) 2007 Oracle.  All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 021110-1307, USA.
#
# Description:  This test launches logwriter that extends the file
#		in a loop while this script keeps renaming the filename.
#		This test was useful in fixing a race in ocfs2 in
#		which rename was flushing stale inode->i_size to disk.
#
# Author: 	Sunil Mushran (sunil.mushran@oracle.com)
# 
ITER=100000	# Default number of iteractions
Usage()
{
echo "Usage: ${0} -d <directory> -i <iteractions>"
exit 1;
}
if [ `dirname ${0}` == '.' ]; then
	if [ -f config.sh ]; then
		. `dirname ${0}`/config.sh
	fi;
else
	if [ -f `dirname ${0}`/config.sh ]; then
		. `dirname ${0}`/config.sh
	fi;
fi;
while getopts "d:i:h?" args
do
	case "$args" in
		d) DIRECTORY="$OPTARG";;
		i) ITER="$OPTARG";;
		h) USAGE="yes";;
		?) USAGE="yes";;
	esac
done
if [ -n "${USAGE}" ]; then
	Usage;
fi;

if [ ! -d ${DIRECTORY} -o ! -w ${DIRECTORY} ]; then
	echo "${DIRECTORY} is not a valid directory or is not writable."
	exit 1;
fi;
FILE=${DIRECTORY}/_renametest_
APP=${BINDIR}/logwriter

${APP} ${FILE} 1 ${ITER} >/dev/null 2>&1 &

while true
do
	kill -0 %1 >/dev/null 2>&1
	if [ $? -ne 0 ]; then
		break
	fi

	jobs >/dev/null 2>&1

	OLDNAME=${FILE}
	for i in `seq 100`
	do
		NEWNAME=${FILE}${i}
		mv -v ${OLDNAME} ${NEWNAME}
		OLDNAME=${NEWNAME}
	done
	mv -v ${OLDNAME} ${FILE}
done

rm ${FILE}

