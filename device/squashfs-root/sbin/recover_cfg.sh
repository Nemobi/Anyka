#!/bin/sh
# File:				update.sh	
# Provides:         
# Description:      recover system configuration
# Author:			aj

play_recover_tip()
{
	ccli misc --tips "/usr/share/anyka_recover_device.mp3"
	sleep 3
}
#去除别名；因为即使-f会出现是否覆盖的交互
unalias cp

/usr/sbin/wifi_led.sh force_off
/usr/sbin/capture_led.sh force_off
/usr/sbin/record_led.sh force_off

#sleep 1
#recover factory config ini
cp -f /usr/local/factory_cfg.ini /etc/jffs2/anyka_cfg.ini
sync

#recover isp config ini
rm -rf /etc/jffs2/isp*.conf
rm -rf /etc/jffs2/.devpsd
sync

#after all done play tips
#play_recover_tip
#sleep 1

