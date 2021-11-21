#! /bin/sh
### BEGIN INIT INFO
# File:				wifi_run.sh
# Provides:         manage wifi station and smartlink
# Required-Start:   $
# Required-Stop:
# Default-Start:
# Default-Stop:
# Short-Description:start wifi run at station or smartlink
# Author:
# Email:
# Date:				2012-8-8
### END INIT INFO

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin
MODE=$1
cfgfile="/etc/jffs2/anyka_cfg.ini"
TEST_MODE=0

CM_NORMAL=0
CM_BOLD=1
CM_UNDERLINED=4
CM_BLINK=5
CM_NEGATIVE=7

CB_BLACK=40
CB_RED=41
CB_GREEN=42
CB_YELLOW=43
CB_BLUE=44
CB_PURPLE=45
CB_CYAN=46
CB_WHITE=47

CF_BLACK=30
CF_RED=31
CF_GREEN=32
CF_YELLOW=33
CF_BLUE=34
CF_PURPLE=35
CF_CYAN=36
CF_WHITE=37

UDHCPC_WAIT_SEC=15                                                                                  #wifi连接后,等待dhcp分配ip的时间(秒)
play_please_config_net()
{
	echo "play please config wifi tone"
	ccli misc --tips "/usr/share/anyka_please_config_net.mp3"
}

play_get_config_info()
{
	echo "play_get_config_info(`date +'%Y-%m-%d %H:%M:%S'`)"
	ccli misc --tips "/usr/share/anyka_camera_get_config.mp3"
}

play_afresh_net_config()
{
	echo "play please afresh config net tone"
	ccli misc --tips "/usr/share/anyka_connected_failed.mp3"
	ccli misc --tips "/usr/share/anyka_afresh_net_config.mp3"
}

play_connected_success()
{
	echo "play_connected_success(`date +'%Y-%m-%d %H:%M:%S'`)"
	ccli misc --tips "/usr/share/anyka_connected_success.mp3"
}

using_static_ip()
{
	ipaddress=`awk 'BEGIN {FS="="}/\[ethernet\]/{a=1} a==1&&$1~/^ipaddr/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`
	netmask=`awk 'BEGIN {FS="="}/\[ethernet\]/{a=1} a==1&&$1~/^netmask/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`
	gateway=`awk 'BEGIN {FS="="}/\[ethernet\]/{a=1} a==1&&$1~/^gateway/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`

	ifconfig wlan0 $ipaddress netmask $netmask
	route add default gw $gateway
	#sleep 1
}


station_install()
{
	### remove all wifi driver
	/usr/sbin/wifi_driver.sh uninstall

	## stop smartlink app


	## install station driver
	/usr/sbin/wifi_driver.sh station
	i=0
	###### wait until the wifi driver insmod finished.
	while [ $i -lt 3 ]
	do
		if [ -d "/sys/class/net/wlan0" ];then
			ifconfig wlan0 up
			break
		else
			sleep 1
			i=`expr $i + 1`
		fi
	done

	if [ $i -eq 3 ];then
		echo "wifi driver install error, exit"
		return 1
	fi

	echo "wifi driver install OK"
	return 0
}

station_connect()
{
	/usr/sbin/wifi_station.sh start

	pid=`pgrep wpa_supplicant`
	if [ -z "$pid" ];then
		echo "the wpa_supplicant init failed, exit start wifi"
		return 1
	fi

	/usr/sbin/wifi_station.sh connect
	ret=$?
	echo "wifi connect return val: $ret"
	if [ $ret -eq 0 ];then
		if [ -d "/sys/class/net/eth0" ]
		then
			ifconfig eth0 down
			ifconfig eth0 up
		fi
		echo "wifi connected!"
		return 0
	else
		echo "[station start] wifi station connect failed"
	fi

	return $ret
}


check_ip_and_start()
{
	echo "check ip and start"
	dhcp=`awk 'BEGIN {FS="="}/\[ethernet\]/{a=1} a==1 &&
		$1~/^dhcp/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);
		gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`
	if [ $dhcp -eq 1 ];then
		echo "using dynamic ip ..."
		killall udhcpc
		udhcpc -i wlan0 &
	elif [ $dhcp -eq 0 ];then
		echo "using static ip ..."
		using_static_ip
	fi
	status=
	i=0
	while [ $i -lt $UDHCPC_WAIT_SEC ]
	do
		sleep 1
		status=`ifconfig wlan0 | grep "inet addr:"`                                         #以是否能获取ip为依据,判断wifi是否连接成功
		if [ "$status" != "" ];then
			return 0
		fi
		i=`expr $i + 1`
	done

	echo "[WiFi Station] fails to get ip address"
	/usr/sbin/wifi_led.sh blink 100 100
	return 1
}

