

## About the device ##

Anyka Techonologies Corp. is a manufacturer of video-enabled SoC's. There are
many different brands of wifi-cameras which use Anyka chips, and many can be found in cheap security cameras on markets such as Amazon, Banggood and Ali-Express.

These devices are (in my exprecience) always tied to a companion app for Android or iOS, which you can use to change settings and watch a live feed from the camera or recordings from the SD card. What companion app a specific device is intended for isn't disclosed at the time of purchase, instead you get a QR-encoded shortened url which directs you to a download. Usually this redirects to Google Play or Apple App Store, but sometimes you end up with a simple html page with an apk-file which you need to side-load to use.
 
## Security concerns ##

Buying a wifi-enabled device and putting it on your home network is dangerous for multiple reasons. You have no control over how the device interacts with your other devices, what it records in terms of your network traffic, and with theese specific devices being video recording devices, where those video streams end up.

And since many of theese devices have the ability for OTA firmware updates, even if your device is well behaved and do nothing nafarious at this time, that might change at any moment. A motivated government can at the push of a button turn your device into a member of a botnet zombie army.

## Security concerns Part II, the companion app ##

As mentioned previously, the camera usually requires a companion app to use. These apps have a tendency to request addisional permissions, and shuts down if these aren't granted.

The companion app for the device this repo is centered on is called LookCam and is on the Google Play store [Todo: put link to store page here]. 

This device requests permission to access your phones storage, which is legitimate in order to save recordings to your phone, but it also requests permission to access your camera and microphone. Neither of theese should be required for the app to function properly.

If you disable Wifi on your phone you will notice that you still have access to your video feed. This means that live video in your home is retransmitted to a server that the manufacturer has control over before it is relayed relayed to your phone.

## About this repo ## 
My atempt here is to harden the device and make it usable without the companion app, and stop it from retransmitting the video feed outside of my local network. The most basic requirement is to get RTSP/RTP running, or an mjpeg server.  

## Breaking into the device ##

The devices I'm focused on here all have Telnet running on port 23. Connecting to the device will present you with
```
Trying {IP}...
Connected to {IP}.
Escape character is '^]'.

anyka login:
```

There lists of passwords online if you search for ```anyka password``` such as [this one](https://gist.github.com/gabonator/74cdd6ab4f733ff047356198c781f27d). None of these worked for me though. 

The firmware of the device is contained on a SPI Flash chip which can be read by any SPI enabled device. In my case I used an [Adafruit HUZZAH32 ESP32](https://www.adafruit.com/product/3405) to read the flash memory. I won't document the process here but after dumping the flash to a bin-file and using binwalk to extract the content I ended up with a squashfs partition. The contents from that can be found in the "device" folder in this repo.

There is also a partition in the format of jffs2. And while squashfs file systems are mounted read-only, jffs2 is mounted r/w. One of the files on the jffs2 partition is the /etc/shadow file, which contains the password-hashes of the user accounts. If we can find a way to modify this file we will have access to the system.

Part of the boot process runs a bash script called [/usr/sbin/servcie.sh](device/squashfs-root/sbin/service.sh). This script is responsible for starting the watchdog-servcie and main application "anyka_ipc". But the interesing part is this:
```
if test -d /mnt/usbnet ;then
	FACTORY_TEST=1
else
	FACTORY_TEST=0
fi

....

if [ $FACTORY_TEST = 1 ]; then
                insmod /mnt/usbnet/udc.ko
            insmod /mnt/usbnet/g_ether.ko
                /usr/bin/tcpsvd 0 21 ftpd -w / -t 600 &
            sleep 1
            ifconfig eth0 up
                telnetd &
            sleep 1
            /usr/sbin/eth_manage.sh start
                 echo "start product test."
                 /mnt/usbnet/product_test &
....
fi

```

This checks the SD card fro a folder named usbnet, and if this folder exists it checks for a file named "product_test"
in this folder and tries to execute it.

This is our entrypoint. Simply by creating a folder on the SD card and placing a shell script in it and name the file "product_test" we can run arbitrary commands as root on boot.

In my case I copied the shadow file from the previously mentioned jffs2 partition and changed the root entry to:
```
root:$1$ouLOV500$R5LCUppbxY40r9uLE8la61:0:0:99999:7:::
bin:*:10933:0:99999:7:::
daemon:*:10933:0:99999:7:::
nobody:*:10933:0:99999:7:::
```

This makes the password for the root account equal to ```password```.
I then created a file named "product_test" in the usbnet folder on the SD card and gave it the following content:
```
#!/bin/sh
cd /mnt/usbnet
if [ -e shadow ]
then
	cat shadow > /etc/shadow
fi
```

That's it. We now have root access to the device through Telnet.

```

$ telnet 192.168.1.56
Trying 192.168.1.56...
Connected to 192.168.1.56.
Escape character is '^]'.

anyka login: root
Password: password

welcome to file system
[root@anyka ~]$

```
