#!/bin/sh
module="cec_drv"
device="CECoIP_drv"

# kill applications
pkill CEC_guest 2>/dev/null

# invoke rmmod with all arguments we got
rmmod $module $* || exit 1

# Remove stale nodes
rm -f /dev/${device} 

