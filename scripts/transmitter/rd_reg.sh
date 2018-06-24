#!/bin/sh
source GW_IIC_FUNC

if [ $# -eq 0 ]; then
 return;
fi



echo 3 60 > $IO_SELECT
echo $FUNC_TYPE_OFFSET $_4SCR_READ_REG_ARG > $IO_VALUE  
bank=$(ten_2_hex $1)
offset=$2
 
echo $SET_ARGS_OFFSET 2 > $IO_VALUE   # data length
echo $SET_ARGS_OFFSET $bank > $IO_VALUE 
echo $SET_ARGS_OFFSET $offset > $IO_VALUE
echo $FUNC_TYPE_OFFSET $IIC_STATMNT_FIN > $IO_VALUE

sleep 1
             

echo $_4SCR_READ_REG 1 > $I_RANGE
arg=$(cat $IO_VALUE  | tail -n 1 | awk '{print $2}')    
echo $arg
