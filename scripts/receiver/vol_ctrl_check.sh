#!/bin/sh
source GW_IIC_FUNC

echo 3 a0 > $IO_SELECT
echo $VOL_CTRL_EXIST 0x1 > $I_RANGE
arg=$(cat $IO_VALUE  | tail -n 1 |awk '{print $2}')
printf "\x$arg\n\r"