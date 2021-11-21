#! /bin/sh
### BEGIN INIT INFO
# File:				camera.sh	
# Provides:         camera service 
# Required-Start:   $
# Required-Stop:
# Default-Start:     
# Default-Stop:
# Short-Description:web service
# Author:			gao_wangsheng
# Email: 			gao_wangsheng@anyka.oa
# Date:				2012-8-8
### END INIT INFO

MODE=$1
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin
mode=hostapd
network=
usage()
{
	echo "Usage: $0 start|stop)"
	exit 3
}

stop()
{
	killall -15 anyka_ipc
	echo "stopping ipc service......"
}

start ()
{
	echo "start ipc service......"
	pid=`pgrep anyka_ipc`
    if [ "$pid" = "" ]
    then
	    anyka_ipc &
	fi
}

restart ()
{
	echo "restart ipc service......"
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

