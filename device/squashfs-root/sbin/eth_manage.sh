#! /bin/sh
### BEGIN INIT INFO
# File:				eth_manage.sh	
# Required-Start:   $
# Required-Stop:
# Default-Start:     
# Default-Stop:
# Description: ethernet manager
# Author:			
# Email: 			
# Date:				2014-8-8
### END INIT INFO

MODE=$1
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin

usage()
{
	echo "Usage: $0 start|stop|restart)"
	exit 3
}

stop()
{
	echo "stop ethernet......"
	killall udhcpc
}

use_static_ip()
{
	inifile="/etc/jffs2/anyka_cfg.ini"

	ipaddr=`awk 'BEGIN {FS="="}/\[ethernet\]/{a=1} a==1&&$1~/ipaddr/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);gsub(/^[[:blank:]]*/,"",$2);print $2}' $inifile`

	netmask=`awk 'BEGIN {FS="="}/\[ethernet\]/{a=1} a==1&&$1~/netmask/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);gsub(/^[[:blank:]]*/,"",$2);print $2}' $inifile`

	gateway=`awk 'BEGIN {FS="="}/\[ethernet\]/{a=1} a==1&&$1~/gateway/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);gsub(/^[[:blank:]]*/,"",$2);print $2}' $inifile`

	firstdns=`awk 'BEGIN {FS="="}/\[ethernet\]/{a=1} a==1&&$1~/firstdns/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);gsub(/^[[:blank:]]*/,"",$2);print $2}' $inifile`

	backdns=`awk 'BEGIN {FS="="}/\[ethernet\]/{a=1} a==1&&$1~/backdns/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);gsub(/^[[:blank:]]*/,"",$2);print $2}' $inifile`

	ifconfig eth0 $ipaddr netmask $netmask
	route add default gw $gateway
	sed -i "2,\$c nameserver $firstdns \
		nameserver $backdns" /etc/jffs2/resolv.conf

	sleep 1
}

check_ip_and_start()
{
	inifile="/etc/jffs2/anyka_cfg.ini"
	i=0

	dhcp=`awk 'BEGIN {FS="="}/\[ethernet\]/{a=1} a==1&&$1~/dhcp/{gsub(/\"/,"",$2);gsub(/\;.*/, "", $2);gsub(/^[[:blank:]]*/,"",$2);print $2}' $inifile`

	if [ $dhcp -eq 0 ]
	then
		echo "using static ip address..."
		use_static_ip
		status=ok
	else
		status=

		while [ $i -lt 2 ]
		do
			cable=`ifconfig eth0 | grep RUNNING`
			if [ "$cable" = "" ]
			then
				echo "Network cable has been unplug!"
				return
			fi

			echo "Getting ip address..."
			killall udhcpc
			udhcpc -i eth0 &

			####  sleep 5 seconds, because some router allocate IP address is too slow
			sleep 5

			status=`ifconfig eth0 | grep "inet addr:"`
			if [ -z "$status" ];then
				i=`expr $i + 1`
			else
				break
			fi
		
		done

		status=`ifconfig eth0 | grep "inet addr:"`
		if [ "$status" = "" ] && [ $i -eq 2 ];then
			echo "can't getting ip address by dynamic, using static ip address!"
			killall udhcpc
			use_static_ip
		fi
	fi
	
}

start ()
{
	echo "start ethernet......"
	check_ip_and_start
}

restart ()
{
	echo "restart ethernet......"
	stop
	start
}

#
# main:
#

case "$MODE" in
	start)
		start
		;;
	stop)
		stop
		;;
	restart)
		restart
		;;
	*)
		usage
		;;
esac
exit 0

