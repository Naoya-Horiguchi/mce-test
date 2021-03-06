#!/bin/bash

. ../../../lib/mce.sh

INJ_TYPE=0x00000008
APEI_IF=""
PFA_BIN=""
EDAC_TYPE=""

invalid()
{
	echo $*
	exit 1
}

apei_inj()
{
	echo $INJ_TYPE > $APEI_IF/error_type
	echo $1 > $APEI_IF/param1
	echo 0xfffffffffffff000 > $APEI_IF/param2
	echo 1 > $APEI_IF/notrigger
	echo 1 > $APEI_IF/error_inject
}

usage()
{
	cat <<-EOF
	usage: ${0##*/} [PFA program] [trigger interval time]
	example: ${0##*/} ./pfa 10

	EOF
}

main()
{
	if [ X"$1" = X -o X"$2" = X ]
	then
		usage
		exit 0
	fi

	PFA_BIN=$1
	check_debugfs

	APEI_IF=`cat /proc/mounts | grep debugfs | cut -d ' ' -f2 | head -1`/apei/einj

	#if einj is not builtin, just insmod it
	if [ ! -d $APEI_IF ]; then
		#if einj is a module, it is ensured to have been loaded
		modprobe einj param_extension=1 > /dev/null 2>&1
		[ $? -eq 0 ] || invalid "module einj isn't supported?"
	fi
	[ -f $APEI_IF/param1 ] ||
	invalid "no BIOS extension support for APEI on this platform"

	#check if the platform supports Correctable Memory Error injection
	cat $APEI_IF/available_error_type | grep -q $INJ_TYPE
	[ $? -ne 0 ] &&
	invalid "Necessary Error Injection for PFA is not supported on this platform"

	# remove possible EDAC module, otherwise, the error information will be ate
	# by EDAC module and mcelog will not get it.
	# By now, only i7core_edac and sb_edac hook into the mcelog kernel buffer
	cat /proc/modules | grep -q i7core_edac
	if [ $? -eq 0 ]; then
		EDAC_TYPE="i7core_edac"
	else
		cat /proc/modules | grep -q sb_edac
		[ $? -eq 0 ] && EDAC_TYPE="sb_edac"
	fi
	rmmod $EDAC_TYPE >/dev/null 2>&1

	killall $PFA_BIN > /dev/null 2>&1
	$PFA_BIN | tee log &
	#wait to flush stdout into log
	sleep 1
	addr=`cat log |cut -d' '  -f8|tail -1`
	last_addr=$addr
	start=`date +%s`
	while :
	do
		echo inject address = $addr
		apei_inj $addr
		sleep $2
		addr=`cat log |cut -d' '  -f8|tail -1`
		end=`date +%s`
		timeout=`expr $end - $start`
		if [ X"$last_addr" != X"$addr" ]
		then
			break
		# assume it is enough to trigger PFA in 5 minutes
		elif [ $timeout -ge 300 ]; then
			invalid "Timeout! PFA is not triggered"
		fi
	done
}

cleanup()
{
	rm -f trigger log
	modprobe $EDAC_TYPE >/dev/null 2>&1
}

trap "cleanup" 0
main "$@"
