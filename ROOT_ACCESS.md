# Getting root access #

Getting root access is pretty straight forward for this specific device. All you need to do is create a folder on your SD card named "usbnet" and create a file named "product_test" in that folder. 

Copy this line into your product_test file:
    echo 'root:$1$ouLOV500$R5LCUppbxY40r9uLE8la61:0:0:99999:7:::' > /etc/shadow

## Explanation ##

Part of the boot process runs a bash script called /usr/sbin/servcie.sh. This script is responsible for starting the watchdog-servcie and main application "anyka_ipc". But the interesing part is this:

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


This checks the SD card for a folder named usbnet, and if this folder exists it tries to execute the file product_test.

This is our entrypoint as this allows us torun arbitrary commands as root during boot.

So running the command `echo 'root:$1$ouLOV500$R5LCUppbxY40r9uLE8la61:0:0:99999:7:::' > /etc/shadow` replaces the existing password for the root account and you can now login to the device via Telnet with the username root and the password "password".

    $ telnet 192.168.1.57
    Trying 192.168.1.57...
    Connected to anyka.
    Escape character is '^]'.
    
    anyka login: root
    Password: password
    welcome to file system
    [root@anyka ~]$



