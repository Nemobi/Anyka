#! /bin/sh
### BEGIN INIT INFO
# File:				wifi_station.sh	
# Provides:         wifi station start, stop and connect
# Author:			
		
# Date:				2016-03-05
### END INIT INFO

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin
MODE=$1
cfgfile="/etc/jffs2/anyka_cfg.ini"

usage()
{
	echo "Usage: $0 start | stop | connect"
}

wifi_station_start()
{
	wpa_supplicant -B -iwlan0 -Dwext  -c /etc/jffs2/wpa_supplicant.conf
	echo " $0 start"
}

using_static_ip()
{
	ipaddress=`awk 'BEGIN {FS="="}/\[ethernet\]/{a=1} a==1 &&
		$1~/^ipaddr/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);
		gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`
	netmask=`awk 'BEGIN {FS="="}/\[ethernet\]/{a=1} a==1 && 
		$1~/^netmask/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);
		gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`
	gateway=`awk 'BEGIN {FS="="}/\[ethernet\]/{a=1} a==1 && 
		$1~/^gateway/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);
		gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`

	ifconfig wlan0 $ipaddress netmask $netmask
	route add default gw $gateway
}

check_ip_and_start()
{
	echo "check ip and start"

	dhcp=`awk 'BEGIN {FS="="}/\[ethernet\]/{a=1} a==1 && 
		$1~/^dhcp/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);
		gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`
		
	i=0
	while [ $i -lt 2 ]
	do
		if [ $dhcp -eq 1 ];then
			echo "using dynamic ip ..."
			killall udhcpc
			udhcpc -i wlan0 &
		elif [ $dhcp -eq 0 ];then
			echo "using static ip ..."
			using_static_ip
		fi
		status=
		j=0
		while [ $j -lt 20 ]  ##等待20s
		do
			sleep 0.5
			#以是否能获取ip为依据,判断wifi是否连接成功
			status=`ifconfig wlan0 >/tmp/wifi`
			status=` grep "inet addr:" /tmp/wifi `                
			if [ "$status" != "" ];then
				return 0
			fi
			j=`expr $j + 1`
			sleep 0.5
		done
		i=`expr $i + 1`
	done
	echo "[WiFi Station] fails to get ip address"
	return 1
}

wifi_station_do_connect()
{
	security=$1
	ssid=$2
	pswd=$3
	#### when debug, echo next line, other times don't print it
	#echo "security=$security ssid=$ssid password=$pswd"
	/usr/sbin/station_connect.sh $security "$ssid" "$pswd"
	ret=$?
	echo "/usr/sbin/station_connect.sh, return val:$ret"
	#sleep 1

	if [ $ret -eq 0 ];then
		i=0
		while [ $i -lt 30 ]
		do
			sleep 1
			OK=`wpa_cli -iwlan0 status >/tmp/wifi`
			OK=`grep wpa_state /tmp/wifi`			
			if [ "$OK" = "wpa_state=COMPLETED" ];then
				echo "[WiFi Station] $OK, security=$security ssid=$ssid pswd=$pswd"
				check_ip_and_start   #### get ip
				if [ $? -eq 0 ];then
					return 0
				else
					return 1
				fi
			else
				echo "wpa_cli still connectting, info[$i]: $OK"
				#增加密码错误的判断
				check_wpa=`grep -c "4-Way Handshake failed" /tmp/wpa_log`
				#echo "password error $check_wpa"
				if [ $check_wpa -gt 0 ];then
					echo -n "" > /tmp/wpa_log
					echo "wpa password err"
					return 3
				fi
				check_wep=`grep -c "Invalid WEP key" /tmp/wpa_log`
				if [ $check_wep -gt 0 ];then
					echo -n "" > /tmp/wpa_log
					echo "wep password err"
					return 3
				fi
			fi
			i=`expr $i + 1`
		done
		### time out judge
		if [ $i -eq 30 ];then
			echo "wpa_cli connect time out, try:$i, result:$OK"
			return 1
		fi
	else
		echo "station_connect.sh run failed, ret:$ret, check your arguments"
		return $ret
	fi
}

store_config_2_ini()
{
	#### save security
	if [ -n "$1" ];then
		old_security=`awk 'BEGIN {FS="="}/\[wireless\]/{a=1} a==1&&
			$1~/^security/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);
			gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`
		#### store info by replace
		echo "Save Security, new: $1"
		sed -i "/^security/ s/= $old_security/= $1/" $cfgfile
		sync
	fi

	#### save ssid
	if [ -n "$2" ];then
		old_ssid=`awk 'BEGIN {FS="="}/\[wireless\]/{a=1} a==1&&
			$1~/^ssid/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);
		gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`
		#### store info by replace
		echo "Save Ssid, new: $2, old: $old_ssid"
		sed -i -e "/^ssid/ s/= $old_ssid/= $2/" $cfgfile
		sync
	fi

	#echo "[WiFi Station] Save Config OK"
	#### for debug, show ini file first 23 line content
	#head -23 $cfgfile
}

wifi_station_check_security()
{
	#echo "check security, curval: $1"
	if [ -z "$1" ] || [ $1 = 0 ];then
		echo "[check security] invalid, val is null"
		return 1
	else
		echo "[check security] ok, val: $1"
		return 0
	fi
}

