#!/bin/sh
## Last Updated 2016-07-18 - Just Add Power
##	Requirements:
## 		Set RX1 and RX2 as the desired background images
##		Set RX3 and RX4 as the KEY images
## 	chromakey.sh [color]:[level setting]
## 	EXAMPLE:
##		chromakey.sh green:1
##		Keys out Green on KEY Channel 3/4

# tftp 169.254.6.55 -c get chromakey.sh
# p4p.sh layer:4321 ch1 hpos:0 vpos:0 width:1920 height:1080 ch2 hpos:1240 vpos:610 width:480 height:270 ch3 hpos:200 vpos:200 width:640 height:360 ch4 hpos:200 vpos:200 width:640 height:360    

# p4p.sh  ch1 hpos:0 vpos:0 width:1920 height:1080 ch2 hpos:1240 vpos:610 width:480 height:270 ch3 hpos:200 vpos:200 width:640 height:360 ch4 hpos:200 vpos:200 width:640 height:360    
source GW_IIC_FUNC

chroma_handler()
{
  echo 3 60 > $IO_SELECT
  echo $FUNC_TYPE_OFFSET $_4SCR_CHROMA > $IO_VALUE
  
  if [ $# -gt 1 ]; then
		  echo $SET_ARGS_OFFSET 5 > $IO_VALUE                # data length
		  echo $SET_ARGS_OFFSET $_CM_ON > $IO_VALUE          # mode
		  export data=$1
		  export i=1
			while [ $i -le 3 ]
			do
			  export F1=$(($i*2-1))
			  export F2=$(($i*2))
			  export itemp=$(echo $data | cut -c$F1-$F2)
			  echo $SET_ARGS_OFFSET $itemp > $IO_VALUE
				i=$(expr $i + 1)
			done
		  echo $SET_ARGS_OFFSET $2 > $IO_VALUE          # range
  else  # off
      echo $SET_ARGS_OFFSET 1 > $IO_VALUE   # data length
		  echo $SET_ARGS_OFFSET $_CM_OFF > $IO_VALUE  # mode
  fi
  echo $FUNC_TYPE_OFFSET $IIC_STATMNT_FIN > $IO_VALUE
}


case $1 in
	off*)   chroma_handler 's';;
	*) chroma_handler $1 $2;;
esac
