#!/bin/sh

while true
do
	killall -15 $1
	obj=`ps | grep $1 | grep -v grep |grep -v $0 | awk '{print $1}'`
	if [ "$obj" != "" ]
	then
		sleep 1
	else
		echo "the pro has been killed"
		exit 0
	fi
done
