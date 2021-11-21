#!/bin/sh
# File:				update.sh	
# Provides:         
# Description:      update zImage&rootfs under dir1/dir2/...
# Author:			xc

VAR1="uImage"
VAR2="root.sqsh4"
VAR3="usr.sqsh4"
VAR4="usr.jffs2"

ZMD5="uImage.md5"
SMD5="usr.sqsh4.md5"
JMD5="usr.jffs2.md5"
RMD5="root.sqsh4.md5"

DIR1="/tmp"
DIR2="/mnt"
UPDATE_DIR_TMP=0

update_voice_tip()
{
	echo "play update voice tips"
	ccli -t --f "/usr/share/anyka_update_device.mp3"
	sleep 3
}

update_ispconfig()
{
	rm -rf /etc/jffs2/isp*.conf
}

update_kernel()
{
	echo "check ${VAR1}............................."

	if [ -e ${DIR1}/${VAR1} ] 
	then
		if [ -e ${DIR1}/${ZMD5} ];then

			result=`md5sum -c ${DIR1}/${ZMD5} | grep OK`
			if [ -z "$result" ];then
				echo "MD5 check zImage failed, can't updata"
				return
			else
				echo "MD5 check zImage success"
			fi
		fi

		echo "update ${VAR1} under ${DIR1}...."
		updater local KERNEL=${DIR1}/${VAR1}
	fi	
}

update_squash()
{		
	echo "check ${VAR3}.........................."

	if [ -e ${DIR1}/${VAR3} ]
	then
		if [ -e ${DIR1}/${SMD5} ];then

			result=`md5sum -c ${DIR1}/${SMD5} | grep OK`
			if [ -z "$result" ];then
				echo "MD5 check usr.sqsh4 failed, can't updata"
				return
			else
				echo "MD5 check usr.sqsh4 success"
			fi
		fi

		echo "update ${VAR3} under ${DIR1}...."
		updater local B=${DIR1}/${VAR3}
	fi	
}

update_jffs2()
{
	echo "check ${VAR4}........................"

	if [ -e ${DIR1}/${VAR4} ]
	then
		if [ -e ${DIR1}/${JMD5} ];then

			result=`md5sum -c ${DIR1}/${JMD5} | grep OK`
			if [ -z "$result" ];then
				echo "MD5 check usr.jffs2 failed, can't updata"
				return
			else
				echo "MD5 check usr.jffs2 success"
			fi
		fi

		echo "update ${VAR4} under ${DIR1}...."
		updater local C=${DIR1}/${VAR4}
	fi	
}

update_rootfs_squash()
{		
	echo "check ${VAR2}.........................."

	if [ -e ${DIR1}/${VAR2} ]
	then
		if [ -e ${DIR1}/${RMD5} ];then

			result=`md5sum -c ${DIR1}/${RMD5} | grep OK`
			if [ -z "$result" ];then
				echo "MD5 check root.sqsh4 failed, can't updata"
				return
			else
				echo "MD5 check root.sqsh4 success"
			fi
		fi

		echo "update ${VAR2} under ${DIR1}...."
		updater local A=${DIR1}/${VAR2}
	fi	
}

update_check_image()
{
	echo "check update image .........................."

	for target in ${VAR1} ${VAR2} ${VAR3} ${VAR4}
	do
		if [ -f ${DIR1}/${target} ]; then
			echo "find a target ${target}, update in /tmp"
			UPDATE_DIR_TMP=1
			break
		fi	
	done
}

#
# main:
#
echo ""
echo "### enter update.sh ###"
echo "stop system service before update....."
killall -15 syslogd
killall -15 klogd
killall -15 tcpsvd

# play update vioce tip
update_voice_tip

# send signal to stop watchdog
killall -12 daemon 
sleep 5
# kill apps, MUST use force kill
killall -9 daemon
killall -9 anyka_ipc
killall -9 net_manage.sh
/usr/sbin/wifi_manage.sh stop
killall -9 smartlink

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

if [ $i -eq 0 ];then
	echo "The main app anyka_ipc is still run, we don't do update, reboot now !!!"
	reboot
fi

echo "############ please wait a moment. And don't remove TFcard or power-off #############"

#led blink
/usr/sbin/capture_led.sh blink 50 50

# cp busybox to tmp, avoid the command become no use
cp /bin/busybox /tmp/
rm /mnt/update/ -rf
update_check_image

if [ $UPDATE_DIR_TMP -ne 1 ];then
	## copy the image file to /tmp to avoid update fail on TF-card
	for dir in ${VAR1} ${VAR2} ${VAR3} ${VAR4}
	do
		cp ${DIR2}/${dir} /tmp/ 2>/dev/null
		cp ${DIR2}/${dir}.md5 /tmp/ 2>/dev/null
	done
	umount /mnt/ -l
	echo "update use image from /mnt"
else
	echo "update use image from /tmp"
fi
cd ${DIR1}

update_ispconfig

update_kernel
update_jffs2
update_squash
update_rootfs_squash

/tmp/busybox echo "############ update finished, reboot now #############"

/tmp/busybox sleep 3
/tmp/busybox reboot -f