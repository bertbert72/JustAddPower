#!/bin/bash
# Last Modified 2017-09-20 - Just Add Power
# Turns the LED lights on a Transmitter or Receiver Off until a reboot
echo 0 > /sys/class/leds/led_pwr/brightness
echo 0 > /sys/class/leds/led_link/brightness
chmod a-w /sys/class/leds/led_pwr/brightness
chmod a-w /sys/class/leds/led_link/brightness
