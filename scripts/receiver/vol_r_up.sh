#!/bin/sh
source GW_IIC_FUNC

echo 3 a0 > $IO_SELECT
echo $FUNC_TYPE_OFFSET $VOL_R_UP > $IO_VALUE
echo $FUNC_TYPE_OFFSET $IIC_STATMNT_FIN > $IO_VALUE