scan_ap_security()
{
    echo "scan_ap_security, val: $1"
    iwlist wlan0 scanning > /tmp/scan_result
    
    check_ssid=`grep -c $1 /tmp/scan_result`
    if [ $check_ssid -eq 0 ];then
        echo "hiden AP, need to check OPEN/WPA/WEP"
        if [ -z "$password" ];then
            rm -rf /tmp/scan_result
            return 1
        else
            #first try WPA and then WEP
            rm -rf /tmp/scan_result
            return 0
        fi
    else
        echo "get AP security"
        grep -A25 $1 /tmp/scan_result|sed '/Cell/q' > /tmp/ap_info
        if [ `grep -c "Encryption key:on" /tmp/ap_info` -gt 0 ];then
            if [ `grep -c "WPA" /tmp/ap_info` -gt 0 ];then
                rm -rf /tmp/scan_result
                rm -rf /tmp/ap_info
                return 3
            else
                rm -rf /tmp/scan_result
                rm -rf /tmp/ap_info
                return 2
            fi
        else
            rm -rf /tmp/scan_result
            rm -rf /tmp/ap_info
            return 1
        fi
    fi
    
}

wifi_station_connect()
{
	#echo "connect wifi station......"
	echo " $0 connect begin"
	#### get ini info
	if [ -f "/tmp/wifi_info" ];then
		echo "reading wifi config from tmp"

		ssid=`awk -F '=' '/^ssid=/{print $2}' "/tmp/wifi_info"`
		password=`awk -F '=' '/^pswd=/{print $2}' "/tmp/wifi_info"`
		security=`awk -F '=' '/^sec=/{print $2}' "/tmp/wifi_info"`
		rm -rf /tmp/wifi_info 
	else
		echo "reading wifi config from ini"
		ssid=`awk 'BEGIN {FS="="}/\[wireless\]/{a=1} a==1 && 
			$1~/^ssid/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);
			gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`
		password=`awk 'BEGIN {FS="="}/\[wireless\]/{a=1} a==1 && 
			$1~/^password/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);
			gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`
		security=`awk 'BEGIN {FS="="}/\[wireless\]/{a=1} a==1 &&
			$1~/^security/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);
			gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`
	fi

	############################# 正常连接时 ##########################
	#### ssid不为空则认为机器被配置过。已配置过的机器，进入正常连接
	while [ -n "$ssid" ]
	do
		#### 正常连接时，检查加密方式，不正确则通过当前ssid去搜索并改写为正确的。
		wifi_station_check_security "$security"
		#### 隐藏时通过ssid无法扫描到加密方式
		if [ $? -eq 1 ];then
			security="" #### clean the value
			break		#### 无法通过扫描获取加密方式时，尝试wpa和open方式
		fi

		#### 此时所有参数应为正常的，否则连接会失败
		wifi_station_do_connect "$security" "$ssid" "$password"
		ret=$?
		if [ $ret -eq 0 ];then
			return 0
		elif [ $ret -eq 3 ];then
			echo "[WiFi Station] Normal connect failed, argments error"
			return 3
		else
			echo "[WiFi Station] Normal connect failed"
			return 1
		fi
	done
	############################# 正常连接时 ##########################

	#### if run to here, 说明ssid被隐藏了或者某些原因上述代码无法获取加密方式，此时需要尝试
	if [ -n "$ssid" ] && [ -z "$security" ];then
		wpa_cli -iwlan0 scan #### must scan
		sleep 1
		for security in 3 2 1
		do
			wifi_station_do_connect $security "$ssid" "$password"
			if [ 0 -eq $? ];then
				store_config_2_ini $security "" #### save config, ssid don't need save
				return 0
			elif [ $? -eq 3 ];then
				echo "$security connect, arguments error, please check"
			fi
		done
		echo "[WiFi Station] Normal connect failed"
		return 1
	fi

	######## 通过smartlink 或者 voicelink 配置网络时 运行下面的代码 ######## 
	#### if run to here, it means the mechine need to be config ####

	#### 1. get two encode types ssid from temporary file
	gbk_ssid=`cat /tmp/wireless/gbk_ssid`
	utf8_ssid=`cat /tmp/wireless/utf8_ssid`
	echo "##### gbk_ssid: $gbk_ssid"
	echo "##### utf-8_ssid: $utf8_ssid"

	#### 2. if security is not open, we only use wpa with two encode types ssid to try connect
	for ssid in "$gbk_ssid" "$utf8_ssid"
	do
		scan_ap_security "$ssid"
		security=$?
		if [ $security -eq 0 ];then
			for security in 3 2 1
			do
				wifi_station_do_connect $security "$ssid" "$password"
				ret=$?
				if [ $ret -eq 0 ];then
					store_config_2_ini $security "$ssid" 
					return 0
				fi
			done
		else
			wifi_station_do_connect $security "$ssid" "$password"
			ret=$?
			if [ $ret -eq 0 ];then
				store_config_2_ini $security "$ssid" 
				return 0
			fi
		fi
	done
	if [ $ret -eq 3 ];then
			echo "[WiFi Station] Connect failed, argments error"
			return 3
	fi
	#### if run to here, that means the way wpa+gbk or wpa+utf8 connect failed, need to be reconfiguration
	echo "[WiFi Station] Connect Failed, try again !!!"
	return 1
}

wifi_station_stop()
{
	echo "stop wifi station......"
	killall wpa_supplicant
	killall udhcpc
	ifconfig wlan0 down
}


case "$MODE" in
	start)
		wifi_station_start
		;;
	stop)
		wifi_station_stop
		;;
	connect)
		wifi_station_connect
		ret=$?
		rm -f /tmp/wifi
		if [ $ret -ne 0 ];then
			echo "[WiFi Station] Connect failed, argments error"
			/usr/sbin/wifi_led.sh blink 100 100
		else
			/usr/sbin/wifi_led.sh on  
			echo "[WiFi Station] Connect OK"
		fi
		echo " $0 connect return"
		return $ret
		;;
	*)
		usage
		;;
esac
exit 0


