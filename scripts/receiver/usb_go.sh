#!/bin/sh

if [ `lmparam g USB_ACCESS_ON` = 'y' ]; then
  e e_stop_usb
else
  e e_start_usb
fi