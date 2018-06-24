#!/bin/sh

rm FLUX 2> /dev/null
mknod FLUX p:
killall -9 nc

while true; do
	nc -l -p 4998 0< FLUX | tr '\r' '\n' | fluxhandler.sh 1> FLUX
done
