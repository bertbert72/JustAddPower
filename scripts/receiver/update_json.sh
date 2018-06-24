#!/bin/bash
## update_json.sh
## Last Modified 2017-06-22 - Just Add Power
## Update /www/switchplease/json/systeminfo.json with new "name" and "vlan" data
## Syntax:
## update_json.sh $IPADDR -n "$NAME"
## update_json.sh $IPADDR -v "$VLAN"

HELP(){
	echo "UPJSON: Syntax - "
	echo 'UPJSON: 	update_json.sh $IPADDR -n "$NAME"'
	echo 'UPJSON: 	update_json.sh $IPADDR -v "$VLAN"'
	exit
}

update_vlan(){
	IPADDR=$1
	VLAN=$2
	# Verify $VLAN is a number
	if ! [ $VLAN -eq $VLAN ] 2> /dev/null;then
		echo 'UPJSON: Invalid parameters - $VLAN must be a number'
		exit
	fi
	OLD_VLAN=$(cat /www/switchplease/json/systeminfo.json | grep -B 1 $IPADDR | grep vlan | tr ' ' '\0')
	NEW_VLAN=$(printf "\t\t\t\t\t\"vlan\":\"$VLAN\",")
#	cat /www/switchplease/json/systeminfo.json | awk -v ip="$IPADDR" -v old="$OLD_VLAN" -v new="$NEW_VLAN" '$0 ~ ip{sub(old, new, last)} NR>1{print last} {last=$0} END {print last}' > /www/switchplease/json/systeminfo.json
	sed -i "/\"$IPADDR\"/{n;s/.*/$NEW_VLAN/}" /www/switchplease/json/systeminfo.json
}

#add_name(){
#	START=$(cat /www/switchplease/json/systeminfo.json | grep $IPADDR -m 1 | tr ' ' '\0')
#	sed -i "s/\"$START\"/$START,\\n\t\t\t\t\t\"name\":\"$NAME\"/g" /www/switchplease/json/systeminfo.json
#}

update_name(){
	NEW_NAME=$(printf "\t\t\t\t\t\"name\":\"$NAME\"")
	sed -i "/\"$IPADDR\"/{n;n;s/.*/$NEW_NAME/}" /www/switchplease/json/systeminfo.json
}

name_handler(){
	IPADDR=$1
	NAME=$2
	# Decide whether to add_name or update_name based on whether "name" field exists for $IPADDR in systeminfo.json
	CHECK_NAME=$(cat /www/switchplease/json/systeminfo.json | grep -A 2 -m 1 "$IPADDR" | grep -c "name")
	if [ $CHECK_NAME -eq 0 ];then
		add_name
	elif [ $CHECK_NAME -eq 1 ];then
		update_name
	else
		echo "UPJSON: DAFUQ"
		exit
	fi
}

# Ensure valid parameterts passed to script
if [ $# -lt 3 ];then
	echo "UPJSON: Invalid parameters"
	HELP
fi
# Ensure /www/switchplease/json/systeminfo.json exists
if [ ! -e "/www/switchplease/json/systeminfo.json" ];then
	echo "UPJSON: Cannot update systeminfo.json. File does not exist."
	exit
fi
# Evaluate "name" or "vlan"
case $2 in
	-n) 
		NAME=$(echo "$@" | cut -d' ' -f3-)
		name_handler $1 "$NAME"
		;;
	-v) update_vlan $1 "$3";;
	*) HELP;;
esac
