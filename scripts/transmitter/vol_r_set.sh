#!/bin/sh
source GW_IIC_FUNC

if [ $# -eq 0 ]; then
 return;
fi

echo 3 60 > $IO_SELECT
echo $FUNC_TYPE_OFFSET $VOL_R_SET > $IO_VALUE
arg=$(ten_2_hex $1)
echo $SET_ARGS_OFFSET 1 > $IO_VALUE   # data length
echo $SET_ARGS_OFFSET $arg > $IO_VALUE
echo $FUNC_TYPE_OFFSET $IIC_STATMNT_FIN > $IO_VALUE
