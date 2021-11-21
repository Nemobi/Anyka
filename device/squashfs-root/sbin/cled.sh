#! /bin/sh
### BEGIN INIT INFO
# File:				led.sh	
# Description:      control led status
# Author:			gao_wangsheng
# Email: 			gao_wangsheng@anyka.oa
# Date:				2012-9-6
### END INIT INFO


led=/sys/class/leds/IR_CTRL
mode=$1
brightness=$2
delay_off=$2
delay_on=$3

default_br=1
default_blk=100
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin

usage()
{
	echo "Usage: $0 mode(on|off|blink) off_time on_time"
	echo "Light on led: $0 on brightness"
	echo "Light off led: $0 off"
	echo "Flash led in 200ms: $0 blink 100 100"
	exit 3
}

light_on_led()
{
	echo "none" > ${led}/trigger
	echo ${brightness} > ${led}/brightness
}

light_off_led()
{
	echo "none" > ${led}/trigger
	echo 0 > ${led}/brightness
}

blink_led()
{
	light=`cat ${led}/brightness`
	if [ "$light" -eq "0" ]
	then
		light_on_led 1
	fi
	
	echo "timer" > ${led}/trigger
	echo $delay_off > ${led}/delay_off
	echo $delay_on > ${led}/delay_on
}

#
# main:
#

if [ "$#" -lt "1" ]
then
	usage
	exit 2
fi

case "$mode" in
	on)
		if [ -z $brightness ]
		then
			brightness=$default_br
		fi
		light_on_led $brightness
		;;
	off)
		light_off_led
		;;
	blink)

		if [ -z $delay_on ]
		then
			delay_on=$default_blk
		fi

		if [ -z $delay_off ]
		then
			delay_off=$default_blk
		fi
		blink_led
		;;
	*)
		usage
		exit 1
		;;
esac

exit 0

