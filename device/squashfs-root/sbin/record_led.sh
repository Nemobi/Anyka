#! /bin/sh
### BEGIN INIT INFO
# File:				led.sh	
# Description:      control led status
# Author:			gao_wangsheng
# Email: 			gao_wangsheng@anyka.oa
# Date:				2012-9-6
### END INIT INFO


led=/sys/class/leds/gree_led
pre_state=/tmp/record_led_state
mode=$1
brightness=$2
delay_off=$2
delay_on=$3
tm=$4
default_br=1
default_off=0
default_blk=100
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin
cfgfile="/etc/jffs2/anyka_cfg.ini"

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
	echo ${default_br} > ${led}/brightness
}

light_off_led()
{
	echo "none" > ${led}/trigger
	echo ${default_off} > ${led}/brightness
}

blink_led()
{
	light=`cat ${led}/brightness`
	if [ "$light" -eq "0" ]
	then
		light_on_led 
	fi
	
	echo "timer" > ${led}/trigger
	echo $delay_off > ${led}/delay_on
	echo $delay_on > ${led}/delay_off
}

#
# main:
#

if [ "$#" -lt "1" ]
then
	usage
	exit 2
fi

#增加强关灯的mode，便于在APP指示灯开关关闭时，开机强制关灯;以及避免机器运行过程中APP
#指示灯关闭时软件层做的清除各种灯的off状态
if [ "$mode" == "force_off" ]
then
	echo "$0 force_off"
	light_off_led
	exit 0
fi

	echo "$0 $*" >$pre_state
led_switch=`awk 'BEGIN {FS="="}/\[lookcam_ir_led\]/{a=1} a==1 &&
		$1~/^led_switch/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);
		gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`
if [ $led_switch -eq 0 ];then
	exit 0
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
	times)
		i=0
		if [ -z $delay_on ]           
                then                    
                        delay_on=$default_blk
                fi                   
                                             
                if [ -z $delay_off ]         
                then                          
                        delay_off=$default_blk
                fi       

		while [ $i -lt $tm ]
		do
		  light_on_led
		  usleep $delay_on
		  light_off_led
		  usleep $delay_off
		  i=`expr $i + 1`
		  #echo "$i"
		done
		light_on_led 1
		;;
	*)
		usage
		exit 1
		;;
esac

exit 0