station_start_normdrv()
{
	ifconfig wlan0 down
	i=0
	while [ $i -lt 3 ]
	do
		if [ -d "/sys/class/net/wlan0" ];then
			ifconfig wlan0 up
			break
		else
			sleep 1
			i=`expr $i + 1`
		fi
	done

	if [ $i -eq 3 ];then
		echo "wifi driver install error, exit"
		return 1
	fi
	echo "wifi driver install OK"
	/usr/sbin/wifi_station.sh connect
	ret=$?
	echo "wifi connect return val: $ret"
	if [ $ret -eq 0 ];then
		if [ -d "/sys/class/net/eth0" ]
		then
			ifconfig eth0 down
			ifconfig eth0 up
		fi
		echo "wifi connected!"
	else
		echo "[station start] wifi station connect failed"
	fi

	/usr/sbin/wifi_station.sh start
	check_ip_and_start
	return $?
}

station_start()
{
	#station 模式未连接上线时也实现wifi led 快闪
	/usr/sbin/wifi_led.sh blink 100 100
	### remove all wifi driver
	/usr/sbin/wifi_driver.sh uninstall

	## stop smartlink app


	## install station driver
	/usr/sbin/wifi_driver.sh station
	i=0
	###### wait until the wifi driver insmod finished.
	while [ $i -lt 3 ]
	do
		if [ -d "/sys/class/net/wlan0" ];then
			ifconfig wlan0 up
			break
		else
			/usr/sbin/wifi_driver.sh uninstall	
			/usr/sbin/wifi_driver.sh station			
			sleep 1
			i=`expr $i + 1`
		fi
	done
		wlan0_status=`ls -l /sys/class/net/`
		echo "wlan0_status : $wlan0_status"

	if [ $i -eq 3 ];then
		echo "wifi driver install error, exit"
		return 1
	fi
	
	#保存wifi scan 结果到文件，尝试3次，程序从文件读取或者重新检索
	#wifi scan 有结果就保留/tmp/wifi_scan.txt 没有就删除，程序以此文件是否存在决定是否重新检索
	i=0
	while [ $i -lt 3 ]
	do
		iwlist wlan0 scan >/tmp/wifi_scan.txt
		count=`grep -c "ESSID:" /tmp/wifi_scan.txt`
		if [ $count -eq 0 ];then
			echo "$0 iwlist wlan0 scan cannot get result,retry times :$i!"
			i=`expr $i + 1`
			rm -f /tmp/wifi_scan.txt
			sleep 1
		else
			echo "$0 iwlist wlan0 scan get result:$count"
			break
		fi
	done
	
	echo "wifi driver install OK"
	/usr/sbin/wifi_station.sh start
	/usr/sbin/wifi_station.sh connect
	ret=$?
	echo "wifi connect return val: $ret"
	if [ $ret -eq 0 ];then
		if [ -d "/sys/class/net/eth0" ]
		then
			ifconfig eth0 down
			ifconfig eth0 up
		fi
		echo "wifi connected!"
#		return 0
	else
		echo "[station start] wifi station connect failed"
	fi

	check_ip_and_start
	return $?
}

smartlink_start()
{
	/usr/sbin/wifi_driver.sh uninstall
	### start smartlink status led
	/usr/sbin/wifi_driver.sh smartlink
}


#main
echo -e "\33[32m$0 $@(`date +'%Y-%m-%d %H:%M:%S'`)\33[0m"





ssid=`awk 'BEGIN {FS="="}/\[wireless\]/{a=1} a==1 && $1~/^ssid/{gsub(/\"/,"",$2);
	gsub(/\;.*/, "", $2);gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`

if [ "$ssid" = "" ]
then
	/usr/sbin/ap.sh start
	play_voice_flag=0
	while true
	do
		#wait anyka_ipc play the voice
		#smartlink_start
		check_ipc=`pgrep anyka_ipc`                                                         #等待anyka_ipc完成启动
		if [ "$check_ipc" = "" ];then
			sleep 1
			continue
		fi
		sleep 3
	done
fi
station_start