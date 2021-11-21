#! /bin/sh
### BEGIN INIT INFO
# File:				wifi_manage.sh
# Provides:         start wifi station and ap
# Required-Start:   $
# Required-Stop:
# Default-Start:
# Default-Stop:
# Short-Description:start or stop wifi
# Author:
# Email:
# Date:				2015-3-5
### END INIT INFO

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin
MODE=$1
cfgfile="/etc/jffs2/anyka_cfg.ini"

usage()
{
	echo "Usage: $0 start | stop"
}

wifi_stop()
{
	killall -15 wifi_run.sh
	rm -f /var/run/wpa_supplicant/wlan0
	ifconfig wlan0 down
	/usr/sbin/wifi_station.sh stop
	killall -15 wifi_station.sh
	/usr/sbin/wifi_driver.sh uninstall
}

#
#main
#
echo -e "\33[32m$0 $@(`date +'%Y-%m-%d %H:%M:%S'`)\33[0m"
case "$MODE" in
	start)
		#wifi_stop
		/usr/sbin/wifi_run.sh &
		;;
	stop)
		killall -15 wifi_run.sh
		wifi_stop
		;;
	reset)
		killall -15 wifi_run.sh
		wifi_stop
		sleep 3
		/usr/sbin/wifi_run.sh &
		;;
	*)
		usage
		;;
esac
exit 0

