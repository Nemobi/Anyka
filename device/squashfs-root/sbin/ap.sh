#!/bin/sh

cfgfile="/etc/jffs2/anyka_cfg.ini"

wifi_ap_start()
{
	killall smartlink 2>/dev/null
	killall wpa_supplicant 2>/dev/null
	dnsd -d -c /usr/local/dnsd.conf
	/usr/sbin/wifi_led.sh blink 1000 1000
	
	wifi_driver.sh uninstall
	sleep 0.5
	wifi_driver.sh station
	ifconfig wlan0 up
	
	#保存wifi scan 结果到文件，尝试3次，程序从文件读取或者重新检索
	#wifi scan 有结果就保留/tmp/wifi_scan.txt 没有就删除，程序以此文件是否存在决定是否重新检索
	i=0
	while [ $i -lt 3 ]
	do
		iwlist wlan0 scan >/tmp/wifi_scan.txt
		count=`grep -c "ESSID:" /tmp/wifi_scan.txt`
		if [ $count -eq 0 ];then
			echo "$0  iwlist wlan0 scan cannot get result,retry times :$i!"
			i=`expr $i + 1`
			rm -f /tmp/wifi_scan.txt
			sleep 1
		else
			echo "$0 iwlist wlan0 scan get result:$count"
			break
		fi
	done
	
	
	## check driver
	wifi_driver.sh uninstall
	sleep 0.5
	wifi_driver.sh ap

	echo "start wlan0 on ap mode"
	ifconfig wlan0 up
	
	## 做以下修改，避免软件还没将ssid写入配置anyka_cfg.ini里
	while true
	do
		ssid=`awk 'BEGIN {FS="="}/\[softap\]/{a=1} a==1 && 
		$1~/s_ssid/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);
		gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`
		password=`awk 'BEGIN {FS="="}/\[softap\]/{a=1} a==1 && 
		$1~/s_password/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);
		gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`
	
		echo " AP ssid:$ssid"
		if [ -z "$ssid" ];then
			sleep 1
		else
			break
		fi
	done
	
	echo "ap :: ssid=$ssid password=$password"


	/usr/sbin/device_save.sh name "$ssid"
	/usr/sbin/device_save.sh password "$password"

	if [ -z $password ];then
		/usr/sbin/device_save.sh setwpa 0
	else
		/usr/sbin/device_save.sh setwpa 2
	fi

	hostapd /etc/jffs2/hostapd.conf -B
	ifconfig wlan0 192.168.100.1
	route del default 2>/dev/null
	route add default gw 192.168.100.1 wlan0
	udhcpd /etc/udhcpd.conf
	echo " $0 start"
}

wifi_ap_stop()
{
	killall hostapd 2>/dev/null
	killall udhcpd 2>/dev/null
	killall dnsd 2>/dev/null	
	ifconfig wlan0 down
	wifi_driver.sh uninstall
	route del default 2>/dev/null
	echo " $0 stop"
}

usage()
{
	echo "$0 start | stop"
}


case $1 in
	start)
		wifi_ap_start
		;;
	stop)
		wifi_ap_stop
		;;
	*)
		usage
		;;
esac
	


