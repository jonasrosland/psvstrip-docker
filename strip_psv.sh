#!/bin/bash

# -----------------------------------------------------------------------------
#
#	App Title:		strip_psv.sh
#	Author:			Jared Breland <jbreland@legroom.net>
#	Homepage:		https://www.legroom.net/software
#	License:		GNU General Public License, v3.0
#						http://www.gnu.org/licenses/gpl.html
#
#	Script Function:
#		Strip unique header and license info from PSV files as described here:
#		https://forum.no-intro.org/viewtopic.php?f=2&t=3443
#
#	Instructions:
#		Run 'strip_psv.sh -h' for usage instructions
#
#	Requirements:
#		xxd (part of Vim) - https://www.vim.org/
#			used to convert between binary and hexidecimal
#		grep - https://www.gnu.org/software/grep/)
#			used to find license offset
#		sed - http://sed.sourceforge.net/
#			used to strip trailing newlines from LIC file
#		dd, printf, tail, tr - https://www.gnu.org/software/coreutils/
#			basic GNU core utilities used for various tasks
#
#	Release History:
#		05/12/2021:
#			Initial release
# -----------------------------------------------------------------------------

# Static variables
readonly VERSION='1.0'
readonly PROG=$(basename $0)
readonly PROGDIR=$(dirname $0)
readonly TITLE=${PROG}

# Setup environment
QUIET=0
RESTORE=0
SAVE=0
PSVFILE=

# PSV parameters
HEADERLEN=512
UNKOFFSET=7168
UNKLEN=608
LICPATTERN="\xFF\xFF\x00\x01\x00\x01\x04\x02\x00\x00\x00\x00\x00\x00\x00\x00"
LIC1OFFSET=80
LIC1LEN=16
LIC2OFFSET=160
LIC2LEN=352

# Function to display correct usage information
function warning() {
	echo -e "Usage: ${PROG} [-q] [-r|-s] <Game.psv>"
	echo -e "Strip (or restore) PSV header and license information for Vita games\n"
	echo -e "Options:"
	echo -e "  -q  quiet output"
	echo -e "  -r  restore header/license content, if previously saved"
	echo -e "  -s  save header/license content that is stripped"
	echo -e "\nNote: the save/restore options will store data in a file named Game.psv-lic"
	exit 0
}

# Generically validate binaries used by other functions in this file
function bincheck() {
	while [ -n "$1" ]; do
		[ ! -f "$(which $1 2>/dev/null)" ] && echo "Error: required binary $1 cannot be found" && exit 1
		shift
	done
}

