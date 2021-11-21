#! /bin/sh
### BEGIN INIT INFO
# File:				service.sh
# Provides:         init service
# Required-Start:   $
# Required-Stop:
# Default-Start:
# Default-Stop:
# Short-Description:web service
# Author:			gao_wangsheng
# Email: 			gao_wangsheng@anyka.oa
# Date:				2012-12-27
### END INIT INFO

MODE=$1
PUSHID_MODE=0
TEST_MODE=0
FACTORY_TEST=0
UPDATE_MODE=0
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin
cfgfile="/etc/jffs2/anyka_cfg.ini"
usage()
{
	echo "Usage: $0 start|stop)"
	exit 3
}

stop_service()
{

	killall -12 daemon
	echo "watch dog closed"
	#sleep 5
	killall daemon
	killall cmd_serverd

	/usr/sbin/anyka_ipc.sh stop

	echo "stop network service......"
	killall net_manage.sh

    /usr/sbin/eth_manage.sh stop
    /usr/sbin/wifi_manage.sh stop
}

start_service ()
{
	cmd_serverd
	if [ $FACTORY_TEST = 1 ]; then
		insmod /mnt/usbnet/udc.ko
	    insmod /mnt/usbnet/g_ether.ko
		/usr/bin/tcpsvd 0 21 ftpd -w / -t 600 &
	    sleep 1
	    ifconfig eth0 up
		telnetd &
	    sleep 1
	    /usr/sbin/eth_manage.sh start
		 echo "start product test."
		 /mnt/usbnet/product_test & 
	elif [ $PUSHID_MODE = 1 ]; then
		/usr/sbin/wifi_led.sh blink 200 200 
		while [ ! -e /etc/jffs2/lookcam.conf ]
		do
			#/usr/bin/ak_adec_demo 8000 2 mp3 /usr/share/pushID.mp3
			/usr/sbin/capture_led.sh blink 200 200
			if grep -qs '/dev/mmcblk0' /proc/mounts;then
				echo "pls push sn."
				#/usr/sbin/ap.sh start
				/mnt/lookcamSn/tf_burn_id.sh
				#sleep 1
				umount /mnt
			else
				if test -e /dev/mmcblk0p1 ;then
					mount -rw /dev/mmcblk0p1 /mnt
				elif test -e /dev/mmcblk0 ;then
					mount -rw /dev/mmcblk0 /mnt
				fi
				sleep 1
			fi
		done
	else
		if [ $UPDATE_MODE = 1 ]; then
	        echo "to do software update check."
	        /usr/sbin/update.sh
	    fi
		led_switch=`awk 'BEGIN {FS="="}/\[lookcam_ir_led\]/{a=1} a==1 &&
		$1~/^led_switch/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);
		gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`
		if [ $led_switch -eq 0 ];then
			/usr/sbin/wifi_led.sh force_off
			/usr/sbin/capture_led.sh force_off
			/usr/sbin/record_led.sh force_off
			#增加capture_led也就是红色电源灯的开机常亮的状态保存到/tmp/capture_led_state中
			/usr/sbin/capture_led.sh on
		else
			#增加capture_led 开的状态便于指示灯开关打开后恢复为亮的状态
			/usr/sbin/capture_led.sh on
		fi

		daemon
		/usr/sbin/anyka_ipc.sh start 
		echo "start ipc service......"
		#/usr/sbin/udisk.sh start
	fi

	boot_from=`cat /proc/cmdline | grep nfsroot`
	if [ -z "$boot_from" ];then
		echo "start net service......"
		/usr/sbin/net_manage.sh &
	else
		echo "## start from nfsroot, do not change ipaddress!"
	fi
	unset boot_from

}

restart_service ()
{
	echo "restart service......"
	stop_service
	start_service
}

#
# main:
#
if test -e /etc/jffs2/lookcam.conf ;then
	PUSHID_MODE=0
else
	PUSHID_MODE=1
fi

if test -e /dev/mmcblk0p1 ;then
    mount -rw /dev/mmcblk0p1 /mnt
elif test -e /dev/mmcblk0 ;then
    mount -rw /dev/mmcblk0 /mnt
fi

if test -d /mnt/usbnet ;then
	FACTORY_TEST=1
else
	FACTORY_TEST=0
fi

if test -d /mnt/update ;then
    UPDATE_MODE=1
else
    UPDATE_MODE=0
fi

if test -e /mnt/settime.txt ;then
	date -s "$(cat /mnt/settime.txt)"
else
	date -d "2019-01-01" +"%Y-%m-%d %H:%m:%S" >/mnt/settime.txt
fi

date +%Y-%m-%d

case "$MODE" in
	start)
		start_service
		;;
	stop)
		stop_service
		;;
	restart)
		restart_service
		;;
	pwoff)
		#/usr/sbin/pled.sh blink 150 150
		#/usr/sbin/led.sh blink 150 150
		#stop_service
		killall daemon
		killall cmd_serverd
		/usr/sbin/anyka_ipc.sh stop
		sync
		sleep 1
		echo 0 >/sys/user-gpio/POWER_OFF
		;;
	*)
		usage
		;;
esac
exit 0

