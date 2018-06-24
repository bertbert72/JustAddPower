#!/bin/bash
## Last modified 2016-12-09 - Just Add Power
## Adds a special webname value to the version.html Image Pull(TM) section
## astparam s webname YOUR CUSTOM DEVICE NAME HERE;astparam save
export JAP=$(cat /www/index.html | grep title | cut -d'>' -f2 | cut -d'-' -f1 | tr '&' '~')
sed "s/Image Pull/Unnamed $JAP - Image Pull/" /www/version.html | tr '~' '&' > /www/version.tmp

export WEBNAME=$(astparam g webname)
if [ "$WEBNAME" == '"webname" not defined' ] ; then
	export WEBNAME=Unnamed
fi
sed "s/Unnamed/$WEBNAME/" /www/version.tmp > /www/version.html
rm -f /www/version.tmp