# Process arguments
[ $# -eq 0 ] && warning
while [ $# -ne 0 ]; do
	# Display help if requested
	if [ "$1" == "-h" -o "$1" == "--help" -o "$1" == "-?" ]; then
		warning

	# Display version of requested
	elif [ "$1" == "-V" -o "$1" == "--version" ]; then
		echo "${TITLE} ${VERSION}"
		exit 0

	# Set quiet mode
	elif [ "$1" == "-q" ]; then
		QUIET=1
	
	# Enable restore mode
	elif [ "$1" == "-r" ]; then
		RESTORE=1
	
	# Enable save mode
	elif [ "$1" == "-s" ]; then
		SAVE=1

	# Assume game name is final argument
	else
		if [ -z "$1" ]; then
			warning
		elif [ -n "${PSVFILE}" ]; then
			echo "Error: Only one PSV file may be specified"
			exit 1
		fi
		PSVFILE="${1}"

	fi
	shift
done

# Verify needed binaries are present
bincheck xxd grep sed dd printf tail tr

# Verify PSV file exists
if [ ! -f "${PSVFILE}" ]; then
	echo "Error: '${PSVFILE}' does not exist"
	exit 2
else
	# If so, set additional file name variables
	LICFILE="${PSVFILE}-lic"
	STRIPFILE="${PSVFILE%.*}.stripped.psv"
	RESTOREFILE="${PSVFILE%.*}.restored.psv"
fi

# Verify restore and save not set at the same time
if [ ${RESTORE} -eq 1 -a ${SAVE} -eq 1 ]; then
	echo "Error: The Save and Restore options may not be both enabled"
	exit 3
fi

# If restoring, verify LIC file exists
if [ ${RESTORE} -eq 1 -a ! -f "${LICFILE}" ]; then
	echo "Error: Saved header/license info was not found in file:"
	echo "${LICFILE}"
	exit 3
fi

# Begin processing file

# If stripping file...
if [ ${RESTORE} -eq 0 ]; then
	[ ${QUIET} -eq 0 ] && echo "Stripping PSV header and license from '${PSVFILE}'..."
	[ ${SAVE} -eq 1 ] && echo "# Original file: ${PSVFILE}" >"${LICFILE}"

	# Strip the initial PSV header
	[ ${QUIET} -eq 0 ] && echo "   Stripping header"
	if [ ${SAVE} -eq 1 ]; then
		echo -n "PSVHEADER=" >>"${LICFILE}"
		dd bs=1 count=${HEADERLEN} status=none if="${PSVFILE}" | xxd -p | tr '\n' '|' >>"${LICFILE}"
		echo >>"${LICFILE}"
	fi
	tail -c +$((HEADERLEN + 1)) "${PSVFILE}" >"${STRIPFILE}"

	# Null the 'unknown' area
	[ ${QUIET} -eq 0 ] && echo "   Clearing unknown data"
	if [ ${SAVE} -eq 1 ]; then
		echo -n "UNKNOWN=" >>"${LICFILE}"
		dd bs=1 skip=${UNKOFFSET} count=${UNKLEN} status=none if="${STRIPFILE}" | xxd -p | tr '\n' '|' >>"${LICFILE}"
		echo >>"${LICFILE}"
	fi
	printf '\x00%.0s' $(seq 1 ${UNKLEN}) | dd bs=1 seek=${UNKOFFSET} count=${UNKLEN} conv=notrunc status=none of="${STRIPFILE}"

	# Get license offset
	[ ${QUIET} -eq 0 ] && echo "   Finding license offset"
	LICOFFSET=$(LANG=C grep -obUaP -m1 "${LICPATTERN}" "${STRIPFILE}" | cut -f1 -d:)
	if [ ${SAVE} -eq 1 ]; then
		echo "LICOFFSET=${LICOFFSET}" >>"${LICFILE}"
	fi

	# Null license section 1
	[ ${QUIET} -eq 0 ] && echo "   Clearing license section 1"
	if [ ${SAVE} -eq 1 ]; then
		echo -n "LIC1=" >>"${LICFILE}"
		dd bs=1 skip=$((LICOFFSET + LIC1OFFSET)) count=${LIC1LEN} status=none if="${STRIPFILE}" | xxd -p | tr '\n' '|' >>"${LICFILE}"
		echo >>"${LICFILE}"
	fi
	printf '\x00%.0s' $(seq 1 ${LIC1LEN}) | dd bs=1 seek=$((LICOFFSET + LIC1OFFSET)) count=${LIC1LEN} conv=notrunc status=none of="${STRIPFILE}"

	# Null license section 2
	[ ${QUIET} -eq 0 ] && echo "   Clearing license section 2"
	if [ ${SAVE} -eq 1 ]; then
		echo -n "LIC2=" >>"${LICFILE}"
		dd bs=1 skip=$((LICOFFSET + LIC2OFFSET)) count=${LIC2LEN} status=none if="${STRIPFILE}" | xxd -p | tr '\n' '|' >>"${LICFILE}"
		echo >>"${LICFILE}"
	fi
	printf '\x00%.0s' $(seq 1 ${LIC2LEN}) | dd bs=1 seek=$((LICOFFSET + LIC2OFFSET)) count=${LIC2LEN} conv=notrunc status=none of="${STRIPFILE}"

	# Cleanup and exit
	[ ${QUIET} -eq 0 ] && echo "Process complete"
	if [ ${SAVE} -eq 1 ]; then
		# Strip trailing pipes so they don't get converted to newlines on restore
		sed -e 's/^\(.*\)|$/\1/' -i "${LICFILE}"
		[ ${QUIET} -eq 0 ] && echo "   Header/license info saved to '${LICFILE}'"
	fi

# Otherwise, restore previous data...
else
	[ ${QUIET} -eq 0 ] && echo "Restoring PSV header and license to '${PSVFILE}'..."

	# Populate header/license info from LIC file
	# https://unix.stackexchange.com/a/562943/471253
	[ ${QUIET} -eq 0 ] && echo "   Reading header/license data"
	declare -A LICPROP
	while IFS='=' read -d $'\n' -r k v; do
		[[ "$k" =~ ^([[:space:]]*|[[:space:]]*#.*)$ ]] && continue
		LICPROP[${k}]="${v}"
	done <"${LICFILE}"

	#echo "PSVHEADER = ${LICPROP['PSVHEADER']}"
	#echo "UNKNOWN = ${LICPROP['UNKNOWN']}"
	#echo "LICOFFSET = ${LICPROP['LICOFFSET']}"
	#echo "LIC1 = ${LICPROP['LIC1']}"
	#echo "LIC2 = ${LICPROP['LIC2']}"

	# Prepend the initial PSV header
	[ ${QUIET} -eq 0 ] && echo "   Prepending header"
	echo "${LICPROP['PSVHEADER']}" | tr '|' '\n' | xxd -r -p >"${RESTOREFILE}"
	cat "${PSVFILE}" >>"${RESTOREFILE}"

	# Restore the 'unknown' area
	[ ${QUIET} -eq 0 ] && echo "   Restoring unknown data"
	echo "${LICPROP['UNKNOWN']}" | tr '|' '\n' | xxd -r -p | dd bs=1 seek=$((UNKOFFSET + HEADERLEN)) count=${UNKLEN} conv=notrunc status=none of="${RESTOREFILE}"

	# Restore license section 1
	[ ${QUIET} -eq 0 ] && echo "   Restoring license section 1"
	echo "${LICPROP['LIC1']}" | tr '|' '\n' | xxd -r -p | dd bs=1 seek=$((LICPROP['LICOFFSET'] + LIC1OFFSET + HEADERLEN)) count=${LIC1LEN} conv=notrunc status=none of="${RESTOREFILE}"

	# Restore license section 2
	[ ${QUIET} -eq 0 ] && echo "   Restoring license section 2"
	echo "${LICPROP['LIC2']}" | tr '|' '\n' | xxd -r -p | dd bs=1 seek=$((LICPROP['LICOFFSET'] + LIC2OFFSET + HEADERLEN)) count=${LIC2LEN} conv=notrunc status=none of="${RESTOREFILE}"

	# Cleanup and exit
	[ ${QUIET} -eq 0 ] && echo "Process complete"
	[ ${QUIET} -eq 0 ] && echo "   Restored to '${RESTOREFILE}'"
fi

exit 0
