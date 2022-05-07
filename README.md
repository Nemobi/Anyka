

## About the device ##

Anyka Techonologies Corp. is a manufacturer of video-enabled SoC's. There are
many different brands of wifi-cameras which use Anyka chips, and many can be found in cheap security cameras on markets such as Amazon, Banggood and Ali-Express.

These devices are (in my exprecience) always tied to a companion app for Android or iOS, which you can use to change settings and watch a live feed from the camera or recordings from the SD card. What companion app a specific device is intended for isn't disclosed at the time of purchase, instead you get a QR-encoded shortened url which directs you to a download. Usually this redirects to Google Play or Apple App Store, but sometimes you end up with a simple html page with an apk-file which you need to side-load to use.
 
## Security concerns ##

Buying a wifi-enabled device and putting it on your home network is dangerous for multiple reasons. You have no control over how the device interacts with your other devices, what it records in terms of your network traffic, and with theese specific devices being video recording devices, where those video streams end up.

And since many of theese devices have the ability for OTA firmware updates, even if your device is well behaved and do nothing nafarious at this time, that might change at any moment. In essense, the user has no control over the device and the manufacturer have fulla access to the device and to the users network if it wanted to.

## Security concerns Part II, the companion app ##

As mentioned previously, the camera usually requires a companion app to use. The companion app for the device this repo is centered on is called LookCam and is on the Google Play store <https://play.google.com/store/apps/details?id=com.view.ppcs>. This the app requests permission to access your phones storage, which is legitimate in order to save recordings to your phone, but it also requests permission to access your camera and microphone. Neither of theese should be required for the app to function properly.

If you disable Wifi on your phone you will notice that you still have access to your video feed. This means that live video in your home is retransmitted to a server that the manufacturer has control over before it is relayed relayed to your phone.

## About this repo ## 

My atempt here is to harden the device and make it usable without the companion app, and stop it from retransmitting the video feed outside of my local network. The most basic requirement is to get RTSP/RTP running, or an mjpeg server.

### RTSP Server

Devices that was built using the Anyka SDK usually already contains a simple RTSP server, `/usr/bin/ak_rtsp_demo`. Unfortunately it doesn't provide any form of authentication. The main process, anyka_ipc, can also be built to include an RTSP server by settings `CONFIG_RTSP_SUPPORT = y` when building from the SDK.

### SDK

The SDK for the device can be found at <https://github.com/Nemobi/ak3918ev300v18/>. Crosstool-ng can be used to build the sdk but it's much easier to use the pre-configured tools below.

### Build tools

A crosscompiler toolchain can be found at <https://github.com/ricardojlrufino/arm-anykav200-crosstool>

## Docker 

A complete crosstool environment with the SDK can be found at <hub.docker.com/nemobi/anyka_ak3918ev300v18_sdk>.
By default this image will set up a crosstool build environment and build a default configuration and output the firmware files.

### Usage
```
docker run -v output:/output nemobi/anyka_ak3918ev300v18_sdk
```

## Getting a root shell on the device ##

Follow [this](/ROOT_ACCESS.md) guide to get root access.

The devices I'm focused on here all have Telnet running on port 23.
There lists of passwords online if you search for ```anyka password``` such as [this one](https://gist.github.com/gabonator/74cdd6ab4f733ff047356198c781f27d). None of these passwords worked for me though and instead I had to dump the firmware and look for a weakness in the boot process. 

The firmware of the device is contained on a SPI Flash chip which can be read by any SPI enabled device. In my case I used an [Adafruit HUZZAH32 ESP32](https://www.adafruit.com/product/3405) to read the flash memory. I won't document the process here but after dumping the flash to a bin-file and using binwalk to extract the content I ended up with a squashfs partition. The contents from that can be found in the "device" folder in this repo.

There is also a partition in the format of jffs2. And while squashfs file systems are mounted read-only, jffs2 is mounted r/w. One of the files on the jffs2 partition is the /etc/shadow file, which contains the password-hashes of the user accounts. By modifying this file we can get root access to the system.


