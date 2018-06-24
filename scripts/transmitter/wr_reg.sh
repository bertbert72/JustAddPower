#!/bin/sh
source GW_IIC_FUNC

if [ $# -lt 3 ]; then
 return;
fi

bank=$(ten_2_hex $1)
offset=$2
data=$3
if [ $((${#data}%2)) == 1 ] ; then
	export data=0"$data"
fi
digit=$((${#data}/2))
totalsize=$(($digit+3))

echo 3 60 > $IO_SELECT
echo $FUNC_TYPE_OFFSET $_4SCR_WRITE_REG > $IO_VALUE
echo $SET_ARGS_OFFSET $totalsize > $IO_VALUE   # data length
echo $SET_ARGS_OFFSET $bank > $IO_VALUE
echo $SET_ARGS_OFFSET $offset > $IO_VALUE
echo $SET_ARGS_OFFSET $digit > $IO_VALUE

export i=$digit
while [ $i -gt 0 ]
do
  export F1=$(($i*2-1))
  export F2=$(($i*2))
  export itemp=$(echo $data | cut -c$F1-$F2)
  echo $SET_ARGS_OFFSET $itemp > $IO_VALUE
	i=$(expr $i - 1)
done

echo $FUNC_TYPE_OFFSET $IIC_STATMNT_FIN > $IO_VALUE