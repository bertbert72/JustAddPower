#!/bin/sh
#init udhcpd

#START CLEANUP
pkill -9 udhcpd 2> /dev/null
killall udhcpd 2> /dev/null
#DEFINE FILES
mkdir /var/lib/misc/ 2> /dev/null
echo > /var/lib/misc/udhcpd.leases
echo > /var/run/udhcpd.pid

#DEFINE IP SCOPE
export NETM=$(astparam g netmask)
export GATE=$(astparam g gatewayip)
export IPAD=$(printf "$(astparam g ipaddr | cut -d'.' -f1-3).254")
export START=$(printf "$(astparam g ipaddr | cut -d'.' -f1-3).200")
export END=$(printf "$(astparam g ipaddr | cut -d'.' -f1-3).249")

#DEFINE ETH0
ifconfig eth0 $IPAD
ifconfig eth0 up
#BUILD /ETC/UDHCPD.CONF # printf " " >> /etc/udhcpd.conf
printf "start $START \x0a" > /etc/udhcpd.conf
printf "end $END \x0a" >> /etc/udhcpd.conf
printf "max_leases 50 \x0a" >> /etc/udhcpd.conf
printf "remaining yes \x0a" >> /etc/udhcpd.conf
printf "interface eth0 \x0a" >> /etc/udhcpd.conf
printf "lease_file /var/lib/misc/udhcpd.leases \x0a" >> /etc/udhcpd.conf
printf "pidfile /var/run/udhcpd.pid \x0a" >> /etc/udhcpd.conf
printf "opt dns 8.8.8.8 4.2.2.2 \x0a" >> /etc/udhcpd.conf
printf "opt subnet $NETM \x0a" >> /etc/udhcpd.conf
printf "opt router $GATE \x0a" >> /etc/udhcpd.conf
printf "opt lease 864000 \x0a" >> /etc/udhcpd.conf

#RUN DHCP SERVER
udhcpd -f /etc/udhcpd.conf &
