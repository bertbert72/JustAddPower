#!/bin/sh
source GW_IIC_FUNC

echo 3 60 > $IO_SELECT

echo $DD_MIC_SIG 1 > $I_RANGE
arg=$(cat $IO_VALUE  | tail -n 1 | awk '{print $2}')
arg=$(hex_2_ten $arg)

echo $arg