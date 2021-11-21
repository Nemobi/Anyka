#! /bin/sh

#调用此脚本必须注意：确保系统应用层代码当前不会主动调到内核驱动里。
#因为不知道驱动将来会做什么与standby相冲突的任务,导致某些模块没进入standby模式。

umount_sd ()
{
	state=`mount |grep mmcblk0 | grep -v grep`
	if [ "$state" != "" ]
	then
		echo "umount sd"
		umount /mnt
	fi
}

echo "enter standby"
sleep 1
ifconfig eth0 down
/usr/sbin/service.sh stop
sleep 2
umount_sd
echo standby > /sys/power/state

echo "exit standby"
/usr/sbin/service.sh start

exit 0
