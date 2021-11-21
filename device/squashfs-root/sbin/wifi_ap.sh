#! /bin/sh
### BEGIN INIT INFO
# File:				wifi_ap.sh
# Provides:         wifi ap start and stop
# Required-Start:   $
# Required-Stop:
# Default-Start:
# Default-Stop:
# Short-Description:start wifi run at station or softAP
# Author:
# Email:
# Date:				2014-12-19
### END INIT INFO

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin
MODE=$1
cfgfile="/etc/jffs2/anyka_cfg.ini"

usage()
{
	echo "Usage: $0 start | stop "
}

ap_start()
{
	echo "start wifi soft ap......"
	#read ssid and password
	ssid=`awk 'BEGIN {FS="="}/\[softap\]/{a=1} a==1&&$1~/s_ssid/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`
	password=`awk 'BEGIN {FS="="}/\[softap\]/{a=1} a==1&&$1~/s_password/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`

	if [ -z $ssid ]
	then
	#	ssid="Bodycam_XXX"
		return 0
	fi


	/usr/sbin/device_save.sh name "$ssid"
	/usr/sbin/device_save.sh password "$password"
	echo "ssid=$ssid password=$password"

	if [ -z $password ]
	then
		/usr/sbin/device_save.sh setwpa 0
	else
		/usr/sbin/device_save.sh setwpa 2
	fi
	
	
	#hostapd /etc/jffs2/hostapd.conf -B
	#test -f /var/run/udhcpd.pid && rm -f /var/run/udhcpd.pid
	#test -f /var/run/dhcpd.pid && rm -f /var/run/dhcpd.pid
	#ifconfig wlan1 192.168.0.1 #for busybox
	#route add default gw 192.168.0.1 #
	ifconfig wlan0 192.168.10.1 netmask 255.255.255.0 up  #for busybox
	if [ -z $password ]
	then
		iwpriv wlan0 apcfg "ASCII_CMD=AP_CFG,SSID=$ssid,SEC=OPEN"
	else
		iwpriv wlan0 apcfg "ASCII_CMD=AP_CFG,SSID=$ssid,SEC=WPA2-PSK,KEY=$password"
	fi
	udhcpd /etc/udhcpd.conf #for busybox
	iwpriv wlan0 start
	iwpriv wlan0 bssstart
	if [  -d "/sys/class/net/eth0" ]
    	then
	      ifconfig eth0 down
	      ifconfig eth0 up
	fi
	/usr/sbin/wifi_led.sh blink 800 200
}

ap_stop()
{
	/usr/sbin/wifi_led.sh off
	echo "stop wifi soft ap......"
	iwpriv wlan0 stop
	iwpriv wlan0 bssstop
	killall udhcpd
	#killall hostapd #MUST NOT killall -9, otherwise softAP can't shutdown
	ifconfig wlan0 down
}

echo -e "\33[32m$0 $@\33[0m"
case "$MODE" in
	start)
		ap_start
		;;
	stop)
		ap_stop
		;;
	*)
		usage
		;;
esac
exit 0

