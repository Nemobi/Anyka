#! /bin/sh
### BEGIN INIT INFO
# File:				net_manage.sh
# Provides:         select eth or wifi
# Required-Start:   $
# Required-Stop:
# Default-Start:
# Default-Stop:
# Short-Description
# Author:
# Email:
# Date:				2013-1-15
### END INIT INFO

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

mode=""
status=""
ping_time=0                                                                                         #ping当前的时间间隔
cfgfile="/etc/jffs2/anyka_cfg.ini"

ping_enable=`awk 'BEGIN {FS="="}/\[ping\]/{a=1} a==1 &&
			$1~/^ping_enable/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);
			gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`                                        #ping使能
ping_try=`awk 'BEGIN {FS="="}/\[ping\]/{a=1} a==1 &&
			$1~/^ping_try/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);
			gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`                                        #ping失败重试次数
ping_split=`awk 'BEGIN {FS="="}/\[ping\]/{a=1} a==1 &&
			$1~/^ping_split/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);
			gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`                                        #ping验证间隔
ping_ip_static=`awk 'BEGIN {FS="="}/\[ping\]/{a=1} a==1 &&
			$1~/^ping_ip/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);
			gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`                                        #ping所使用的ip地址
ping_type=`awk 'BEGIN {FS="="}/\[ping\]/{a=1} a==1 &&
			$1~/^ping_type/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);
			gsub(/^[[:blank:]]*/,"",$2);print $2}' $cfgfile`                                        #ping所使用的验证方式ping/arping

if [ -n "$ping_ip_static" ] ; then                                                                  #是否已经从配置中读取到ping_ip
	ping_ip=$ping_ip_static
fi
echo -e "\e["$CM_NORMAL";"$CF_BLUE";"$CB_BLACK"m""ping_enable=$ping_enable ping_try=$ping_try ping_split=$ping_split ping_type=$ping_type ping_ip=$ping_ip""\e[0m"

wlan_ping()
{
	let ping_time=$ping_time+1
	if [ $ping_time -ge $ping_split ] ; then                                                        #判读当前时间间隔是否已经达到
		gw_ip=`route -n | grep -E "^0.0.0.0.*wlan[0-9]" | awk '{print $2}'`                         #获取网关ip地址
		if [ -z "$ping_ip_static" ] ; then                                                          #判断是否存在没有静态验证ip地址
			ping_ip=$gw_ip                                                                          #配置文件ip为空则使用网关ip进行验证
		fi
		if [ -n "$gw_ip" ] ; then                                                                   #判断gw_ip地址是否为空,是否获取要验证的ip地址
			#echo -e "\e["$CM_NORMAL";"$CF_BLUE";"$CB_BLACK"m""TRY_PING '$ping_ip'""\e[0m"
			i=0
			while [ $i -lt $ping_try ]                                                              #循环ping_try次去进行ping验证网络是否连通
			do
				if [ $ping_type -eq 0 ]
				then                                                                                #使用ping
					ping -W 1 -c 1 $ping_ip > /dev/null
					ping_res=$?
					#echo -e "\e["$CM_NORMAL";"$CF_BLUE";"$CB_BLACK"m"`date`" PING $ping_res""\e[0m"
				else                                                                                #使用arping
					arping -c 1 -w 1 -I wlan0 $ping_ip > /dev/null
					ping_res=$?
					#echo -e "\e["$CM_NORMAL";"$CF_BLUE";"$CB_BLACK"m"`date`" ARPING $ping_res""\e[0m"
				fi
				if [ $ping_res -ne 0 ]                                                              #返回结果不为0则为ping不通
				then                                                                                #验证失败
					echo -e "\e["$CM_NORMAL";"$CF_RED";"$CB_BLACK"m"`date`" PING $ping_ip FAIL""\e[0m"
				else                                                                                #验证成功
					#echo -e "\e["$CM_NORMAL";"$CF_GREEN";"$CB_BLACK"m"`date`" PING $ping_ip SUCCESS""\e[0m"
					let ping_time=0
					return 0
				fi
				let i=$i+1
			done
			mode=""                                                                                 #ping验证失败,将mode设置为空，在check_and_start_wlan重新连接
			return 1
		fi
		let ping_time=0
	fi
	return 0
}

check_and_start_wlan()
{
	#echo -e "\e["$CM_NORMAL";"$CF_BLUE";"$CB_BLACK"m""$mode $ping_time $ping_enable $ping_split""\e[0m"
	if [ "$mode" != "wlan" ]; then
		mode=wlan
		ip=`ifconfig eth0 | grep 'inet addr' | awk '{print $2}' | awk -F ':' '{print $2}'`
		ipaddr del $ip dev eth0
		ifconfig eth0 down
		/usr/sbin/wifi_manage.sh start
		ifconfig eth0 up
	elif [ $ping_enable -eq 1 ]; then                                                               #ping_enable使能开关是否为1,判断是否进行ping验证
		wlan_ping
		if [ $? -ne 0 ]
		then
			/usr/sbin/wifi_manage.sh stop
		fi
	fi
}

check_and_start_eth()
{
	if [ "$mode" != "eth" ]
	then
		mode=eth
		/usr/sbin/wifi_manage.sh stop
		/usr/sbin/eth_manage.sh start
	fi
}


#
#main
#

#Do load ethernet module?

if [ ! -d "/sys/class/net/eth0" ]
then
	/usr/sbin/wifi_manage.sh start
	exit 1
else
	#ethernet always up
	ifconfig eth0 up
	sleep 3
fi

status=`ifconfig eth0 | grep RUNNING`
while true
do
	#check whether insert internet cable

	if [ "$status" = "" ]
	then
		#don't insert internet cable
		check_and_start_wlan
	else
		#have inserted internet cable
		check_and_start_eth
	fi

	tmp=`ifconfig eth0 | grep RUNNING`
	if [ "$tmp" != "$status" ]
	then
		sleep 2
		tmp=`ifconfig eth0 | grep RUNNING`
		status=$tmp
	fi
	sleep 1
done
exit 0

