#!/bin/sh
source GW_IIC_FUNC

if [ $# -eq 0 ]; then
 return;
fi

arg=`echo $1 | awk '{printf tolower($1)}'`
        
if [ $arg == 'on' ] ; then
  arg=1
else
  arg=0
fi

echo 3 60 > $IO_SELECT
echo $FUNC_TYPE_OFFSET $_4SCR_FOCUS_ONOFF > $IO_VALUE
arg=$(ten_2_hex $arg)
echo $SET_ARGS_OFFSET 1 > $IO_VALUE   # data length
echo $SET_ARGS_OFFSET $arg > $IO_VALUE
echo $FUNC_TYPE_OFFSET $IIC_STATMNT_FIN > $IO_VALUE
