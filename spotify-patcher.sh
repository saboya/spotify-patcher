#!/bin/bash
#
# Copyright (c) 2017 Rodrigo Saboya
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

BAD_LIBS=( \
	"libssl.so" \
	"libcrypto.so" \
	"libcurl.so.4" \
)

if [ "$#" -ne 1 ]; then
	echo "Usage: ./patch_spotify.sh /path/to/spotify/binary"
	exit 1
fi

SPOTIFY_BIN=$1

ELF_CLASS=$(readelf -h $SPOTIFY_BIN | grep Class | sed -nr 's/.*(ELF[0-9]+).*/\1/p')

case $ELF_CLASS in
	ELF64)
		printf "ELF64 binary\n"
		HEADER_SECTION_LENGTH=0X40
		SHINFO_OFFSET=0x2c
		;;
	ELF32)
		printf "ELF32 binary\n"
		HEADER_SECTION_LENGTH=0X28
		SHINFO_OFFSET=0x01c
		;;
	*)
		printf "Bad ELF class, exiting.\n"
		exit 1
		;;
esac

# http://stackoverflow.com/a/17841619
function join_by { local d=$1; shift; echo -n "$1"; shift; printf "%s" "${@/#/$d}"; }

function update_header()
{
	printf "Updating .gnu.version_r section headers:\n"
	local header_start=$(readelf -S $SPOTIFY_BIN | head -n1 | sed -nr 's/.*offset ([0-9a-fx]+).*/\1/p')
	local gnu_version_pos=$(readelf -S $SPOTIFY_BIN | grep '.gnu.version_r' | sed -nr 's/.*\[\s*([0-9]+)\].*/\1/p')

	local final_offset=$(($header_start+$HEADER_SECTION_LENGTH*$gnu_version_pos+$SHINFO_OFFSET))
	local new_size=$(printf '%04x%s' $(readelf -V $SPOTIFY_BIN 2>/dev/null | sed '/^$/,/^$/d' | grep "File:" | wc -l))

	printf "  Writing 0x%s to 0x%X\n" $new_size $final_offset
	echo -ne "\x${new_size:2:4}\x${new_size:0:2}" | dd of=$SPOTIFY_BIN seek=$final_offset oflag=seek_bytes bs=2 count=1 conv=notrunc status=none
}

function is_bad_lib()
{
	return $(echo $1 | grep -q $(join_by '\|' "${BAD_LIBS[@]/#/}"))
}

function parse_lib_offset() {
	printf $(echo $1 | cut -f1 -d':' | tr -d '[:space:]')
}

GOOD_OFFSETS=()

GNU_VERSION_OFFSET=$(readelf -V $SPOTIFY_BIN 2>/dev/null | grep -A1 "'.gnu.version_r'" | sed -nr 's/.*Offset: ([0-9a-fx]+).*/\1/p')

IFS_pre=$IFS
IFS=$'\n'
LIBS=($(readelf -V $SPOTIFY_BIN 2>/dev/null | sed '/^$/,/^$/d' | grep "File:"))

for lib in ${LIBS[@]}; do
	lib_offset=$(parse_lib_offset $lib)

	if [ ! -z ${last_good+x} ]; then
		if is_bad_lib $lib; then
			echo $lib
			printf "Bad lib found, updating pointer:\n"

			new_offset=$(printf '%04x%s' $(($lib_offset-$last_good)))

			if [[ $lib == ${LIBS[-1]} ]]; then
				printf "  Bad lib is last lib, setting pointer to 0.\n"
				new_offset=$(printf '%04x%s' 0)
			fi

			printf "  Writing 0x%s to 0x%X\n" $new_offset $last_pointer_byteoffset
			echo -ne "\x${new_offset:2:4}\x${new_offset:0:2}" | dd of=$SPOTIFY_BIN seek=$last_pointer_byteoffset oflag=seek_bytes bs=2 count=1 conv=notrunc status=none
		fi
	fi

	last_good=$lib_offset
	last_pointer_byteoffset=$(($GNU_VERSION_OFFSET+$last_good+0xc))
	last_pointer=$(hexdump -s $last_pointer_byteoffset -n 2 -e '"0x%04x\n"' $SPOTIFY_BIN)
done

update_header

exit 0
