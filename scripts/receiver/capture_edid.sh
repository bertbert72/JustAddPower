#!/bin/sh

echo primary > /sys/devices/platform/videoip/edid_use;
sleep 30;
reboot