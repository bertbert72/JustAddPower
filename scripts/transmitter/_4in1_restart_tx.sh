#!/bin/sh
source GW_IIC_FUNC

echo 3 60 > $IO_SELECT
echo $FUNC_TYPE_OFFSET $_4SCR_RESTART_OUTPUT > $IO_VALUE
echo $FUNC_TYPE_OFFSET $IIC_STATMNT_FIN > $IO_VALUE
