#!/bin/sh

# Create and manage rsync snapshots of a set of directory trees.

# This scripts is based on the work of Mike Rubel, Andrew J. Nelson, and rabraham.
#
# It was created to backup a Synology DS415+ because the tools packaged by Synology are broken
# (links are silently ignored) and I wanted something that would work with the versions of shell and
# rsync which comes pre-installed by Synology.  I tried to keep it a general solution that could be
# used on other platforms.
#


# Change Log
#
# 2015-12-12 - JDK - Genesis...
# 2015-12-13 - JDK - Made it work
#

# To Do List
#
# rsync dry-run prior to rotating snapshots
# clean up snapshots greater then $SNAP_COUNT
# fix dry-run/verbose/quiet behavior
#


# Functions
usage() {
	echo "Usage: $0 [-h -q -v -n] [-l <log>] [-i <N>] <src> [src]... <dest>"
	echo "\t-h\t\tthis help message"
	echo "\t-q\t\tpass --quiet flag to rsync"
	echo "\t-v\t\tincrease verbosity and pass --verbose flag to rsync"
	echo "\t-n\t\tdisplay commands which would be run and pass --dry-run flag to rsync"
	echo "\t-l logfile\tlog to the specified file"
	echo "\t-i N\t\tkeep N snapshots"
}


# Initialize defaults
VERBOSE=0
DRY_RUN=0
RSYNC_OPTIONS=""
LOG_FILE=""
#SRC_DIR=""
SNAP_COUNT=0
SRC_LIST=""
DEST_DIR=""
EXIT_STATUS=0


while getopts "hqvnl:i:" opt; do
	case $opt in
		h )
			usage
			exit 1
			;;
		q )
			RSYNC_OPTIONS="$RSYNC_OPTIONS --quiet"
			;;
		v )
			VERBOSE=1
			#RSYNC_OPTIONS="$RSYNC_OPTIONS --verbose"
			;;
		n )
			DRY_RUN=1
			RSYNC_OPTIONS="$RSYNC_OPTIONS --dry-run"
			;;
		l )
			LOG_FILE=$OPTARG
			;;
		i )
			SNAP_COUNT=$OPTARG
			;;
		? )
			usage
			exit 1
			;;
	esac
done
shift $(($OPTIND - 1))

# Need at least one SRC and a DEST
if [ $# -lt 2 ] ; then
	echo "Too few arguments"
	usage
	exit 1
fi
# SRC must be a directory - this may be wrong....?
while [ $# -gt 1 ] ; do
	if [ ! -d $1 ] ; then
		echo "Invalid directory: $1"
		usage
		exit 1
	fi
	SRC_LIST="$SRC_LIST $1"
	shift
done
DEST_DIR=$1
shift

# Make sure -i was supplied a number
if [ ! $SNAP_COUNT -ge 0 2>/dev/null ] ; then
	usage
	exit 1
fi



# Should be more paranoid here

# Rotate snapshots. Need to add logic to remove snapshots greater than $SNAP_COUNT
i=`expr $SNAP_COUNT - 1`
j=`expr $SNAP_COUNT - 2`

# Remove oldest snapshot as first step in rotation
[ $VERBOSE -eq 1 ] && echo "${i}, ${j}"
if [ -d ${DEST_DIR}.$i ] ; then
	RM_CMD="rm -rf ${DEST_DIR}.$i"
	if [ $DRY_RUN -eq 1 ] ; then
		echo $RM_CMD
	else
		[ $VERBOSE -eq 1 ] && echo $RM_CMD
		eval $RM_CMD
	fi
fi


while [ $i -gt 0 ] ; do

	[ $VERBOSE -eq 1 ] && echo "${i}, ${j}"

	if [ -d ${DEST_DIR}.$j ] ; then
		MV_CMD="mv ${DEST_DIR}.$j ${DEST_DIR}.$i"
		if [ $DRY_RUN -eq 1 ] ; then
			echo $MV_CMD
		else
			[ $VERBOSE -eq 1 ] && echo $MV_CMD
			eval $MV_CMD
		fi
	else
		MKDIR_CMD="mkdir ${DEST_DIR}.$i"
		if [ $DRY_RUN -eq 1 ] ; then
			echo $MKDIR_CMD
		else
			[ $VERBOSE -eq 1 ] && echo $MKDIR_CMD
			eval $MKDIR_CMD
		fi
	fi

	i=$j
	j=`expr $j - 1`

done

[ $VERBOSE -eq 1 ] && echo "${i}, ${j}"

# Create DEST_DIR as final step in rotation
MKDIR_CMD="mkdir -p ${DEST_DIR}.0"
if [ $DRY_RUN -eq 1 -o ] ; then
	echo $MKDIR_CMD
else
	[ $VERBOSE -eq 1 ] && echo $MKDIR_CMD
	eval $MKDIR_CMD
fi



# Build rsync command
RSYNC_COMMAND=" \
	rsync $RSYNC_OPTIONS \
		--archive \
		--delete \
		--human-readable \
		--link-dest=${DEST_DIR}.1 \
		$SRC_LIST \
		${DEST_DIR}.0 \
	"

# Execute rsync
if [ $DRY_RUN -eq 1 ] ; then
	echo $RSYNC_COMMAND
else
	[ $VERBOSE -eq 1 ] && echo $RSYNC_COMMAND
	eval $RSYNC_COMMAND
	EXIT_STATUS=$?
fi



exit $EXIT_STATUS


