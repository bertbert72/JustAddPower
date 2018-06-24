#!/bin/bash
## Last modified 2016-05-13 - Just Add Power
case "$(getmodel.sh)" in
	*R*) echo 1 > /sys/devices/platform/display/power_save ;;
	*T*) echo 1 > /sys/devices/platform/videoip/detach_input_port ;;
esac
