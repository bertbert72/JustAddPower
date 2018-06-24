#!/bin/bash
## Last modified 2017-07-10 - Just Add Power
## Returns device model information
## 	2017-02-09: Added support for 2G/3G+ Models
## 	2017-06-09: Modified syntax to remove relying on FAILED in dmesg
##	2017-07-10: Modified syntax to remove awk and added check for 3G+4+ TX
p="/sys/devices/platform"
i="info"
a="sii9678"
b="sii9679"
c="it6613"
d="cat6023"
r="VERSION_READ"
q="No version queuery"
s="i2c/io_select"
n="i2c/i_range"
o="i2c/io_value"
m="$(io 0 1e6e2158 | cut -d' ' -f3)"

echo 2 98 > $p/$s
echo 0 1 > $p/$n
if [ "$(cat $p/$o | grep 00 | cut -d' ' -f2)" != "" ];then
	export v=1
else
	export v=0
fi
if [ -e $p/$a/$i ] && [ -e $p/$b/$i ];then 
	if [ $v == 0 ] ; then
		echo "3G+HIFI TX"
	else
		echo "3G+WP4 TX"
	fi
elif [ -e $p/$b/$i ];then 
	if [ $v == 0 ];then
		if [ "$($r)" == "$q" ];then
			echo "3G TX"
		else
			echo "3G+AVP TX"
		fi
	else
		echo "3G+WP2 TX"
	fi
elif [ -e $p/$a/$i ];then 
	if [ "$($r)" == "$q" ];then
		echo "3G RX"
	else
		echo "3G+AVP RX"
	fi
elif [ -e $p/$d ];then 
	if [ -e $p/$a ];then
		echo "2G/3G+ TX"
	else
		echo "2G TX"
	fi
elif [ -e $p/$c ];then 
	if [ -e $p/$a ];then
		echo "2G/3G+ RX"
	else
		echo "2G RX"
	fi
elif [ $v == 1 ];then
	echo "2G/3G VGA TX"
elif [ -e $p/$b ];then
	if [ "$m" == "1e8d0" ];then 
		echo "3G+4+ TX"
	else
		echo "2G/3G TX"
	fi
elif [ -e $p/$a ];then
	if [ "$m" == "1e8d0" ];then
		echo "3G+4+ RX"
	else
		echo "2G/3G RX"
	fi
else
	echo "ERROR!"
fi
