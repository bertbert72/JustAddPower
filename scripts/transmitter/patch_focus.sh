#!/bin/bash
## Last modified 2016-12-13 - Just Add Power
## Affects the focus border on a +4+ tiling Transmitter
## Parameter: focus
## When the focus parameter is set to 'y' the green border turns on
## When the focus parameter is set to 'n' the green border turns off
## Example: astparam s focus y;astparam save;sleep 1;reboot
export FOCUS=$(astparam g focus)
if [ "$FOCUS" != '"focus" not defined' ] ; then
	
	if [ "$FOCUS" == "y" ] ; then
		_4in1_focus_onoff.sh on;
	elif [ "$FOCUS" == "n" ] ; then
		_4in1_focus_onoff.sh off;
	fi

fi
