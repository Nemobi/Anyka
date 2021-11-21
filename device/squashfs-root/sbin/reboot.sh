#!/bin/sh
# File:				reboot.sh	
# Provides:         
# Description:      reboot the system make sure the wifi work ok after reboot
# Author:			cyc


#
# main:
#
echo ""
echo "### enter reboot.sh ###"
echo "stop system service before reboot....."
killall -15 syslogd
killall -15 klogd
killall -15 tcpsvd



# send signal to stop watchdog
killall -12 daemon 
sleep 3
/usr/sbin/capture_led.sh force_on
sleep 2
# kill apps, MUST use force kill
killall -9 daemon
killall -9 anyka_ipc
killall -9 net_manage.sh
/usr/sbin/wifi_manage.sh stop
killall -9 smartlink
killall -9 cmd_serverd
killall -9 udhcpc
killall -9 wpa_supplicant



# sleep to wait the program exit
i=5
while [ $i -gt 0 ]
do
	sleep 1

	pid=`pgrep anyka_ipc`
	if [ -z "$pid" ];then
		echo "The main app anyka_ipc has exited !!!"
		break
	fi

	i=`expr $i - 1`
done


echo "reboot now !!!"
reboot

