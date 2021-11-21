#! /bin/sh
### BEGIN INIT INFO
# File:				rtl8188ftv.sh(wifi_driver.sh)	
# Provides:         8188 driver install and uninstall
# Required-Start:   $
# Required-Stop:
# Default-Start:     
# Default-Stop:
# Short-Description:install driver
# Author:			
# Email: 			
# Date:				2017-08-07
### END INIT INFO

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin
MODE=$1

usage()
{
	echo "Usage: $0 station | smartlink | ap | uninstall"
}

station_uninstall()
{
	#rm usb wifi driver(default)
	rmmod rdawfmac
	rmmod otg-hs
	rmmod sdio_wifi
}

station_install()
{
    #install usb wifi driver(default)
    insmod /usr/modules/sdio_wifi.ko
    sleep 1 #### 等待电源稳定后再加载其他驱动	
	insmod /usr/modules/otg-hs.ko
	sleep 2 #### 等待otg 向usb host 核心层完成一些注册工作后再加在驱动
	insmod /usr/modules/rdawfmac.ko
	echo " $0 station"
}

smartlink_uninstall()
{
	#rm usb wifi driver(default)
	rmmod rdawfmac
	rmmod otg-hs
	rmmod sdio_wifi
}

smartlink_install()
{
    insmod /usr/modules/sdio_wifi.ko
	sleep 1 #### 等待电源稳定后再加载其他驱动
	insmod /usr/modules/otg-hs.ko 
	sleep 2 #### 等待otg 向usb host 核心层完成一些注册工作后再加在驱动
	insmod /usr/modules/rdawfmac.ko
}

ap_install()
{
	#install usb wifi driver(default)
    insmod /usr/modules/sdio_wifi.ko
    sleep 1 #### 等待电源稳定后再加载其他驱动	
	insmod /usr/modules/otg-hs.ko
	sleep 2 #### 等待otg 向usb host 核心层完成一些注册工作后再加在驱动
	insmod /usr/modules/rdawfmac.ko  firmware_path=ap
	echo "install rda5995 ap driver"
}

ap_uninstall()
{
	#uninstall ap mode driver
	rmmod rdawfmac
	rmmod otg-hs
	rmmod sdio_wifi
	echo "uninstall rda5995 ap driver"
}

####### main

case "$MODE" in
	station)
		station_install
		;;
	smartlink)
		smartlink_install
		ifconfig wlan0 up
		iwconfig wlan0 mode monitor
		;;	
	ap)
		ap_install
		;;
	uninstall)
		station_uninstall
		smartlink_uninstall
		ap_uninstall
		;;
	*)
		usage
		;;
esac
exit 0


