# JustAddPower
Scripts from JAP receivers and transmitters

## Receivers

The receiver commands are switch aware and work with both Cisco and Luxul switches.

|Command|Description|Example|
|:------|:----------|------:|
|channel|Switch to the next or previous receiver|./channel.sh up|
|commandallrx|Generates a list of all Receivers and then Telnets to each to execute a specified command $1|./commandallrx.sh "./channel.sh up"
|getmodel|Returns device model information|./getmodel.sh|
|getswitchinfo|Details of current switch config|./getswitchinfo.sh vlans|
|irm|Recalls previously learned IR commands from a Just Add Power 2G IR Manager by bank (1-4) and command (1-32)|./irm.sh 1 13 x|
|lightsoff|Turns the LED lights on a Transmitter or Receiver Off until a reboot|./lightsoff.sh|
|switch|Change receiver to different transmitter|./switch.sh rx1-5,7,9,11-16 tx5|

## Transmitters

## Updating

ls -1 | while read line ; do if [ $(grep -c ELF $line) == 0 ] ; then ftpput 192.168.0.x "public/JustAddPower/Scripts/receiver/$line" "$line" -u x ; fi ; done
ls -1 | while read line ; do if [ $(grep -c ELF $line) == 0 ] ; then ftpput 192.168.0.x "public/JustAddPower/Scripts/transmitter/$line" "$line" -u x ; fi ; done

ls -1 | while read line ; do if [ $(grep -c ELF $line) == 0 ] ; then echo $line : $(date -r $line) ; fi ; done

="/raid/data/module/bin/busybox touch -c -d "&TEXT(CONCATENATE(D1," ",C1," ",I1," ",E1,":",F1,":",G1),"yyyymmddhhmm.ss")&" "&A1
