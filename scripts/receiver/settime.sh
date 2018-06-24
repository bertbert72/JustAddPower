#!/bin/bash
# Last Modified 2017-10-18 - Just Add Power
checkTime(){
	if [ $(ping 8.8.8.8 | grep -c !) -eq 1 ];then
		TSIP=$(nslookup $1 8.8.8.8 | grep $1 -A 1 | tail -n 1 | cut -d' ' -f3)
		rdate -s $TSIP
		DATE=$(date)
		echo "SETTIME: $DATE"
		exit
	fi
}
if [ $# -gt 0 ];then
	TS="$1"
else
	TS="time.nist.gov"
fi
echo "hosts: files dns mdns4" > /etc/nsswitch.conf
C=0
while [ $C ];do
	checkTime $TS
	sleep $C
	C=$C+1
done
