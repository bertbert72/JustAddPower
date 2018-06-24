###soundcheck.sh, currently reports audio capabilities, amplification, and delay. Will include current audio format in future.
if [ "$(getmodel.sh | grep "AVP" -c )" == "1" ] && [ "$(getmodel.sh | grep "TX" -c )" == "1" ];then
echo "This device is capable of broadcasting up to Dolby Digital 5.1. It has downmixing capabilities. "
elif [ "$(getmodel.sh | grep "3G" -c )" == "1" ];then
echo "This device is capable of interpreting lossless audio formats. "
elif [ "$(getmodel.sh | grep "2G" -c )" == "1" ];then
echo "This device is capable of interpreting up to 7.1 channel audio formats. "
else 
	echo "Function error. "
fi
Vol=$(volume_read.sh)
if [ "$(getmodel.sh | grep AVP -c )" == "1" ];then
	echo "The stereo output amplification is $Vol"
elif [ "$(getmodel.sh | grep "WP4" -c )" == "1" ];then
	echo "The stereo output amplification is $Vol"
elif [ "$(getmodel.sh | grep AVP -c )" == "0" ];then
 	echo "This device does not have stereo amplification. "
else
	echo "Function error. "
fi
DELAY=$(AUD_DLY_READ_CURRENT 2> /dev/null)
DELAYFUNCTION=$(awk -v DELAY=$DELAY 'BEGIN{ print DELAY * 6.8 }')
if [ "$(getmodel.sh | grep + -c )" == "1" ];then
case $DELAY in
0) echo "This device has a delay value of $DELAY (minumum delay). This corresponds to a stereo analog delay of 0 milliseconds. "
	exit
	;;
1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22]|23|24) echo "This device has a delay value of "$DELAY". This corresponds to a stereo analog delay of $DELAYFUNCTION milliseconds. "
	exit
	;;
25) echo "This device has a delay value of $DELAY (maximum delay). This corresponds to a stereo analog delay of 170 milliseconds. "
	exit
	;;
*) echo "This device does not have stereo delay capabilities. "
	exit
	;;
esac
fi
###audio frequency