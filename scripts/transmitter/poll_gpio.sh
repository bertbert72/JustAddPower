#!/bin/sh

PRE_STATE='N'
GPIO_SYSFS_PATH="/sys/class/leds/gpio_pwr_status_in"
GPIO_VALUE="${GPIO_SYSFS_PATH}/brightness"
GPIO_READ="$GPIO_VALUE"

get_gpio_value()
{
	# Bruce160513. Fix.
	# Write 0 to brightness means read. Write 1 to brightness means read and invert.
	# We should write 0 here instead of 1.
	echo 0 > $GPIO_READ
	cat $GPIO_VALUE
}

if ! [ -f "$GPIO_VALUE" ]; then
	echo "gpio_pwr_status_in is not available!!"
	exit
fi

if [ "$1" = "report" ]; then
	current_value=`get_gpio_value`
	#e e_pwr_status_chg_${current_value}
	e msg_to${2}_e_pwr_status_chg_${current_value}
	exit
fi

while sleep 1; do
	current_value=`get_gpio_value`
	if [ "$current_value" != "$PRE_STATE" ]; then
		#e e_pwr_status_chg_${current_value}
		e msg_toFFFFFFFF_e_pwr_status_chg_${current_value}
		PRE_STATE=$current_value
	fi
done
