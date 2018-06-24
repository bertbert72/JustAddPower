#!/bin/sh

##
## Copyright (c) 2004-2012
## ASPEED Technology Inc. All Rights Reserved
## Proprietary and Confidential
##
## By using this code you acknowledge that you have signed and accepted
## the terms of the ASPEED SDK license agreement.
##


######  Link Manager Host/Client State Defines
#s_init
#s_idle
#s_search			client ONLY
#s_start_srv
#s_srv_on
#s_attaching		host ONLY. for video only
#s_stop_srv
#s_error
#s_pre_srv_on		host ONLY

######  Link Manager Host/Client Event Defines
#e_sys_init_ok
#e_button_link or button_link
#e_button_link_1 or button_link_1
#e_button_pairing or button_pairing
#e_button_pairing_1 or button_pairing_1
#e_kill
#e_no_gw			no gateway(host) found. client ONLY.
#e_found_gw		client ONLY
#e_reconnect
#e_stop_link
#e_chg_hostname
#e_usbip_init_ok
#e_usbip_user_init_ok
#e_videoip_init_ok
#e_heartbeat_init_ok
#e_all_init_ok
#e_video_start_working
#e_video_stop_working
#e_usbip_stopped
#e_usbip_user_stopped
#e_videoip_stopped
#e_heartbeat_stopped
#e_all_stopped
#e_attach			host ONLY
#e_no_heartbeat
#e_debug
#e_timeout
#e_no_usb			don't run usb service
#e_no_video		don't run video service
#e_no_i2s			don't run i2s service
#e_i2s_init_ok
#e_i2s_stopped
#e_no_ir			don't run IR service
#e_iroip_init_ok
#e_iroip_stopped
#e_video_stat_client_read_edid
#e_video_stat_client_wait_host_info
#e_video_stat_mode_1080p
#e_video_stat_mode_non_1080p
#e_ip_got::xxx.xxx.xxx.xxx
#e_ip_del::xxx.xxx.xxx.xxx
#e_ip_remote_got::$GWIP
#e_usb_all_init_ok	for $SHARE_USB='y'
#e_usb_all_stopped	for $SHARE_USB='y'
#e_video_unsupported_mode
#e_video_mode_changed
#e_no_vhub_heartbeat	for vhub heartbeat
#e_vhub_heartbeat_init_ok	for vhub heartbeat
#button_remote_ctrl_pressed
#button_remote_ctrl_released
#e_name_id		used to indicate the hastname id
#e_attaching_XXXXXXXX got this event when a client with IP XXXXXXXX attached
#e_start_usb for client only
#e_stop_usb for client only
#button_chg_ch		When this button is pressed, client should reload and save the channel setting from 4-bits dip switch and re-connect.
#e_eth_link_on
#e_eth_link_off
#e_osd_test
#e_video_unsupported_refresh_rate
#e_vw_moninfo_	used to enable video wall's frame compensation.
#e_vw_enable_	used to setup and enable video wall layout
#r${THE_ROW_ID}_XXXXX		send event XXXXX to rs232 cascaded device with $THE_ROW_ID id
#${VW_VAR_POS_IDX}_XXXX	accept and send event XXXX only when VW_VAR_POS_IDX matched
#e_vw_refresh_pos_idx
#e_vw_h_shift_r_xx
#e_vw_h_shift_l_xx
#e_vw_h_scale_xx
#e_vw_v_scale_xx
#e_vw_install_state_on/off
#e_vw_config_osd_on for console API
#e_vw_config_osd_off for console API
#e_vw_pos_layout_R_C   This event is used to save vw_pos_max_row and vw_pos_max_col
#e_vw_v_shift_u_   Video wall vertical shift up
#e_vw_v_shift_d_   Video wall vertical shift down
#e_vwbtn_menu_cancel|on|off
#e_vw_delay_kick_XX
#e_vw_reset_to_pos_R_C
#e_sh_cmd=$shellCmds   This is the LM shell
#e_usb_request_on_off   console API command for "share_usb=y"
#e_start_srv_hp_time_up::$S_SEARCH_TOKEN  Client only

######### Actions from message channel
#act_pwr_ctrl_press
#act_pwr_ctrl_release
#act_osd_on_X  ask client to display OSD number X
#act_e_button_pairing  request to fire a e_button_pairing event
#act_e_button_pairing_1  request to fire a e_button_pairing event
#act_e_start_usb request client to start usb
#act_e_stop_usb request client to stop usb
#msg_e_request_usb
#msg_e_vw_moninfo_
#msg_to${CLIENT_IP}_XXXXXXXXXXXXXX

######### Video state & mode
#//common states
#V_STATE_INITIALIZING 0x0//start state
#V_STATE_OPERATING 0x1
#V_STATE_RESETING 0x2
#V_STATE_REMOVING 0xFFFFFFFF
#//host-specific states
#V_HOST_STATE_LOOPBACK 0x10
#V_HOST_STATE_READING_EDID 0x11
#V_HOST_STATE_WAITING_CLIENT_INFO 0x12
#V_HOST_STATE_DETECTING_MODE 0x13
#V_HOST_STATE_WAITING_CLIENT_READY 0x15
#V_HOST_STATE_WAITING_CLIENT_RESCALE_DONE 0x16
#//client-specific states
#V_CLIENT_STATE_RETRYING_READING_EDID 0x22
#V_CLIENT_STATE_WAITING_HOST_MODE 0x23
#V_CLIENT_STATE_WAITING_HOST_RESCALE_READY 0x26
#V_MODE_1080P
#V_MODE_NON_1080P
#V_MODE_UNKNOWN

######  PIPE
PIPE="/var/event_pipe"
PIPE_INFO_LOCAL="/var/info_local"
PIPE_INFO_REMOTE="/var/info_remote"
PIPE_INFO_OSD="/var/info_osd"
PIPE_ACK="/var/event_pipe_ack"
PIPE_INFO_GUI_ACTION="/var/info_gui_action"


######  GPIO & LED defines
LED_LINK="led_link"
LED_PWR="led_pwr"

######  VideoIP defines
VIDEO_SYS_PATH="/sys/devices/platform/videoip"
HDMIRX_SYS_PATH="/sys/devices/platform/$V_RX_DRV"
DISPLAY_SYS_PATH="/sys/devices/platform/display"
I2S_SYS_PATH="/sys/devices/platform/1500_i2s"
IR_SYS_PATH="/sys/devices/platform/IRoIP"
MAC_SYS_PATH="/sys/devices/platform/ftgmac"
GPIO_SYS_PATH="/sys/class/leds"
KMOIP_SYS_PATH="/sys/devices/platform/kmoip"
VHUB_SYS_PATH="/sys/devices/platform/vhci_hcd"
SCU_SYS_PATH="/sys/devices/platform/scu"

#watchdog defines & functions
WATCHDOG_AVAILABLE='n'

DEVICE_STATUS_FILE="/var/ast_device_status"
OSD_FROM_GUI='y'
JUMBO_MTU='8000'

. bash/utilities.sh

. ./osd_str.sh
. ./vw_osd.sh

init_watchdog()
{
	if [ -d /sys/devices/platform/watchdog ]; then
		echo "watchdog available"
		WATCHDOG_AVAILABLE='y'
		# set timeout will enable the watchdog, but won't touch
		# the enable flag. So, we should enable the flag here.
		echo 'yes' > /sys/devices/platform/watchdog/enable
		# Set watchdog timeout to 50 secs
		echo 50 > /sys/devices/platform/watchdog/timeout
	else
		echo "watchdog unavailable"
		WATCHDOG_AVAILABLE='n'
	fi
}

#enable_watchdog()
#{
#	if [ "$WATCHDOG_AVAILABLE" = 'y' ]; then
#		echo yes > /sys/devices/platform/watchdog/enable
#	fi
#}

disable_watchdog()
{
	if [ "$WATCHDOG_AVAILABLE" = 'y' ]; then
		echo no > /sys/devices/platform/watchdog/enable
	fi
}

tickle_watchdog()
{
	if [ "$WATCHDOG_AVAILABLE" = 'y' ]; then
		echo > /sys/devices/platform/watchdog/tickle
	fi
}

start_watchdog_daemon()
{
	if [ "$WATCHDOG_AVAILABLE" = 'y' ]; then
		_t="$1"
		if [ -z "$1" ]; then
			# tickle every 10 sec by default
			_t='10'
		fi
		watchdog_daemon.sh "$_t" &
		# Set watchdog timeout to shorter 35 secs
		echo 35 > /sys/devices/platform/watchdog/timeout
	fi
}

stop_watchdog_daemon()
{
	if [ "$WATCHDOG_AVAILABLE" = 'y' ]; then
		# Set watchdog timeout back to 50 secs
		echo 50 > /sys/devices/platform/watchdog/timeout
		pkill watchdog_daemon 2> /dev/null
	fi
}

###### GPIO & LED functions
enable_remote_ctrl_button()
{
	if [ "$FPGA_TEST" = '1' ]; then
		return
	fi

	echo 'pushbutton' > "${GPIO_SYS_PATH}"/button_remote_ctrl/trigger
}

led_on()
{
	if [ "$FPGA_TEST" = '1' ]; then
		return
	fi

	# $1 is the led name to be access. Ex: $LED_LINK
	echo none > ${GPIO_SYS_PATH}/$1/trigger
	echo 1 > ${GPIO_SYS_PATH}/$1/brightness
}
led_off()
{
	if [ "$FPGA_TEST" = '1' ]; then
		return
	fi

	# $1 is the led name to be access. Ex: $LED_LINK
	echo none > ${GPIO_SYS_PATH}/$1/trigger
	echo 0 > ${GPIO_SYS_PATH}/$1/brightness
}
led_blink()
{
	if [ "$FPGA_TEST" = '1' ]; then
		return
	fi
	# $1 is the led name to be access. Ex: $LED_LINK
	echo timer > ${GPIO_SYS_PATH}/$1/trigger
}

_osd_position()
{
	if [ "$SOC_VER" -ge '3' ]; then
	#_osd_position "$OSDPIC_OSD_POSITION_ALIGN" "$OSDPIC_OSD_POSITION_X_START_OFFSET" "$OSDPIC_OSD_POSITION_Y_START_OFFSET"
	echo "$1" "$2" "$3" > "$DISPLAY_SYS_PATH"/osd_position
	fi
}

osd_position()
{
	#osd_position "$_OSD_POSITION_ALIGN" "$_OSD_POSITION_X_START_OFFSET" "$_OSD_POSITION_Y_START_OFFSET"
	OSDPIC_OSD_POSITION_ALIGN="$1"
	OSDPIC_OSD_POSITION_X_START_OFFSET="$2"
	OSDPIC_OSD_POSITION_Y_START_OFFSET="$3"

	_osd_position "$OSDPIC_OSD_POSITION_ALIGN" "$OSDPIC_OSD_POSITION_X_START_OFFSET" "$OSDPIC_OSD_POSITION_Y_START_OFFSET"
}

_osd_off_pic()
{
	if [ ${HAS_GUI} = 'n' ]; then
		return
	fi

	# Turn off OSD first before change GUI
	echo 0 > "$DISPLAY_SYS_PATH"/osd_from_gui

	if [ "$CURRENT_SCREEN" = '2' ]; then
		# In decode screen
		inform_gui_action "GUI_show_picture::../usr/local/bin/mono.jpg::$GUI_SHOW_TEXT_RUNTIME"

		# if OSD_STR session exists, we don't turn off CRT's OSD. Just remove GUI's pic
		if ! [ -z "$OSD_STR_UUID" ]; then
			echo "1 $OSDSTR_OSD_TRANSPARENT $OSDSTR_OSD_BKGRND_MASK_EN $OSDSTR_OSD_Y_START $OSDSTR_OSD_MAX_Y_SIZE" > "$DISPLAY_SYS_PATH"/osd_from_gui
		fi
	else
		# In GUI screen
		#echo "GUI_show_picture::$GUI_PICTURE_NAME::$GUI_SHOW_TEXT_RUNTIME"
		inform_gui_action "GUI_show_picture::$GUI_PICTURE_NAME::$GUI_SHOW_TEXT_RUNTIME"
	fi

	# Clear OSD_PIC_UUID to indicate current OSD_PIC session is done
	OSD_PIC_UUID=''
}

osd_off_pic()
{
	#e_osd_off_pic::OSD_PIC_UUID

	case "$*" in
		e_osd_off_pic::"$OSD_PIC_UUID")
			# off
			#echo "OSD PIC OFF!!$OSD_PIC_UUID"
			_osd_off_pic
		;;
		e_osd_off_pic::now)
			# force off
			#echo "Force OSD PIC OFF!!"
			_osd_off_pic
		;;
		#*)
		#	# do nothing
		#	echo "aged OSD off"
		#;;
	esac
}

_osd_on_pic()
{
	#osd_on_pic "$_OSD_Y_START" "$_OSD_MAX_Y_SIZE" "$_OSD_TRANSPARENT" "$_OSD_BKGRND_MASK_EN" "$_OFF_TIMER" "$_OSD_PIC_FILE" "$_OSD_PIC_OPTION"
	inform_gui_action "GUI_show_picture::$6::n"
	_osd_position "$OSDPIC_OSD_POSITION_ALIGN" "$OSDPIC_OSD_POSITION_X_START_OFFSET" "$OSDPIC_OSD_POSITION_Y_START_OFFSET"
	echo "1 $3 $4 $1 $2" > "$DISPLAY_SYS_PATH"/osd_from_gui
}

osd_on_pic()
{
	#osd_on_pic "$_OSD_Y_START" "$_OSD_MAX_Y_SIZE" "$_OSD_TRANSPARENT" "$_OSD_BKGRND_MASK_EN" "$_OFF_TIMER" "$_OSD_PIC_FILE" "$_OSD_PIC_OPTION"
	# TODO. Validate input parameters.
	if [ "$#" != '7' ]; then
		echo "ERROR!! wrong osd_on_pic()"
		return
	fi

	local _OFF_TIMER="$5"
	# Create a new OSD_STR session
	OSD_PIC_UUID="PIC$RANDOM"
	OSDPIC_OSD_Y_START="$1"
	OSDPIC_OSD_MAX_Y_SIZE="$2"
	OSDPIC_OSD_TRANSPARENT="$3"
	OSDPIC_OSD_BKGRND_MASK_EN="$4"
	OSDPIC_OSD_OFF_TIMER="$5"
	OSDPIC_OSD_PIC_FILE="$6"
	OSDPIC_OSD_PIC_OPTION="$7"

	# Start OSD off timer
	if [ "$_OFF_TIMER" != 'n' ]; then
		{ sleep $_OFF_TIMER; ast_send_event -1 e_osd_off_pic::$OSD_PIC_UUID; } &
	fi

	if [ "$CURRENT_SCREEN" = '1' ]; then
		# Don't do it under console screen. osd_recover() will take effect.
		return
	fi
	# Run in background in case GUI runs slow
	_osd_on_pic "$@"
}

_osd_off_str()
{
	if [ ${HAS_GUI} = 'n' ]; then
		return
	fi

	# Bruce: Don't run in background. It causes race condition.
	# Bruce160302. Hope new CRT driver resolves the race condition. And we put PIPE access to background to avoid LM hang and enhance LM performance(?).
	{ printf ", 30, 0xFF00FF00\0"; } > "$PIPE_INFO_OSD" &

	# if OSD_PIC session exists, we don't turn off CRT's OSD. Just remove GUI's string.
	if [ -z "$OSD_PIC_UUID" ]; then
		echo 0 > "$DISPLAY_SYS_PATH"/osd_from_gui
	#else
	#	# This line should be redundent. OSD_PIC has higher CRT OSD setting priority.
	#	# So, there should have no overwrite and hence no recover needed.
	#	echo "1 $OSDPIC_OSD_TRANSPARENT $OSDPIC_OSD_BKGRND_MASK_EN $OSDPIC_OSD_Y_START $OSDPIC_OSD_MAX_Y_SIZE" > "$DISPLAY_SYS_PATH"/osd_from_gui
	fi

	# Clear OSD_STR_UUID to indicate current OSD_STR session is done
	OSD_STR_UUID=''
}

osd_off_str()
{
	#e_osd_off_str::OSD_STR_UUID

	case "$*" in
		e_osd_off_str::"$OSD_STR_UUID")
			# off
			#echo "OSD OFF!!$OSD_STR_UUID"
			_osd_off_str
		;;
		e_osd_off_str::now)
			# force off
			#echo "Force OSD OFF!!"
			_osd_off_str
		;;
		#*)
		#	# do nothing
		#	echo "aged OSD off"
		#;;
	esac
}

_osd_on_str()
{
	#osd_on_str "$OSD_Y_START" "$OSD_MAX_Y_SIZE" "$OSD_TRANSPARENT" "$OSD_BKGRND_MASK_EN" "$OFF_TIMER" "$OSD_STR_FILE" "$OSD_FONT_SIZE" "$OSD_FONT_COLOR"
	{ printf "$6, $7, ${8}\0"; } > "$PIPE_INFO_OSD" &

	# Use OSD_PIC session's CRT OSD setting is preferred.
	if [ -z "$OSD_PIC_UUID" ]; then
		_osd_position "0" "0" "0"
		echo "1 $3 $4 $1 $2" > "$DISPLAY_SYS_PATH"/osd_from_gui
	fi
}

osd_on_str()
{
	#osd_on_str "$OSD_Y_START" "$OSD_MAX_Y_SIZE" "$OSD_TRANSPARENT" "$OSD_BKGRND_MASK_EN" "$OFF_TIMER" "$OSD_STR_FILE" "$OSD_FONT_SIZE" "$OSD_FONT_COLOR"
	# TODO. Validate input parameters.
	if [ "$#" != '8' ]; then
		echo "ERROR!! wrong osd_on_str()"
		return
	fi

	local _OFF_TIMER="$5"
	# Create a new OSD_STR session
	OSD_STR_UUID="STR$RANDOM"
	OSDSTR_OSD_Y_START="$1"
	OSDSTR_OSD_MAX_Y_SIZE="$2"
	OSDSTR_OSD_TRANSPARENT="$3"
	OSDSTR_OSD_BKGRND_MASK_EN="$4"
	OSDSTR_OSD_OFF_TIMER="$5"
	OSDSTR_OSD_STR_FILE="$6"
	OSDSTR_OSD_FONT_SIZE="$7"
	OSDSTR_OSD_FONT_COLOR="$8"

	# Start OSD off timer
	if [ "$_OFF_TIMER" != 'n' ]; then
		{ sleep $_OFF_TIMER; ast_send_event -1 e_osd_off_str::$OSD_STR_UUID; } &
	fi

	# Run in background in case GUI runs slow
	_osd_on_str "$@"
}

_osd_recover()
{
	if [ -n "$OSD_PIC_UUID" ]; then
		osd_on_pic  "$OSDPIC_OSD_Y_START" "$OSDPIC_OSD_MAX_Y_SIZE" "$OSDPIC_OSD_TRANSPARENT" "$OSDPIC_OSD_BKGRND_MASK_EN" "$OSDPIC_OSD_OFF_TIMER" "$OSDPIC_OSD_PIC_FILE" "$OSDPIC_OSD_PIC_OPTION"
	fi
	#if [ -n "$OSD_STR_UUID" ]; then
	#	osd_on_str "$OSDSTR_OSD_Y_START" "$OSDSTR_OSD_MAX_Y_SIZE" "$OSDSTR_OSD_TRANSPARENT" "$OSDSTR_OSD_BKGRND_MASK_EN" "$OSDSTR_OSD_OFF_TIMER" "$OSDSTR_OSD_STR_FILE" "$OSDSTR_OSD_FONT_SIZE" "$OSDSTR_OSD_FONT_COLOR"
	#fi
}

osd_recover()
{
	if [ "$SOC_OP_MODE" -lt "3" ]; then
		return
	fi

	if [ -n "$OSD_PIC_UUID" ]; then
		_osd_position "$OSDPIC_OSD_POSITION_ALIGN" "$OSDPIC_OSD_POSITION_X_START_OFFSET" "$OSDPIC_OSD_POSITION_Y_START_OFFSET"
	fi
	# Bruce150901. CRT may run faster then GUI and causes background mask color incorrect.
	# Bruce can't find an easy way to resolve this issue. So, add some more re-try
	# here to workaround this issue.
	_osd_recover
	# Bruce151221. Following retry is buggy because $OSD_PIC_UUID won't reflect the realtime value.
	#              I'm going to rely on CRT driver retry to check GUI's update.
	#{ usleep 50000; _osd_recover; } &
	#{ usleep 100000; _osd_recover; } &
	#{ usleep 500000; _osd_recover; } &
}

osd_off()
{
	VWOSD_STATE='off'
	if [ ${HAS_GUI} = 'n' ]; then
		return
	fi
	pkill -9 osd_off 2> /dev/null
	osd_off.sh $1 "$OSD_FROM_GUI" "$DISPLAY_SYS_PATH" "$PIPE_INFO_OSD" &
	return

	sleep $1
	if [ "$OSD_FROM_GUI" = 'y' ]; then
		echo 0 > "$DISPLAY_SYS_PATH"/osd_from_gui
		{ printf ", 30, 0xFF00FF00\0"; } > "$PIPE_INFO_OSD"
	else
		echo "0" > "$DISPLAY_SYS_PATH"/osd
	fi
}

# This function is only used for LM's own OSD string messages
_osd_on()
{
	#_osd_on osd_msg, osd_font_size, osd_font_color, osd_transparent, osd_max_y_size, off_timer
	if [ "$#" != '6' ]; then
		echo "ERROR!! wrong _osd_on()"
		return
	fi
	
	#osd_on_str "$OSD_Y_START" "$OSD_MAX_Y_SIZE" "$OSD_TRANSPARENT" "$OSD_BKGRND_MASK_EN" "$OFF_TIMER" "$OSD_STR_FILE" "$OSD_FONT_SIZE" "$OSD_FONT_COLOR"
	osd_on_str "0" "$5" "$4" "1" "$6" "$1" "$2" "$3"
	return

	################ OLD CODE ####################
	#printf "$1, $2, $3\0" > "$PIPE_INFO_OSD"
	# Bruce150716. Instead of direct printf, we use 'cat' to cat a whole file to pipe to avoid Bash printf EOF problem.
	__tmp=/var/osd_$RANDOM
	printf "$1, $2, $3\0" > $__tmp
	cat $__tmp > "$PIPE_INFO_OSD"
	rm -f $__tmp

	echo "1 $4 1 0 $5" > "$DISPLAY_SYS_PATH"/osd_from_gui
}

###########################################################
# Following script is used for further customization.
# Don't uncomment it unless you understand what to do.
###########################################################
_osd_customize()
{
	local _osd_msg
	case "$1" in
		0)
			_osd_msg="$OSD_MSG0"
		;;
		1)
			_osd_msg="$OSD_MSG1"
		;;
		2)
			_osd_msg="$OSD_MSG2"
		;;
		3)
			_osd_msg="$OSD_MSG3"
		;;
		4)
			_osd_msg="$OSD_MSG4"
		;;
		5)
			_osd_msg="$OSD_MSG5"
		;;
		6)
			_osd_msg="$OSD_MSG6"
		;;
		7)
			_osd_msg="$OSD_MSG7"
		;;
		8)
			_osd_msg="$OSD_MSG8"
		;;
		9)
			_osd_msg="$OSD_MSG9"
		;;
		10)
			_osd_msg="$OSD_MSG10"
		;;
		11)
			_osd_msg="$OSD_MSG11"
		;;
		*)
			_osd_msg=" "
		;;
	esac

	#echo "_osd_customize $_osd_msg '$2'"
	_osd_on "$_osd_msg" "$OSD_FONT_SIZE" "$OSD_FONT_COLOR" "$OSD_TRANSPARENT" "$OSD_MAX_Y_SIZE" "$2"
}

osd_on()
{
	if [ "$IS_HOST" = 'n' ]; then
		# Client
		if [ ${HAS_GUI} = 'n' ]; then
			return
		fi
		case `cat "$DISPLAY_SYS_PATH"/screen` in
			*'message screen'* | *'no screen'*)
				# We are not going to show OSDs under non-decode screen
				return
			;;
			*)
			;;
		esac
		if [ "$OSD_FROM_GUI" = 'y' ]; then
			_osd_customize "$1" "$2"
		else
			echo "1 15 $1" > "$DISPLAY_SYS_PATH"/osd
		fi
	else
		# Host need to broadcast msg to clients
		ast_send_event -1 "msg_osd_on_$1"
	fi
}

_ch_hex_to_dec()
{
	case "$CH_SELECT" in
		0000)
			echo "01"
		;;
		0001)
			echo "02"
		;;
		0010)
			echo "03"
		;;
		0011)
			echo "04"
		;;
		0100)
			echo "05"
		;;
		0101)
			echo "06"
		;;
		0110)
			echo "07"
		;;
		0111)
			echo "08"
		;;
		1000)
			echo "09"
		;;
		1001)
			echo "10"
		;;
		1010)
			echo "11"
		;;
		1011)
			echo "12"
		;;
		1100)
			echo "13"
		;;
		1101)
			echo "14"
		;;
		1110)
			echo "15"
		;;
		1111)
			echo "16"
		;;
		*)
		;;
	esac
}

osd_set_to()
{
	case "$1" in
		VIDEO_INITIALIZED)
			return
		;;
		VIDEO_CLIENT_READ_EDID)
			return
		;;
		VIDEO_CLIENT_WAIT_HOST_INFO)
			return
		;;
		VIDEO_START_DECODE)
			if [ "$SHOW_CH_OSD" = 'y' ]; then
				( # Use subshell, (), to export OSD_OFF_TIMER
					export OSD_OFF_TIMER='3'
				osd_on_tl.sh "\n    "`_ch_hex_to_dec`
				)
			fi
			return
		;;
		VIDEO_GRAPHIC_MODE)
			osd_on 0 $2
		;;
		VIDEO_VIDEO_MODE)
			osd_on 1 $2
		;;
		VIDEO_ANTIDITHER_OFF)
			osd_on 2 $2
		;;
		VIDEO_ANTIDITHER_1)
			osd_on 3 $2
		;;
		VIDEO_ANTIDITHER_2)
			osd_on 4 $2
		;;
		VIDEO_UNSUPPORTED_MODE)
			osd_on 5 $2
		;;
		VIDEO_MODE_CHANGED)
			osd_on 6 $2
		;;
		REQUEST_USB)
			osd_on 7 $2
		;;
		START_USB)
			osd_on 8 $2
		;;
		STOP_USB)
			osd_on 9 $2
		;;
		VIDEO_UNSUPPORTED_REFRESH_RATE)
			osd_on 10 $2
		;;
		VIDEO_HDCP_FAIL)
			osd_on 11 $2
		;;
		OSD_OFF)
			_osd_off_str
			return
		;;
		*)
		;;
	esac

}

load_sii9679_drv()
{
	# FIXME. This is actually platform dependent
	if [ "$SOC_VER" -lt '3' ]; then
		return
	fi

	insmod sii9679.ko
	local _major=`cat /proc/devices | awk "\\$2==\"sii9679\" {print \\$1}"`
	if [ -n "$_major" ]; then
		mknod /dev/sii9679 c $_major 0
	fi
}

load_sii9678_drv()
{
	# FIXME. This is actually platform dependent
	if [ "$SOC_VER" -lt '3' ]; then
		return
	fi

	# SiI9678 driver is built-in together with CRT driver. So, only make node here.
	local _major=`cat /proc/devices | awk "\\$2==\"sii9678\" {print \\$1}"`
	if [ -n "$_major" ]; then
		mknod /dev/sii9678 c $_major 0
	fi
}

stop_videoip_remote()
{
	pkill -9 asthost 2>/dev/null

	#disable remote will also disconnect all connected clients
	echo disable > "$VIDEO_SYS_PATH"/Remote
}

unload_videoip_c()
{
	# Bruce151225. We call unload_videoip_c in major thread instead background.
	# There is a bug which somehow causing VIDEOIP_RDY never be 'n'.
	# This bug is difficult to duplicate. It occurs when doing e_reconnect stress test.
	# To avoid this issue, we call unload_videoip_c() in forground so that
	# e_videoip_stopped event is no more necessary.
	echo 1 > $VIDEO_SYS_PATH/unlink
	VIDEOIP_RDY='n'
	return

	echo 1 > $VIDEO_SYS_PATH/unlink
	#pkill -9 astclient
	#rmmod videoip.ko
	ast_send_event -1 e_videoip_stopped
}

load_videoip_driver_c()
{
	if [ "$HDCP_ALWAYS_ON_22" = 'y' ]; then
		HDCP_MODE=$(( $HDCP_MODE | 0x100000 ))
	elif [ "$HDCP_ALWAYS_ON" = 'y' ]; then
		HDCP_MODE=$(( $HDCP_MODE | 0x40000 ))
	fi

	insmod videoip.ko init_hdcp_mode=$HDCP_MODE hdcp2_version=$HDCP2_VERSION drv_option=$V_ENG_DRV_OPTION hdmi_force_rgb_out=$V_HDMI_FORCE_RGB_OUTPUT
	if [ -f "$VIDEO_SYS_PATH/gen_lock_cfg" ]; then
		echo $V_GEN_LOCK_CFG > $VIDEO_SYS_PATH/gen_lock_cfg
	fi
}

select_v_input_by_current()
{
	echo `cat $VIDEO_SYS_PATH/rx`
}

select_v_input_by_swap_current()
{
	# Default 'current' value is decided in SCU and VE driver,
	# which uses similar decision flow as select_v_input().
	local _t=`cat $VIDEO_SYS_PATH/rx`
	case "$_t" in
		digital)
			echo "analog"
		;;
		analog)
			echo "digital"
		;;
		*)
			echo "digital"
		;;
	esac
}

select_v_input_from_gpio()
{
	# Request GPIO value
	echo 0 > ${GPIO_SYS_PATH}/v_input/brightness 2>/dev/null
	# Get the value now
	V_INPUT_FROM_GPIO=`cat ${GPIO_SYS_PATH}/v_input/brightness 2>/dev/null`
	# GPIO num mapping is based on SW port# define
	case "$V_INPUT_FROM_GPIO" in
		0)
			echo 'digital'
		;;
		1)
			echo 'analog'
		;;
		*)
			echo 'digital'
		;;
	esac
}

select_v_input_from_v_type()
{
	# 0: VGA
	# 1: disable
	# 2: HDMI
	# 3: DVI
	case "$V_TYPE" in
		0)
			echo "analog"
		;;
		*)
			echo "digital"
		;;
	esac
}

select_v_input_detect_sync()
{
	# $1: swap, gpio, refresh
	local _type="$1"

	if [ "$V_DUAL_INPUT" = "n" ]; then
		select_v_input_from_v_type
		return
	fi

	# For dual input auto selection:
	case "$_type" in
		swap) # swap current port
			select_v_input_by_swap_current
		;;
		gpio) # select from GPIO, for GPIO changes
			select_v_input_from_gpio
		;;
		refresh) # as it is, means current.
			# May not be equal to GPIO setting when user used e_v_select_input_xxxx to runtime change input port.
			select_v_input_by_current
		;;
		*)
			select_v_input_by_current
		;;
	esac
}

select_v_input()
{
	# $1: swap, gpio, refresh
	local _type="$1"

	# SOC_VER < 3 doesn't support dual port input.
	if [ "$SOC_VER" -lt '3' ]; then
		select_v_input_by_current
		return
	fi

	# Specific v_input_select has highest priority.
	case "$V_INPUT_SELECT" in
		fixed)
			select_v_input_from_v_type
		;;
		auto) # for user don't like auto swap port.
			select_v_input_from_gpio
		;;
		detect_sync)
			select_v_input_detect_sync "$_type"
		;;
		*)
			echo "digital"
		;;
	esac
}

select_a_input_from_gpio()
{
	# Request GPIO value
	echo 0 > ${GPIO_SYS_PATH}/a_input/brightness 2>/dev/null
	# Get the value now
	A_INPUT_FROM_GPIO=`cat ${GPIO_SYS_PATH}/a_input/brightness 2>/dev/null`
	# GPIO num mapping 0:digital 1:analog codec
	case "$A_INPUT_FROM_GPIO" in
		0)
			echo 'hdmi'
		;;
		1)
			echo 'analog'
		;;
		*)
			echo 'hdmi'
		;;
	esac
}

select_a_input_per_v_input()
{
	local _t=`cat $VIDEO_SYS_PATH/rx`
	case "$_t" in
		digital)
			echo "hdmi"
		;;
		analog)
			echo "analog"
		;;
		*)
			#echo "Unsupported video input type?! ($_t)"
			select_a_input_from_gpio
		;;
	esac
}

select_a_input_auto()
{
	# decide audio port. auto mode.
	# When video port is HDMI/DVI, select audio port per GPIO.
	# When video port is VGA, always select analog codec audio port.
	local _t=`cat $VIDEO_SYS_PATH/rx`
	case "$_t" in
		digital)
			select_a_input_from_gpio
		;;
		analog)
			echo "analog"
		;;
		*)
			#echo "Unsupported video input type?! ($_t)"
			select_a_input_from_gpio
		;;
	esac
}

select_a_input()
{
	# SOC_VER < 2 doesn't support dual port input.
	if [ "$SOC_VER" -lt '2' ]; then
		echo "hdmi"
		return
	fi

	case "$A_IO_SELECT" in
		hdmi)
			echo "hdmi"
		;;
		analog)
			echo "analog"
		;;
		auto) # HDMI per GPIO, VGA fixed codec.
			select_a_input_auto
		;;
		auto_1) # always per GPIO.
			select_a_input_from_gpio
		;;
		auto_2) # always per video port. HDMI/DVI use HDMI audio, VGA use codec audio.
			select_a_input_per_v_input
		;;
		*)
			select_a_input_from_gpio
		;;
	esac
}

apply_profile_config()
{
	local _old_name="${PROFILE_FOLDER}/${PROFILE_NAME}"
	local _port='0'
	PROFILE_FOLDER="digital"

	case "$1" in
		digital)
			echo "select digital source"
			PROFILE_FOLDER='digital'
			_port='0'
		;;
		analog)
			echo "select analog source"
			PROFILE_FOLDER='analog'
			_port='1'
		;;
		*)
			echo "source undetermined"
			PROFILE_FOLDER='digital'
			_port='0'
		;;
	esac

	if [ "$PROFILE" = 'auto' ]; then
			# Auto choose based on link mode.
			# Assume $ETH_LINK_MODE is valid and correct at this point.
			case "$ETH_LINK_MODE" in
				'10M')
					PROFILE_NAME='10M'
				;;
				'100M')
					PROFILE_NAME='100M'
				;;
				*)
					# 1G and unknown
					PROFILE_NAME='default'
				;;
			esac
	else
		PROFILE_NAME="$PROFILE"
	fi

	# Video Wall profile applies ONLY to SoC OP MODE 1 and must overwrite PROFILE setting.
	if [ "$SOC_OP_MODE" = '1' ]; then
		if [ "$EN_VIDEO_WALL" = 'y' ] && [ "$VW_VAR_MAX_ROW" != '0' ]; then
			echo "select video wall profile"
			if [ "$VW_VAR_MAX_ROW" -gt '3' ]; then
				PROFILE_NAME="video_wall_3"
			else
				PROFILE_NAME="video_wall_$VW_VAR_MAX_ROW"
			fi
		fi
	fi

	if ! [ -d ./V$SOC_OP_MODE/profile/"${PROFILE_FOLDER}/${PROFILE_NAME}" ]; then
		echo "Profile (V${SOC_OP_MODE}/profile/${PROFILE_FOLDER}/${PROFILE_NAME}) not exists!? Use default profile instead."
		PROFILE_NAME='default'
	fi

	if [ "${PROFILE_FOLDER}/${PROFILE_NAME}" != "$_old_name" ]; then
		printf "\n\nProfile=${PROFILE_FOLDER}/${PROFILE_NAME} vs $_old_name\n\n"
		cp -f ./V$SOC_OP_MODE/profile/"${PROFILE_FOLDER}/${PROFILE_NAME}"/* . 2>/dev/null
		# video_config should wait for the videoip.ko initialized
		video_config -s V2 -p "$_port"
		# video driver starts mode detection after this point.
	fi
}

start_videoip_h()
{
	if [ "$HDCP_ALWAYS_ON_22" = 'y' ]; then
		HDCP_MODE=$(( $HDCP_MODE | 0x100000 ))
	elif [ "$HDCP_ALWAYS_ON" = 'y' ]; then
		HDCP_MODE=$(( $HDCP_MODE | 0x40000 ))
	fi

	rmmod videoip 2>/dev/null
	insmod videoip.ko init_hdcp_mode=$HDCP_MODE hdcp2_version=$HDCP2_VERSION drv_option=$V_ENG_DRV_OPTION analog_edge_detect=$V_ANALOG_EDGE_DETECT
	mknod /dev/videoip c 250 0
	echo "$LOOPBACK_EDID_PATCH" > $VIDEO_SYS_PATH/loopback_edid_patch
	echo "$REMOTE_EDID_PATCH" > $VIDEO_SYS_PATH/remote_edid_patch
	# Config edid_use here so that edid_use value will always be as expected even when boot up with Ethernet link OFF.
	if [ "$MULTICAST_ON" = 'n' ]; then
		# Unicast mode always use remote EDID as primary.
	echo 'secondary' > $VIDEO_SYS_PATH/edid_use
	else
		# Init edid_use per $EDID_USE under multicast mode.
		echo $EDID_USE > $VIDEO_SYS_PATH/edid_use
	fi
	if [ "$LOOPBACK_DEFAULT_ON" = 'y' ]; then
		echo 1 > $VIDEO_SYS_PATH/LoopbackEnable
	else
		echo 0 > $VIDEO_SYS_PATH/LoopbackEnable
	fi
	echo "$V_1080I_TO_720P" > $VIDEO_SYS_PATH/force_1080i_to_720p
	echo "$V_CHUNK_SIZE" > $VIDEO_SYS_PATH/chunk_size
	echo "$V_FRAME_RATE" > $VIDEO_SYS_PATH/frame_rate_control
	echo "$V_DBG_MODE" > $VIDEO_SYS_PATH/videoip_debug

#	if [ "$DEFAULT_KSV" != 'unavailable' ]; then
#		echo "$DEFAULT_KSV" > $VIDEO_SYS_PATH/default_ksv
#	fi
	if [ "$HDCP2_GLOBAL_CONSTANT" != 'unavailable' ]; then
		echo "$HDCP2_GLOBAL_CONSTANT" > $VIDEO_SYS_PATH/hdcp2_global_constant
	fi
	if [ "$HDCP2_DCP_PUBLIC_KEY" != 'unavailable' ]; then
		echo "$HDCP2_DCP_PUBLIC_KEY" > $VIDEO_SYS_PATH/hdcp2_dcp_public_key
	fi

	cp -f ./V$SOC_OP_MODE/* . 2>/dev/null

	if [ "$EN_VIDEO_WALL" = 'y' ] && [ "$SOC_OP_MODE" = '1' ]; then
		# Only apply to host and SoC op mode == 1
		echo "$VW_VAR_V_SHIFT" > "$VIDEO_SYS_PATH"/vw_v_shift
		echo "$VW_VAR_MONINFO_HA $VW_VAR_MONINFO_HT $VW_VAR_MONINFO_VA $VW_VAR_MONINFO_VT" > "$VIDEO_SYS_PATH"/vw_frame_comp
		echo "${VW_VAR_MAX_ROW} ${VW_VAR_MAX_COLUMN} ${VW_VAR_ROW} ${VW_VAR_COLUMN}" > "$VIDEO_SYS_PATH"/vw_layout
	fi
	
	if [ "$SOC_VER" -ge '3' ]; then
		if [ "$V_DUAL_INPUT" = 'undefined' ]; then
			V_DUAL_INPUT=`cat $VIDEO_SYS_PATH/has_dual_input`
		fi
		# Note sysfs 'scu board_info' only available on SoC Ver >= 3
		case `cat  $SCU_SYS_PATH/board_info | grep "Video Type"` in
			*VGA*)
				V_TYPE='0'
			;;
			*Disable*)
				V_TYPE='1'
			;;
			*HDMI*)
				V_TYPE='2'
			;;
			*DVI*)
				V_TYPE='3'
			;;
			*)
				V_TYPE='2'
			;;
		esac
	fi

	apply_profile_config `select_v_input refresh`
}

vw_enable_v2()
{
	echo "$VW_VAR_ROTATE" > "$DISPLAY_SYS_PATH"/vw_rotate
	echo "${VW_VAR_V2_X1} ${VW_VAR_V2_Y1} ${VW_VAR_V2_X2} ${VW_VAR_V2_Y2}" > "$DISPLAY_SYS_PATH"/vw_layout_v2
}

vw_enable()
{
	if [ "$VW_VAR_VER" = '2' ]; then
		vw_enable_v2
		return
	fi

	if [ "$IS_HOST" = 'n' ]; then
		if [ "$SOC_OP_MODE" -ge "3" ]; then
			echo "$VW_VAR_STRETCH_TYPE" > "$DISPLAY_SYS_PATH"/vw_stretch_type
			echo "$VW_VAR_ROTATE" > "$DISPLAY_SYS_PATH"/vw_rotate
		fi
		echo "${VW_VAR_MAX_ROW} ${VW_VAR_MAX_COLUMN} ${VW_VAR_ROW} ${VW_VAR_COLUMN}" > "$DISPLAY_SYS_PATH"/vw_layout
		echo "${VW_VAR_MONINFO_HA} ${VW_VAR_MONINFO_HT} ${VW_VAR_MONINFO_VA} ${VW_VAR_MONINFO_VT}" > "$DISPLAY_SYS_PATH"/vw_frame_comp
		echo "$VW_VAR_H_SHIFT" > "$DISPLAY_SYS_PATH"/vw_h_shift
		echo "$VW_VAR_V_SHIFT" > "$DISPLAY_SYS_PATH"/vw_v_shift
		echo "$VW_VAR_H_SCALE $VW_VAR_V_SCALE" > "$DISPLAY_SYS_PATH"/vw_scale_up
		echo "$VW_VAR_DELAY_KICK" > "$VIDEO_SYS_PATH"/delay_dequeue
	elif [ "$SOC_OP_MODE" = '1' ]; then
		# Only apply to host and SoC op mode == 1
		echo "$VW_VAR_V_SHIFT" > "$VIDEO_SYS_PATH"/vw_v_shift
		echo "$VW_VAR_MONINFO_HA $VW_VAR_MONINFO_HT $VW_VAR_MONINFO_VA $VW_VAR_MONINFO_VT" > "$VIDEO_SYS_PATH"/vw_frame_comp
		echo "${VW_VAR_MAX_ROW} ${VW_VAR_MAX_COLUMN} ${VW_VAR_ROW} ${VW_VAR_COLUMN}" > "$VIDEO_SYS_PATH"/vw_layout
		apply_profile_config `select_v_input refresh`
	fi
}

start_videoip_remote()
{
	# Following asthost call will never return until killed.
	if [ "$MULTICAST_ON" = 'n' ]; then
		# Unicast mode always use remote EDID as primary.
		echo 'secondary' > $VIDEO_SYS_PATH/edid_use
		if [ "$UDP_ON" = 'n' ]; then
			asthost
		else
			asthost -m udp
		fi
	else
		echo $EDID_USE > $VIDEO_SYS_PATH/edid_use
		if [ "$SEAMLESS_SWITCH" = 'y' ]; then
			asthost -m $MULTICAST_IP -t no_tcp
		else
			asthost -m $MULTICAST_IP
		fi
	fi
}

start_videoip_loopback()
{
	echo "To loopback mode"
	if [ "$AST_PLATFORM" = "ast1500hv1" ]; then
		# do nothing
		echo ""
	else
		#insmod videoip.ko
		echo $EDID_USE > $VIDEO_SYS_PATH/edid_use
		echo 1 > $VIDEO_SYS_PATH/LoopbackEnable
		echo 1 > $HDMIRX_SYS_PATH/LoopbackEnable
	fi
}

load_videoip_c()
{
	# e_videoip_init_ok should be sent before calling astclent,
	# otherwise e_video_start_working may be fired before e_videoip_init_ok
	#ast_send_event -1 e_videoip_init_ok
	# astclient should wait for the videoip.ko initialized
	if [ "$MULTICAST_ON" = 'n' ]; then
		if [ "$UDP_ON" = 'n' ]; then
			astclient -0 $GWIP -d -s V2
		else
			astclient -0 $GWIP -m udp -d -s V2
		fi
	else
		if [ "$SEAMLESS_SWITCH" = 'y' ]; then
			astclient -0 $GWIP -m $MULTICAST_IP -d -s V2 -t no_tcp
		else
			astclient -0 $GWIP -m $MULTICAST_IP -d -s V2
		fi
	fi
}

start_kmoip_h()
{
	kmoip -m $MULTICAST_IP
}

stop_kmoip_h()
{
	echo 0 0 > $VHUB_SYS_PATH/attach_kmoip
}

start_kmoip_c()
{
	kmoip -m $MULTICAST_IP -a $GWIP
}

stop_kmoip_c()
{
	echo 0 0 > $KMOIP_SYS_PATH/attach
}

start_i2s_h()
{
	load_i2s
	echo $A_ANALOG_IN_VOL > $I2S_SYS_PATH/analog_in_vol
	echo $A_ANALOG_OUT_VOL > $I2S_SYS_PATH/analog_out_vol
	# RctBug#2016111101. Even SOC_OP_MODE is 1, AST1520 still need to set io_select in order to work properly.
	if [ "$SOC_VER" != '1' ]; then
		echo `select_a_input` > $I2S_SYS_PATH/io_select
		#echo $A_IO_SELECT > $I2S_SYS_PATH/io_select
		if [ "$EN_AES" = 'y' ]; then
			echo 1 > $I2S_SYS_PATH/enable_aes_encryption 2>/dev/null
		else
			echo 0 > $I2S_SYS_PATH/enable_aes_encryption 2>/dev/null
		fi
	fi

	if [ -n "$MULTICAST_IP_I2S" ]; then
		_MULTICAST_IP=$MULTICAST_IP_I2S
	else
		_MULTICAST_IP=$MULTICAST_IP
	fi

	if [ "$MULTICAST_ON" = 'n' ]; then
		if [ "$UDP_ON" = 'n' ]; then
			host_i2s -t tcp &
		else
			host_i2s &
		fi
	else
		if [ "$SEAMLESS_SWITCH" = 'y' ]; then
			host_i2s -m $_MULTICAST_IP -t no_tcp &
		else
			host_i2s -m $_MULTICAST_IP &
		fi
	fi
	# Bruce131111. ToDo.
	# host_i2s in most of cases is a blocking call. And it will wait for
	# client's connection or even won't return under multicast mode.
	# There is a very small timing window when host_i2s's TCP server is
	# not ready yet, but we fired 'e_i2s_init_ok' event.
	# Right now, I narrow down the small timing window by fire 'e_i2s_init_ok'
	# event after 'host_i2s &'.
	ast_send_event -1 'e_i2s_init_ok'
}

stop_i2s_h()
{
	unload_i2s.sh
}

start_i2s_c()
{
	# BruceToDo. load_i2s is slow
	load_i2s
	# I2S_CLOCK_LOCK_MODE for SoC v2 client only.
	if [ "$SOC_VER" -ge 2 ]; then
		echo $I2S_CLOCK_LOCK_MODE > $I2S_SYS_PATH/clock_lock
	fi

	if [ -n "$CH_SELECT_I2S" ]; then
		_GWIP=$CH_SELECT_I2S
	else
		_GWIP=$GWIP
	fi
	
	if [ -n "$MULTICAST_IP_I2S" ]; then
		_MULTICAST_IP=$MULTICAST_IP_I2S
	else
		_MULTICAST_IP=$MULTICAST_IP
	fi
	
	if [ "$MULTICAST_ON" = 'n' ]; then
		if [ "$UDP_ON" = 'n' ]; then
			client_i2s -t tcp -a $_GWIP
		else
			client_i2s -a $_GWIP
		fi
	else
		if [ "$SEAMLESS_SWITCH" = 'y' ]; then
			client_i2s -m $_MULTICAST_IP -a $_GWIP -t no_tcp
		else
			client_i2s -m $_MULTICAST_IP -a $_GWIP
		fi
	fi
	# Only SoC >= V3 support client audio hybrid
	if [ "$SOC_OP_MODE" -ge '3' ]; then
		echo $A_IO_SELECT > $I2S_SYS_PATH/io_select
		echo $A_OUTPUT_DELAY > $I2S_SYS_PATH/tx_delay_ms
	fi
	echo $A_ANALOG_IN_VOL > $I2S_SYS_PATH/analog_in_vol
	echo $A_ANALOG_OUT_VOL > $I2S_SYS_PATH/analog_out_vol
	ast_send_event -1 'e_i2s_init_ok'
}

stop_i2s_c()
{
	#unload_i2s.sh
	# kill applications
	#pkill client_i2s 2>/dev/null

	# invoke rmmod with all arguments we got
	rmmod 1500_i2s 2>/dev/null

	# Remove stale nodes
	rm -f /dev/i2s 2>/dev/null
}


start_ir2_h()
{
	# BruceToDo. load_ir2.sh is slow
	load_ir2.sh
	if [ "$MULTICAST_ON" = 'n' ]; then
		if [ "$UDP_ON" = 'n' ]; then
			host_ir2 -t tcp
		else
			host_ir2
		fi
	else
		host_ir2 -m $MULTICAST_IP
	fi
}

stop_ir2_h()
{
	unload_ir2.sh
}

start_cec()
{
	echo "Start CEC"
	load_cec.sh
}

stop_cec()
{
	unload_cec.sh
}

start_ir2_c()
{
	# BruceToDo. load_ir2.sh is slow
	load_ir2.sh
	if [ "$MULTICAST_ON" = 'n' ]; then
		if [ "$UDP_ON" = 'n' ]; then
			client_ir2 -t tcp -a $GWIP
		else
			client_ir2 -a $GWIP
		fi
	else
		client_ir2 -m $MULTICAST_IP -a $GWIP
	fi
}

stop_ir2_c()
{
	unload_ir2.sh
}

start_ir_h()
{
	if [ "$SOC_OP_MODE" -ge '2' ]; then
		start_ir2_h
		return
	fi
	# BruceToDo. load_ir2.sh is slow
	if [ -f "IRoIP.ko" ]; then
	load_ir.sh
	host_ir
	else
		echo "SOC V1 platform IRoIP is not supported yet."
		ast_send_event -1 e_iroip_init_ok
	fi
}

stop_ir_h()
{
	if [ "$SOC_OP_MODE" -ge '2' ]; then
		stop_ir2_h
		return
	fi
	if [ -f "IRoIP.ko" ]; then
	unload_ir.sh
	else
		ast_send_event -1 e_iroip_stopped
	fi
}

start_ir_c()
{
	if [ "$SOC_OP_MODE" -ge '2' ]; then
		start_ir2_c
		return
	fi
	# BruceToDo. load_ir2.sh is slow
	if [ -f "IRoIP.ko" ]; then
	load_ir.sh
	client_ir -a $GWIP
	else
		echo "SOC V1 platform IRoIP is not supported yet."
		ast_send_event -1 e_iroip_init_ok
	fi
}

stop_ir_c()
{
	if [ "$SOC_OP_MODE" -ge '2' ]; then
		stop_ir2_c
		return
	fi
	if [ -f "IRoIP.ko" ]; then
	unload_ir.sh
	else
		ast_send_event -1 e_iroip_stopped
	fi
}

# $1 set as 1 will trun off shrink feature
# $1 set as 2 will trun on shrink feature using 2:1
video_shrink_set()
{
	echo "$1" > "$VIDEO_SYS_PATH"/Hor_Scale
	echo "video shrink to $1"
}

video_shrink_is_on()
{
	local _t
	_t=`cat "$VIDEO_SYS_PATH"/Hor_Scale`
	if [ "$_t" = '2' ]; then
		# yes we are in shrink mode
		return 0
	fi
	return 1
}

video_quality_set()
{
	# Range from -1 to 3. -1 means auto
	echo "video quality mode set to $1"
	echo "$1" > "$VIDEO_SYS_PATH"/QualityMode
}

inform_gui()
{
	if [ "$HAS_GUI" = 'y' ]; then
		# Bruce171018.
		# gui_action may be called several times in a single handler.
		# for example: switch_to_decode_screen() clears osd_pic then recover osd_pic.
		# so, we should wait in order to keep code flow in sequence.

		#echo "$1" > "$PIPE_INFO_LOCAL"
		{ printf "%s" "$1"; } > "$PIPE_INFO_LOCAL" &
		wait ${!}
	fi
}

inform_gui_echo()
{
	inform_gui "$1"
	echo "$1"
}

gui_action()
{
	if [ "$HAS_GUI" = 'y' ]; then
		# Bruce171018.
		# gui_action may be called several times in a single handler.
		# for example: switch_to_decode_screen() clears osd_pic then recover osd_pic.
		# so, we should wait in order to keep code flow in sequence.
		{ printf "$1\0"; } > "$PIPE_INFO_GUI_ACTION" &
		wait ${!}
	fi
}

inform_gui_ui_feature_action()
{
	if [ "$UI_FEATURE" = 'y' ]; then
		gui_action "$1"
	fi
	#echo "$1"
}

inform_gui_action()
{
	gui_action "$1"
}

pc_is_off()
{
	if [ "$FPGA_TEST" = '1' ]; then
		return 0
	fi


	local pc_stat
	echo 0 > "$GPIO_SYS_PATH"/pc_pwr_stat/brightness 2>/dev/null
	pc_stat=`cat "$GPIO_SYS_PATH"/pc_pwr_stat/brightness 2>/dev/null`
	if [ "$pc_stat" = '0' ]; then
		#yes pc is power off
		return 0
	fi
	return 1
}

monitor_pc_stat()
{
	while pc_is_off; do
		while pc_is_off; do
			sleep 1
		done
		sleep 1
	done
	echo "PC powered up!"
	ast_send_event "$EM_PID" "e_button_link"
}

post_ip_addr()
{
	case "$MY_IP" in
		Unknown)
			return 0
		;;
		e_ip_got*)
			# We already got the IP address, send it again.
			ast_send_event -1 "$MY_IP"
		;;
		*)
			ast_send_event -1 "e_ip_got::$MY_IP"
		;;
	esac
	return 0

#	if [ "$MY_IP" = 'Unknown' ]; then
#		return 0
#	fi
#	# We already got the IP address, send it again.
#	if echo "$MY_IP" | grep "e_ip_got" ; then
#		ast_send_event -1 "$MY_IP"
#	else
#		ast_send_event -1 "e_ip_got::$MY_IP"
#	fi
#	# Do it again in case GUI didn't receive it.
#	#sleep 3
#	#ast_send_event -1 "e_ip_got::$ipaddr"
}

config_netmask_n_gw()
{
	ifconfig eth0:stat netmask "$NETMASK"
	route add default gw "$GATEWAYIP"
}

config_ip_addr()
{
	var="$1"

	MY_IP='Unknown'
	echo "IP_MODE=$IP_MODE"
	if [ "$IP_MODE" = 'autoip' ]; then
		ipaddr=`astparam g asthostip`
		if [ "$ipaddr" = "\"asthostip\" not defined" ]; then
			/sbin/avahi-autoipd -D --force-bind eth0 --script=/etc/avahi/avahi-autoipd.action
		else
			/sbin/avahi-autoipd -D --force-bind --start=$ipaddr eth0 --script=/etc/avahi/avahi-autoipd.action
		fi
	elif [ "$IP_MODE" = 'dhcp' ]; then
		#turn on udhcp will stop autoip from setting ip. Use -w in autoipd if you want to turn on udhcpc
		udhcpc -n &
	elif [ "$IP_MODE" = 'static' ]; then
		ifconfig eth0:stat "$IPADDR"
		config_netmask_n_gw
		MY_IP="$IPADDR"
	fi

}

# Used by "button_handler_c.sh"
multicast_ip_from_ch_select()
{
	local _c
	if [ -n "$1" ]; then
		_c="$1"
	else
		_c="$CH_SELECT"
	fi

	ch0=`expr "$_c" : '\(.\)...'`
	ch1=`expr "$_c" : '.\(.\)..'`
	ch2=`expr "$_c" : '..\(.\).'`
	ch3=`expr "$_c" : '...\(.\)'`

	echo "${MULTICAST_IP_PREFIX}$ch0.$ch1$ch2$ch3"
}

# 0.06 seconds
#multicast_ip_from_dipswitch()
#{
#	#Query the gpio value by writing 0 to it
#	echo 0 > ${GPIO_SYS_PATH}/ch0/brightness 2>/dev/null
#	echo 0 > ${GPIO_SYS_PATH}/ch1/brightness 2>/dev/null
#	echo 0 > ${GPIO_SYS_PATH}/ch2/brightness 2>/dev/null
#	echo 0 > ${GPIO_SYS_PATH}/ch3/brightness 2>/dev/null
#	#Get the value now
#	ch0=`cat ${GPIO_SYS_PATH}/ch0/brightness 2>/dev/null`
#	ch1=`cat ${GPIO_SYS_PATH}/ch1/brightness 2>/dev/null`
#	ch2=`cat ${GPIO_SYS_PATH}/ch2/brightness 2>/dev/null`
#	ch3=`cat ${GPIO_SYS_PATH}/ch3/brightness 2>/dev/null`
#
#	echo "${MULTICAST_IP_PREFIX}$ch0.$ch1$ch2$ch3"
#}

# 0.06 seconds. sysfs read takes time
refresh_4bits_ch()
{
	if [ "$FPGA_TEST" = '1' ]; then
		CH0='0'
		CH1='0'
		CH2='0'
		CH3='0'
		return
	fi

	#Query the gpio value by writing 0 to it
	echo ${_CHSLGP0INV} > ${GPIO_SYS_PATH}/ch0/brightness 2>/dev/null
	echo ${_CHSLGP1INV} > ${GPIO_SYS_PATH}/ch1/brightness 2>/dev/null
	echo ${_CHSLGP2INV} > ${GPIO_SYS_PATH}/ch2/brightness 2>/dev/null
	echo ${_CHSLGP3INV} > ${GPIO_SYS_PATH}/ch3/brightness 2>/dev/null
	#Get the value now
	CH0=`cat ${GPIO_SYS_PATH}/${_CHSLGP0}/brightness 2>/dev/null`
	CH1=`cat ${GPIO_SYS_PATH}/${_CHSLGP1}/brightness 2>/dev/null`
	CH2=`cat ${GPIO_SYS_PATH}/${_CHSLGP2}/brightness 2>/dev/null`
	CH3=`cat ${GPIO_SYS_PATH}/${_CHSLGP3}/brightness 2>/dev/null`
}

# 0.16 s
refresh_ch_params()
{
	MULTICAST_IP=`astparam g multicast_ip`
	case "$MULTICAST_IP" in
		*'not defined')
			MULTICAST_IP=`astparam r multicast_ip`
			case "$MULTICAST_IP" in
				*'not defined')
					#MULTICAST_IP=`multicast_ip_from_dipswitch`
					MULTICAST_IP="${MULTICAST_IP_PREFIX}${CH0}.${CH1}${CH2}${CH3}"
				;;
				*)
				;;
			esac
		;;
		*)
		;;
	esac

	CH_SELECT=`astparam g ch_select`
	case "$CH_SELECT" in
		*'not defined')
			CH_SELECT=`astparam r ch_select`
			case "$CH_SELECT" in
				*'not defined')
					#CH_SELECT=`astconfig channel`
					CH_SELECT="${CH0}${CH1}${CH2}${CH3}"
				;;
				*)
				;;
			esac
		;;
		*)
		;;
	esac

	if [ "$IS_HOST" = 'n' ]; then
		# calculate THE_ROW_ID
		#_b3=`expr "$CH_SELECT" : '\(.\)...'`
		#_b2=`expr "$CH_SELECT" : '.\(.\)..'`
		#_b1=`expr "$CH_SELECT" : '..\(.\).'`
		#_b0=`expr "$CH_SELECT" : '...\(.\)'`
		#MY_ROW_ID=`expr $CH0 \* 8 + $CH1 \* 4 + $CH2 \* 2 + $CH3`
		MY_ROW_ID=$(( $CH0 * 8 + $CH1 * 4 + $CH2 * 2 + $CH3 ))
		THE_ROW_ID="$MY_ROW_ID"
		echo "MY_ROW_ID=$MY_ROW_ID"
	fi
	echo "CH_SELECT=$CH_SELECT"
	echo "MULTICAST_IP=$MULTICAST_IP"
}

refresh_hostname_params()
{
	echo "Refresh hostname params"
	HOSTNAMEBYDIPSWITCH=`astparam g hostnamebydipswitch`
	case "$HOSTNAMEBYDIPSWITCH" in
		*'not defined')
			HOSTNAMEBYDIPSWITCH=`astparam r hostnamebydipswitch`
			case "$HOSTNAMEBYDIPSWITCH" in
				*'not defined')
					if [ "$IS_HOST" = 'n' ]; then
						HOSTNAMEBYDIPSWITCH='n'
						# USB only solution doesn't have button (for mfg mode) or 
						# even dip switch, which is difficult to connect 
						# to it's web page to update FW.
						# For USB only solution to easily connect to the web page, 
						# we use 4-bits dip switch as hostname_id.
						if [ "$SCENARIO" = 'usb_only' ] && [ "$MULTICAST_ON" = 'n' ]; then
							HOSTNAMEBYDIPSWITCH='y'
						fi
					else
						HOSTNAMEBYDIPSWITCH='y'
					fi
				;;
				*)
				;;
			esac
		;;
		*)
		;;
	esac

	HOSTNAME_ID=`astparam g hostname_id`
	case "$HOSTNAME_ID" in
		*'not defined')
			HOSTNAME_ID=`astparam r hostname_id`
			case "$HOSTNAME_ID" in
				*'not defined')
					if [ "$HOSTNAMEBYDIPSWITCH" = 'y' ]; then
						#HOSTNAME_ID=`astconfig channel`
						HOSTNAME_ID="${CH0}${CH1}${CH2}${CH3}"
					else
						# BruceToDo. 'astconfig mac' is slow
						HOSTNAME_ID=`astconfig mac`
					fi
				;;
				*)
				;;
			esac
		;;
		*)
		;;
	esac

	if [ "$IS_HOST" = 'y' ]; then
		# calculate THE_ROW_ID
		#_b3=`expr "$HOSTNAME_ID" : '\(.\)...'`
		#_b2=`expr "$HOSTNAME_ID" : '.\(.\)..'`
		#_b1=`expr "$HOSTNAME_ID" : '..\(.\).'`
		#_b0=`expr "$HOSTNAME_ID" : '...\(.\)'`
		#MY_ROW_ID=`expr $_b3 \* 8 + $_b2 \* 4 + $_b1 \* 2 + $_b0`
		#MY_ROW_ID=`expr $CH0 \* 8 + $CH1 \* 4 + $CH2 \* 2 + $CH3`
		MY_ROW_ID=$(( $CH0 * 8 + $CH1 * 4 + $CH2 * 2 + $CH3 ))
		#THE_ROW_ID="$MY_ROW_ID" in host side the row id should be VW_VAR_POS_IDX
		echo "MY_ROW_ID=$MY_ROW_ID"
	fi
	# BruceToDo. 'astconfig mac' may be slow. Check it.
	MY_MAC=`astconfig mac`
	echo "HOSTNAME_ID=$HOSTNAME_ID"
	echo "MY_MAC=$MY_MAC"
}

# 0.02 s
resolve_host_ip_by_name()
{
	# The $CH_SELECT should always be valid at this stage.
	case "$CH_SELECT" in
		?*.?*.?*.?*)
			#if there's a dot ".", it's definitely ip address, no name resolution needed
			gwip=$CH_SELECT
			# If failed to ping the host, just return 'unknown host'.
			if ! { ping "$gwip" | grep -q " is alive!"; }; then
				gwip="Unknown host"
			fi
		;;
		*)
			#no dot ".", assume hostname
			# reload avahi-daemon to clear the mDNS cache #Move to get_remote_ip state.
			#avahi-daemon -k
			#avahi-daemon -D
			gwname="${HOSTNAME_PREFIX}-gateway${CH_SELECT}.local"
			gwip=`astresname $gwname`
		;;
	esac

#	# The $CH_SELECT should always be valid at this stage.
#	if echo "$CH_SELECT" | grep -q "\." ; then
#		#if there's a dot ".", it's definitely ip address, no name resolution needed
#		gwip=$CH_SELECT
#		# If failed to ping the host, just return 'unknown host'.
#		if ! { ping "$gwip" | grep -q " is alive!"; }; then
#			gwip="Unknown host"
#		fi
#	else
#		#no dot ".", assume hostname
#		# reload avahi-daemon to clear the mDNS cache #Move to get_remote_ip state.
#		#avahi-daemon -k
#		#avahi-daemon -D
#		gwname="${HOSTNAME_PREFIX}-gateway${CH_SELECT}.local"
#		gwip=`astresname $gwname`
#	fi

	echo "$gwip"
}

get_host_ip_addr()
{
	## fixed mode is intened to be used in private point-to-point environment, so don't need to resolve by name. ##
	if [ "$IP_MODE" != 'fix' ]; then
		echo `resolve_host_ip_by_name`
	else
		#Query the gpio value by writing 0 to it
		#echo 0 > ${GPIO_SYS_PATH}/ch0/brightness 2>/dev/null
		#echo 0 > ${GPIO_SYS_PATH}/ch1/brightness 2>/dev/null
		#echo 0 > ${GPIO_SYS_PATH}/ch2/brightness 2>/dev/null
		#echo 0 > ${GPIO_SYS_PATH}/ch3/brightness 2>/dev/null
		#Get the value now
		#ch0=`cat ${GPIO_SYS_PATH}/ch0/brightness 2>/dev/null`
		#ch1=`cat ${GPIO_SYS_PATH}/ch1/brightness 2>/dev/null`
		#ch2=`cat ${GPIO_SYS_PATH}/ch2/brightness 2>/dev/null`
		#ch3=`cat ${GPIO_SYS_PATH}/ch3/brightness 2>/dev/null`

		gwip="169.254.2${CH0}.${CH1}${CH2}${CH3}"
		# If failed to ping the host, just return 'unknown host'.
		if ! { ping "$gwip" | grep -q " is alive!"; }; then
			echo "Unknown host"
		else
			echo "$gwip"
		fi
	fi
}

load_coip_c()
{
	coip -c -d $GWIP
}

unload_coip_c()
{
	echo "stop coip"
	# do nothing. CRT driver will disable HW cursor on socket disconnected.
}

load_soip_c()
{
	if [ "$SOIP_TYPE2" = 'y' ]; then
		if [ "$SOIP_GUEST_ON" = 'y' ]; then
			soip2 -h -f /dev/ttyS0 -b $S0_BAUDRATE -o $SOIP_TYPE2_TOKEN_TIMEOUT
		else
			if [ -n "$CH_SELECT_SOIP2" ]; then
				_GWIP=$CH_SELECT_SOIP2
			else
				_GWIP=$GWIP
			fi
			soip2 -c -f /dev/ttyS0 -d $_GWIP -b $S0_BAUDRATE
		fi
	else
		soip -c -d /dev/ttyS0
	fi
}

unload_soip_c()
{
	if [ "$SOIP_TYPE2" = 'y' ]; then
		pkill soip2 2>/dev/null
	else
		pkill soip 2>/dev/null
	fi
}

load_soip_h()
{
	if [ "$SOIP_TYPE2" = 'y' ]; then
		soip2 -h -f /dev/ttyS0 -b $S0_BAUDRATE -o $SOIP_TYPE2_TOKEN_TIMEOUT
	else
		if [ "$SOIP_GUEST_ON" = 'y' ]; then
			soip -c -d /dev/ttyS0
		else
			soip -h -d /dev/ttyS0 -b $S0_BAUDRATE -p "$HOSTNAME_PREFIX"
		fi
	fi
}

unload_soip_h()
{
	if [ "$SOIP_TYPE2" = 'y' ]; then
		pkill soip2 2>/dev/null
	else
		pkill soip 2>/dev/null
	fi
}

init_video_wall_params_v2()
{
	VW_VAR_V2_X1=`astparam g vw_v2_x1`
	if echo "$VW_VAR_V2_X1" | grep -q "not defined" ; then
		VW_VAR_V2_X1=`astparam r vw_v2_x1`
		if echo "$VW_VAR_V2_X1" | grep -q "not defined" ; then
			VW_VAR_V2_X1='0'
		fi
	fi

	VW_VAR_V2_Y1=`astparam g vw_v2_y1`
	if echo "$VW_VAR_V2_Y1" | grep -q "not defined" ; then
		VW_VAR_V2_Y1=`astparam r vw_v2_y1`
		if echo "$VW_VAR_V2_Y1" | grep -q "not defined" ; then
			VW_VAR_V2_Y1='0'
		fi
	fi

	VW_VAR_V2_X2=`astparam g vw_v2_x2`
	if echo "$VW_VAR_V2_X2" | grep -q "not defined" ; then
		VW_VAR_V2_X2=`astparam r vw_v2_x2`
		if echo "$VW_VAR_V2_X2" | grep -q "not defined" ; then
			VW_VAR_V2_X2='10000'
		fi
	fi

	VW_VAR_V2_Y2=`astparam g vw_v2_y2`
	if echo "$VW_VAR_V2_Y2" | grep -q "not defined" ; then
		VW_VAR_V2_Y2=`astparam r vw_v2_y2`
		if echo "$VW_VAR_V2_Y2" | grep -q "not defined" ; then
			VW_VAR_V2_Y2='10000'
		fi
	fi
}

video_wall_params_display_v2()
{
	echo "VW_VAR_VER=$VW_VAR_VER"
	echo "VW_VAR_V2_X1=$VW_VAR_V2_X1"
	echo "VW_VAR_V2_Y1=$VW_VAR_V2_Y1"
	echo "VW_VAR_V2_X2=$VW_VAR_V2_X2"
	echo "VW_VAR_V2_Y2=$VW_VAR_V2_Y2"
}

init_video_wall_params()
{
	# MY_ROW_ID must be ready before this call.

	VW_VAR_MAX_ROW=`astparam g vw_max_row`
	if echo "$VW_VAR_MAX_ROW" | grep -q "not defined" ; then
		VW_VAR_MAX_ROW=`astparam r vw_max_row`
		if echo "$VW_VAR_MAX_ROW" | grep -q "not defined" ; then
			VW_VAR_MAX_ROW='0'
		fi
	fi
	VW_VAR_MAX_COLUMN=`astparam g vw_max_column`
	if echo "$VW_VAR_MAX_COLUMN" | grep -q "not defined" ; then
		VW_VAR_MAX_COLUMN=`astparam r vw_max_column`
		if echo "$VW_VAR_MAX_COLUMN" | grep -q "not defined" ; then
			VW_VAR_MAX_COLUMN='0'
		fi
	fi
	VW_VAR_ROW=`astparam g vw_row`
	if echo "$VW_VAR_ROW" | grep -q "not defined" ; then
		VW_VAR_ROW=`astparam r vw_row`
		if echo "$VW_VAR_ROW" | grep -q "not defined" ; then
			VW_VAR_ROW="unknown"
		fi
	fi
	VW_VAR_COLUMN=`astparam g vw_column`
	if echo "$VW_VAR_COLUMN" | grep -q "not defined" ; then
		VW_VAR_COLUMN=`astparam r vw_column`
		if echo "$VW_VAR_COLUMN" | grep -q "not defined" ; then
			VW_VAR_COLUMN="0"
		fi
	fi
	VW_VAR_MONINFO_HA=`astparam g vw_moninfo_ha`
	if echo "$VW_VAR_MONINFO_HA" | grep -q "not defined" ; then
		VW_VAR_MONINFO_HA=`astparam r vw_moninfo_ha`
		if echo "$VW_VAR_MONINFO_HA" | grep -q "not defined" ; then
			VW_VAR_MONINFO_HA="1"
		fi
	fi
	VW_VAR_MONINFO_HT=`astparam g vw_moninfo_ht`
	if echo "$VW_VAR_MONINFO_HT" | grep -q "not defined" ; then
		VW_VAR_MONINFO_HT=`astparam r vw_moninfo_ht`
		if echo "$VW_VAR_MONINFO_HT" | grep -q "not defined" ; then
			VW_VAR_MONINFO_HT="1"
		fi
	fi
	VW_VAR_MONINFO_VA=`astparam g vw_moninfo_va`
	if echo "$VW_VAR_MONINFO_VA" | grep -q "not defined" ; then
		VW_VAR_MONINFO_VA=`astparam r vw_moninfo_va`
		if echo "$VW_VAR_MONINFO_VA" | grep -q "not defined" ; then
			VW_VAR_MONINFO_VA="1"
		fi
	fi
	VW_VAR_MONINFO_VT=`astparam g vw_moninfo_vt`
	if echo "$VW_VAR_MONINFO_VT" | grep -q "not defined" ; then
		VW_VAR_MONINFO_VT=`astparam r vw_moninfo_vt`
		if echo "$VW_VAR_MONINFO_VT" | grep -q "not defined" ; then
			VW_VAR_MONINFO_VT="1"
		fi
	fi
	VW_VAR_POS_IDX=`astparam g vw_pos_idx`
	if echo "$VW_VAR_POS_IDX" | grep -q "not defined" ; then
		VW_VAR_POS_IDX=`astparam r vw_pos_idx`
		if echo "$VW_VAR_POS_IDX" | grep -q "not defined" ; then
			VW_VAR_POS_IDX='unknown'
		fi
	fi
	VW_VAR_H_SHIFT=`astparam g vw_h_shift`
	if echo "$VW_VAR_H_SHIFT" | grep -q "not defined" ; then
		VW_VAR_H_SHIFT=`astparam r vw_h_shift`
		if echo "$VW_VAR_H_SHIFT" | grep -q "not defined" ; then
			VW_VAR_H_SHIFT='0'
		fi
	fi
	VW_VAR_V_SHIFT=`astparam g vw_v_shift`
	if echo "$VW_VAR_V_SHIFT" | grep -q "not defined" ; then
		VW_VAR_V_SHIFT=`astparam r vw_v_shift`
		if echo "$VW_VAR_V_SHIFT" | grep -q "not defined" ; then
			VW_VAR_V_SHIFT='0'
		fi
	fi
	VW_VAR_H_SCALE=`astparam g vw_h_scale`
	if echo "$VW_VAR_H_SCALE" | grep -q "not defined" ; then
		VW_VAR_H_SCALE=`astparam r vw_h_scale`
		if echo "$VW_VAR_H_SCALE" | grep -q "not defined" ; then
			VW_VAR_H_SCALE='0'
		fi
	fi
	VW_VAR_V_SCALE=`astparam g vw_v_scale`
	if echo "$VW_VAR_V_SCALE" | grep -q "not defined" ; then
		VW_VAR_V_SCALE=`astparam r vw_v_scale`
		if echo "$VW_VAR_V_SCALE" | grep -q "not defined" ; then
			VW_VAR_V_SCALE='0'
		fi
	fi
	VW_VAR_POS_MAX_ROW=`astparam g vw_pos_max_row`
	if echo "$VW_VAR_POS_MAX_ROW" | grep -q "not defined" ; then
		VW_VAR_POS_MAX_ROW=`astparam r vw_pos_max_row`
		if echo "$VW_VAR_POS_MAX_ROW" | grep -q "not defined" ; then
			VW_VAR_POS_MAX_ROW="$MY_ROW_ID"
		fi
	fi
	VW_VAR_POS_MAX_COL=`astparam g vw_pos_max_col`
	if echo "$VW_VAR_POS_MAX_COL" | grep -q "not defined" ; then
		VW_VAR_POS_MAX_COL=`astparam r vw_pos_max_col`
		if echo "$VW_VAR_POS_MAX_COL" | grep -q "not defined" ; then
			VW_VAR_POS_MAX_COL="$MY_ROW_ID"
		fi
	fi
	VW_VAR_DELAY_KICK=`astparam g vw_delay_kick`
	if echo "$VW_VAR_DELAY_KICK" | grep -q "not defined" ; then
		VW_VAR_DELAY_KICK=`astparam r vw_delay_kick`
		if echo "$VW_VAR_DELAY_KICK" | grep -q "not defined" ; then
			VW_VAR_DELAY_KICK='0'
		fi
	fi
	VW_VAR_TAIL_IDX=`astparam g vw_tail_idx`
	if echo "$VW_VAR_TAIL_IDX" | grep -q "not defined" ; then
		VW_VAR_TAIL_IDX=`astparam r vw_tail_idx`
		if echo "$VW_VAR_TAIL_IDX" | grep -q "not defined" ; then
			VW_VAR_TAIL_IDX='unknown'
		fi
	fi
	VW_VAR_STRETCH_TYPE=`astparam g vw_stretch_type`
	if echo "$VW_VAR_STRETCH_TYPE" | grep -q "not defined" ; then
		VW_VAR_STRETCH_TYPE=`astparam r vw_stretch_type`
		if echo "$VW_VAR_STRETCH_TYPE" | grep -q "not defined" ; then
			# 0:auto 1:Stretch out 2:Fit in
			VW_VAR_STRETCH_TYPE='2'
		fi
	fi
	VW_VAR_ROTATE=`astparam g vw_rotate`
	if echo "$VW_VAR_ROTATE" | grep -q "not defined" ; then
		VW_VAR_ROTATE=`astparam r vw_rotate`
		if echo "$VW_VAR_ROTATE" | grep -q "not defined" ; then
			# 5:90 3:180 6:270
			VW_VAR_ROTATE='0'
		fi
	fi

	#VW_VAR_LAYOUT=`expr $VW_VAR_MAX_ROW + 1`x`expr $VW_VAR_MAX_COLUMN + 1`
	VW_VAR_LAYOUT="$(( $VW_VAR_MAX_ROW + 1 ))x$(( $VW_VAR_MAX_COLUMN + 1 ))"

	if [ "$VW_VAR_ROW" = 'unknown' ]; then
		VW_VAR_ROW="$MY_ROW_ID"
	fi

	#Bug#2011090901. We should not mod VW_VAR_COLUMN. The driver can handle it.
	#VW_VAR_COLUMN=`expr $VW_VAR_COLUMN % \( $VW_VAR_MAX_COLUMN + 1 \)`

	if [ "$VW_VAR_POS_IDX" = 'unknown' ]; then
		if [ "$IS_HOST" = 'y' ]; then
			VW_VAR_POS_IDX="${MY_ROW_ID}"
		else
			VW_VAR_POS_IDX="r${VW_VAR_ROW}c${VW_VAR_COLUMN}"
		fi
	fi
	if [ "$IS_HOST" = 'y' ]; then
		VW_VAR_POS_R="$VW_VAR_POS_IDX"
		VW_VAR_POS_C="0"
		THE_ROW_ID="$VW_VAR_POS_IDX" #This flag will be the same as $VW_VAR_POS_R except the host box which is the controller.
	else
		_IFS="$IFS";IFS='rc';set -- $VW_VAR_POS_IDX;IFS="$_IFS"
		VW_VAR_POS_R="$2"
		VW_VAR_POS_C="$3"
		#VW_VAR_POS_R=`expr "$VW_VAR_POS_IDX" : 'r\([[:alnum:]]\{1,\}\)c[[:alnum:]]\{1,\}'`
		#VW_VAR_POS_C=`expr "$VW_VAR_POS_IDX" : 'r[[:alnum:]]\{1,\}c\([[:alnum:]]\{1,\}\)'`
	fi
	if [ "$VW_VAR_TAIL_IDX" = 'unknown' ]; then
		VW_VAR_TAIL_IDX="${VW_VAR_POS_R}"
	fi
	# In case of error
	if [ -z "$VW_VAR_POS_R" ]; then
		VW_VAR_POS_R="0"
	fi
	if [ -z "$VW_VAR_POS_C" ]; then
		VW_VAR_POS_C="0"
	fi
	VW_VAR_THE_MAX_ROW='0' #This is a temp value for host to save max row count
	
	if [ "$SOC_OP_MODE" -ge '3' ]; then
		VW_VAR_VER=`astparam g vw_ver`
		if echo "$VW_VAR_VER" | grep -q "not defined" ; then
			VW_VAR_VER=`astparam r vw_ver`
			if echo "$VW_VAR_VER" | grep -q "not defined" ; then
				VW_VAR_VER='1'
			fi
		fi
	else
		VW_VAR_VER='1'
	fi

	echo "VW_VAR_POS_IDX=$VW_VAR_POS_IDX"
	echo "VW_VAR_MAX_ROW=$VW_VAR_MAX_ROW"
	echo "VW_VAR_MAX_COLUMN=$VW_VAR_MAX_COLUMN"
	echo "VW_VAR_ROW=$VW_VAR_ROW"
	echo "VW_VAR_COLUMN=$VW_VAR_COLUMN"
	echo "VW_VAR_H_SHIFT=$VW_VAR_H_SHIFT"
	echo "VW_VAR_V_SHIFT=$VW_VAR_V_SHIFT"
	echo "VW_VAR_H_SCALE=$VW_VAR_H_SCALE"
	echo "VW_VAR_V_SCALE=$VW_VAR_V_SCALE"
	echo "VW_VAR_MONINFO_HA=$VW_VAR_MONINFO_HA"
	echo "VW_VAR_MONINFO_HT=$VW_VAR_MONINFO_HT"
	echo "VW_VAR_MONINFO_VA=$VW_VAR_MONINFO_VA"
	echo "VW_VAR_MONINFO_VT=$VW_VAR_MONINFO_VT"
	echo "VW_VAR_POS_MAX_ROW=$VW_VAR_POS_MAX_ROW"
	echo "VW_VAR_POS_MAX_COL=$VW_VAR_POS_MAX_COL"
	echo "VW_VAR_POS_R=$VW_VAR_POS_R"
	echo "VW_VAR_POS_C=$VW_VAR_POS_C"
	echo "VW_VAR_DELAY_KICK=$VW_VAR_DELAY_KICK"

	if [ "$VW_VAR_VER" = '2' ]; then
		init_video_wall_params_v2
		video_wall_params_display_v2
	fi
}

parse_usb_busid_map()
{
	## USB_BUSID_MAP='2-1 1-1,3-1 1-2,3-2 1-4,2-3 1-5,2-2 1-3'
	_IFS="$IFS";IFS=',';set -- $USB_BUSID_MAP;IFS="$_IFS"
	
	USB_P1_BUSID="$1"
	USB_P2_BUSID="$2"
	USB_P3_BUSID="$3"
	USB_P4_BUSID="$4"
	USB_P5_BUSID="$5"

	echo "USB_P1_BUSID=($USB_P1_BUSID)"
	echo "USB_P2_BUSID=($USB_P2_BUSID)"
	echo "USB_P3_BUSID=($USB_P3_BUSID)"
	echo "USB_P4_BUSID=($USB_P4_BUSID)"
	echo "USB_P5_BUSID=($USB_P5_BUSID)"
}


init_share_param_from_flash()
{
	DBG='0'
	CLIENT_LIST=''
	CLIENT_LIST_IDX='0'
	THE_CLIENT_IP=''
#	ANALOG_ONLY='n'
	MFG_MODE='Off'
	EDID_USE='primary'

	_p=`/usr/local/bin/io 0 1e6e207c`
	_IFS="$IFS";IFS=' ';set -- $_p;IFS="$_IFS"
	_p=$3
	case "$_p" in
		302)
		# AST1500
		SOC_VER='1'
		;;
		1000003 | 1010303 | 1010203 | 2010303)
			#1000003  AST1510 A0
			#1010303  AST1510 A1
			#1010203  AST1510 A1
			#2010303  AST1510 FPGA
		SOC_VER='2'
		;;
		2010003 | 4000003 | 4000303 | 4010303 | 4??1003)
			#2010003  AST1520 FPGA
			#4000003  AST1520 FPGA
			#4000303  AST1520 A0
			#4010303  AST2500 A1
			#4011003  AST1520 A1
			#4031003  AST1520 A2
		SOC_VER='3'
		;;
		*)
		echo "ERROR!!! Unknown SoC version? $_p"
		exit
		;;
	esac

	SOC_OP_MODE=`astparam g soc_op_mode`
	if echo "$SOC_OP_MODE" | grep -q "not defined" ; then
		SOC_OP_MODE=`astparam r soc_op_mode`
		if echo "$SOC_OP_MODE" | grep -q "not defined" ; then
			SOC_OP_MODE=$SOC_VER
		fi
	fi

	# fool-proof $SOC_OP_MODE setting
	case $SOC_OP_MODE in
		1)
			if [ "$SOC_VER" -lt 2 ]; then
				SOC_OP_MODE=$SOC_VER
			fi
		;;
		2)
			if [ "$SOC_VER" -lt 3 ]; then
				SOC_OP_MODE=$SOC_VER
			fi
		;;
		3)
			if [ "$SOC_VER" -lt 4 ]; then
				SOC_OP_MODE=$SOC_VER
			fi
		;;
		*)
			SOC_OP_MODE=$SOC_VER
		;;
	esac

	if echo "$AST_PLATFORM" | grep "c" ; then
		#Client code
		IS_HOST='n'
	else
		#Host code
		IS_HOST='y'
	fi

	if [ "$SOC_OP_MODE" -ge '2' ]; then
		IR_SYS_PATH="/sys/devices/platform/IRoIP2"
	fi
	
	# List of scenario: usb_only, pc2tv
	SCENARIO=`astparam g scenario`
	if echo "$SCENARIO" | grep -q "not defined" ; then
		SCENARIO=`astparam r scenario`
		if echo "$SCENARIO" | grep -q "not defined" ; then
			SCENARIO='pc2tv'
		fi
	fi

	SEAMLESS_SWITCH=`astparam g seamless_switch`
	if echo "$SEAMLESS_SWITCH" | grep -q "not defined" ; then
		SEAMLESS_SWITCH=`astparam r seamless_switch`
		if echo "$SEAMLESS_SWITCH" | grep -q "not defined" ; then
			SEAMLESS_SWITCH='n'
		fi
	fi

	EN_VIDEO_WALL=`astparam g en_video_wall`
	if echo "$EN_VIDEO_WALL" | grep -q "not defined" ; then
		EN_VIDEO_WALL=`astparam r en_video_wall`
		if echo "$EN_VIDEO_WALL" | grep -q "not defined" ; then
			EN_VIDEO_WALL='y'
		fi
	fi

	# AST1510(SoCv2 or SoCv3@soc_op_mode == 2) doesn't support video wall feature.
	if [ "$SOC_OP_MODE" = '2' ]; then
		EN_VIDEO_WALL='n'
	fi

	# Reset channel on boot first
	RESET_CH_ON_BOOT=`astparam g reset_ch_on_boot`
	if echo "$RESET_CH_ON_BOOT" | grep -q "not defined" ; then
		RESET_CH_ON_BOOT=`astparam r reset_ch_on_boot`
		if echo "$RESET_CH_ON_BOOT" | grep -q "not defined" ; then
			RESET_CH_ON_BOOT='y'
		fi
	fi
	if [ "$RESET_CH_ON_BOOT" = 'y' ]; then
		astparam s ch_select
		astparam s multicast_ip
		astparam s hostname_id
	fi

	NO_VIDEO=`astparam g no_video`
	if echo "$NO_VIDEO" | grep -q "not defined" ; then
		NO_VIDEO=`astparam r no_video`
		if echo "$NO_VIDEO" | grep -q "not defined" ; then
			if [ "$SCENARIO" = 'usb_only' ]; then
				NO_VIDEO='y'
			else
				NO_VIDEO='n'
			fi
		fi
	fi

	V_DUAL_PORT=`astparam g v_dual_port`
	if echo "$V_DUAL_PORT" | grep -q "not defined" ; then
		V_DUAL_PORT=`astparam r v_dual_port`
		if echo "$V_DUAL_PORT" | grep -q "not defined" ; then
			case $SOC_OP_MODE in
				3)
					if [ "$IS_HOST" = 'y' ]; then
			V_DUAL_PORT='0'
					else
						V_DUAL_PORT='1'
					fi
				;;
				*)
					V_DUAL_PORT='0'
				;;
			esac
		fi
	fi

	V_ENG_DRV_OPTION=`astparam g v_eng_drv_option`
	if echo "$V_ENG_DRV_OPTION" | grep -q "not defined" ; then
		V_ENG_DRV_OPTION=`astparam r v_eng_drv_option`
		if echo "$V_ENG_DRV_OPTION" | grep -q "not defined" ; then
			case $SOC_VER in
				*)
			V_ENG_DRV_OPTION='0'
				;;
			esac
		fi
	fi

	V_GEN_LOCK_CFG=`astparam g v_gen_lock_cfg`
	if echo "$V_GEN_LOCK_CFG=" | grep -q "not defined" ; then
		V_GEN_LOCK_CFG=`astparam r v_gen_lock_cfg`
		if echo "$V_GEN_LOCK_CFG" | grep -q "not defined" ; then
			case $SOC_OP_MODE in
				3)
					# gen_lock_cfg[31:24]: location
					#      the location user prefer to lock at (in percetage)
					# gen_lock_cfg[22:8] ppm limit
					#      acceptable PPM variation of monitor
					# gen_lock_cfg[7:4] factor
					#      number of swith between host and client
					# gen_lock_cfg[3]: ppm limit 4k patch:
					#      use 10% ppm limit for 4K resolution
					# gen_lock_cfg[2]: ppm strict mode:
					#      limit PPM even if in JUMP state
					# gen_lock_cfg[0]: enable:
					#      enable/disable gen-lock
					V_GEN_LOCK_CFG='55028aa9'
				;;
				*)
					V_GEN_LOCK_CFG='0'
				;;
			esac
		fi
	fi

	NO_USB=`astparam g no_usb`
	if echo "$NO_USB" | grep -q "not defined" ; then
		NO_USB=`astparam r no_usb`
		if echo "$NO_USB" | grep -q "not defined" ; then
			NO_USB='n'
		fi
	fi

	NO_KMOIP=`astparam g no_kmoip`
	if echo "$NO_KMOIP" | grep -q "not defined" ; then
		NO_KMOIP=`astparam r no_kmoip`
		if echo "$NO_KMOIP" | grep -q "not defined" ; then
			NO_KMOIP='n'
		fi
	fi

	USB_BUSID_MAP=`astparam g usb_busid_map`
	if echo "$USB_BUSID_MAP" | grep -q "not defined" ; then
		USB_BUSID_MAP=`astparam r usb_busid_map`
		if echo "$USB_BUSID_MAP" | grep -q "not defined" ; then
			case $SOC_VER in
				1) # default for AST1500 NEC 5 ports
					USB_BUSID_MAP='2-1 1-1,3-1 1-2,3-2 1-4,2-3 1-5,2-2 1-3'
				;;
				2) # for AST1510
					USB_BUSID_MAP='1-1,3-1 2-1,3-2 2-2,3-3 2-3'
				;;
				3) # for AST1520
					USB_BUSID_MAP='3-3,3-4,3-1 1-1,3-2 2-1'
				;;
				*)
					USB_BUSID_MAP='2-1 1-1,3-1 1-2,3-2 1-4,2-3 1-5,2-2 1-3'
				;;
			esac
		fi
	fi
	parse_usb_busid_map

	KMOIP_PORTS=`astparam g kmoip_ports`
	if echo "$KMOIP_PORTS" | grep -q "not defined" ; then
		KMOIP_PORTS=`astparam r kmoip_ports`
		if echo "$KMOIP_PORTS" | grep -q "not defined" ; then
			# default export all ports. Valid options example: '1 3'
			#KMOIP_PORTS='all'
			KMOIP_PORTS='1 2'
		fi
	fi

	KMOIP_HOTKEYS=`astparam g kmoip_hotkeys`
	if echo "$KMOIP_HOTKEYS" | grep -q "not defined" ; then
		KMOIP_HOTKEYS=`astparam r kmoip_hotkeys`
		if echo "$KMOIP_HOTKEYS" | grep -q "not defined" ; then
			# Default:
			# hotkey 0: scroll lock
			# hotkey 1: pause/break
			# hotkey 2: insert
			KMOIP_HOTKEYS='00 47 00 48 00 49 00 00 00 00 00 00 00 00 00 00'
		fi
	fi

	KMOIP_TOKEN_INTERVAL=`astparam g kmoip_token_interval`
	if echo "$KMOIP_TOKEN_INTERVAL" | grep -q "not defined" ; then
		KMOIP_TOKEN_INTERVAL=`astparam r kmoip_token_interval`
		if echo "$KMOIP_TOKEN_INTERVAL" | grep -q "not defined" ; then
			# default 100 ms
			KMOIP_TOKEN_INTERVAL=100
		fi
	fi

	USB_FAST_SWITCH=`astparam g usb_fast_switch`
	if echo "$USB_FAST_SWITCH" | grep -q "not defined" ; then
		USB_FAST_SWITCH=`astparam r usb_fast_switch`
		if echo "$USB_FAST_SWITCH" | grep -q "not defined" ; then
			USB_FAST_SWITCH='n'
		fi
	fi

	NO_I2S=`astparam g no_i2s`
	if echo "$NO_I2S" | grep -q "not defined" ; then
		NO_I2S=`astparam r no_i2s`
		if echo "$NO_I2S" | grep -q "not defined" ; then
			if [ "$SCENARIO" = 'usb_only' ]; then
				NO_I2S='y'
			else
				NO_I2S='n'
			fi
		fi
	fi

	ACCESS_ON=`astparam g astaccess`
	if echo "$ACCESS_ON" | grep -q "not defined" ; then
		ACCESS_ON=`astparam r astaccess`
		if echo "$ACCESS_ON" | grep -q "not defined" ; then
			ACCESS_ON='y'
		fi
	fi
	# Are we going to use Multicast mode?
	MULTICAST_ON=`astparam g multicast_on`
	if echo "$MULTICAST_ON" | grep -q "not defined" ; then
		MULTICAST_ON=`astparam r multicast_on`
		if echo "$MULTICAST_ON" | grep -q "not defined" ; then
			MULTICAST_ON='n'
		fi
	fi
	# Read after MULTICAST_ON
	EDID_USE=`astparam g edid_use`
	if echo "$EDID_USE" | grep -q "not defined" ; then
		EDID_USE=`astparam r edid_use`
		if echo "$EDID_USE" | grep -q "not defined" ; then
			if [ "$MULTICAST_ON" = 'y' ]; then
				EDID_USE='secondary'
			else
				EDID_USE='primary'
			fi
		fi
	fi

	# Are we going to use UDP for unicast mode?
	UDP_ON=`astparam g udp_on`
	if echo "$UDP_ON" | grep -q "not defined" ; then
		UDP_ON=`astparam r udp_on`
		if echo "$UDP_ON" | grep -q "not defined" ; then
			UDP_ON='y'
		fi
	fi
	# selections: fix, static, dhcp, autoip
	# fix: use 169.254.xxx.xxx without mDNS feature
	# static: use ip setting from flash (asthostip).
	# dhcp: use dhcp client
	# autoip: use 169.254.xxx.xxx with mDNS feature
	IP_MODE=`astparam g ip_mode`
	if echo "$IP_MODE" | grep -q "not defined" ; then
		IP_MODE=`astparam r ip_mode`
		if echo "$IP_MODE" | grep -q "not defined" ; then
			IP_MODE='autoip'
		fi
	fi
	# Are we going to use Serial over IP ?
	NO_SOIP=`astparam g no_soip`
	if echo "$NO_SOIP" | grep -q "not defined" ; then
		NO_SOIP=`astparam r no_soip`
		if echo "$NO_SOIP" | grep -q "not defined" ; then
			NO_SOIP='y'
		fi
	fi

	SOIP_TYPE2=`astparam g soip_type2`
	if echo "$SOIP_TYPE2" | grep -q "not defined" ; then
		SOIP_TYPE2=`astparam r soip_type2`
		if echo "$SOIP_TYPE2" | grep -q "not defined" ; then
			SOIP_TYPE2='y'
		fi
	fi

	SOIP_GUEST_ON=`astparam g soip_guest_on`
	if echo "$SOIP_GUEST_ON" | grep -q "not defined" ; then
		SOIP_GUEST_ON=`astparam r soip_guest_on`
		if echo "$SOIP_GUEST_ON" | grep -q "not defined" ; then
			SOIP_GUEST_ON='n'
		fi
	fi

	S0_BAUDRATE=`astparam g s0_baudrate`
	if echo "$S0_BAUDRATE" | grep -q "not defined" ; then
		S0_BAUDRATE=`astparam r s0_baudrate`
		if echo "$S0_BAUDRATE" | grep -q "not defined" ; then
			S0_BAUDRATE='115200-8n1'
		fi
	fi

	if [ "$SOIP_TYPE2" = 'y' ]; then
		SOIP_TYPE2_TOKEN_TIMEOUT=`astparam g soip_type2_token_timeout`
		if echo "$SOIP_TYPE2_TOKEN_TIMEOUT" | grep -q "not defined" ; then
			SOIP_TYPE2_TOKEN_TIMEOUT=`astparam r soip_type2_token_timeout`
			if echo "$SOIP_TYPE2_TOKEN_TIMEOUT" | grep -q "not defined" ; then
				SOIP_TYPE2_TOKEN_TIMEOUT='1'
			fi
		fi
		CH_SELECT_SOIP2=`astparam g ch_select_soip2`
		if echo "$CH_SELECT_SOIP2" | grep -q "not defined" ; then
			CH_SELECT_SOIP2=`astparam r ch_select_soip2`
			if echo "$CH_SELECT_SOIP2" | grep -q "not defined" ; then
				CH_SELECT_SOIP2=''
			fi
		fi
	fi

	PROFILE=`astparam g profile`
	if echo "$PROFILE" | grep -q "not defined" ; then
		PROFILE=`astparam r profile`
		if echo "$PROFILE" | grep -q "not defined" ; then
			PROFILE='auto'
		fi
	fi

	SHARE_USB_AUTO_MODE=`astparam g share_usb_auto_mode`
	if echo "$SHARE_USB_AUTO_MODE" | grep -q "not defined" ; then
		SHARE_USB_AUTO_MODE=`astparam r share_usb_auto_mode`
		if echo "$SHARE_USB_AUTO_MODE" | grep -q "not defined" ; then
			SHARE_USB_AUTO_MODE='n'
		fi
	fi

	# MULTICAST_ON MUST be available here
	if [ "$SHARE_USB_AUTO_MODE" = 'y' ]; then
		if [ "$MULTICAST_ON" = 'y' ]; then
			SHARE_USB='y'
		else
			SHARE_USB='n'
		fi
	else
		SHARE_USB=`astparam g share_usb`
		if echo "$SHARE_USB" | grep -q "not defined" ; then
			SHARE_USB=`astparam r share_usb`
			if echo "$SHARE_USB" | grep -q "not defined" ; then
				SHARE_USB='n'
			fi
		fi
	fi

	SHARE_USB_ON_FIRST_PEER=`astparam g share_usb_on_first_peer`
	if echo "$SHARE_USB_ON_FIRST_PEER" | grep -q "not defined" ; then
		SHARE_USB_ON_FIRST_PEER=`astparam r share_usb_on_first_peer`
		if echo "$SHARE_USB_ON_FIRST_PEER" | grep -q "not defined" ; then
			SHARE_USB_ON_FIRST_PEER='y'
		fi
	fi

	NO_IR=`astparam g no_ir`
	if echo "$NO_IR" | grep -q "not defined" ; then
		NO_IR=`astparam r no_ir`
		if echo "$NO_IR" | grep -q "not defined" ; then
			if [ "$SCENARIO" = 'usb_only' ]; then
				NO_IR='y'
			else
				NO_IR='n'
			fi
		fi
	fi


	CEC_GUEST_MODE=`astparam g cec_guest_mode`
	if echo "$CEC_GUEST_MODE" | grep -q "not defined" ; then
		CEC_GUEST_MODE=`astparam r cec_guest_mode`
		if echo "$CEC_GUEST_MODE" | grep -q "not defined" ; then
			CEC_GUEST_MODE='n'
		fi
	fi	

	# Used for remote PC power on/off
	NO_PWRBTN=`astparam g no_pwrbtn`
	if echo "$NO_PWRBTN" | grep -q "not defined" ; then
		NO_PWRBTN=`astparam r no_pwrbtn`
		if echo "$NO_PWRBTN" | grep -q "not defined" ; then
			NO_PWRBTN='y'
		fi
	fi

	V_QUALITY_MODE=`astparam g ast_video_quality_mode`
	if echo "$V_QUALITY_MODE" | grep -q "not defined" ; then
		V_QUALITY_MODE=`astparam r ast_video_quality_mode`
		if echo "$V_QUALITY_MODE" | grep -q "not defined" ; then
			# default auto (-1)
			V_QUALITY_MODE='-1'
		fi
	fi

	V_DBG_MODE=`astparam g v_dbg_mode`
	if echo "$V_DBG_MODE" | grep -q "not defined" ; then
		V_DBG_MODE=`astparam r v_dbg_mode`
		if echo "$V_DBG_MODE" | grep -q "not defined" ; then
			V_DBG_MODE='0'
		fi
	fi

	IPADDR=`astparam g ipaddr`
	if echo "$IPADDR" | grep -q "not defined" ; then
		IPADDR=`astparam r ipaddr`
		if echo "$IPADDR" | grep -q "not defined" ; then
			if [ "$IS_HOST" = 'n' ]; then
				#Client code
				IPADDR="169.254.0.111"
			else
				#Host code
				IPADDR="169.254.0.222"
			fi
		fi
	fi

	NETMASK=`astparam g netmask`
	if echo "$NETMASK" | grep -q "not defined" ; then
		NETMASK=`astparam r netmask`
		if echo "$NETMASK" | grep -q "not defined" ; then
			NETMASK='255.255.0.0'
		fi
	fi

	GATEWAYIP=`astparam g gatewayip`
	if echo "$GATEWAYIP" | grep -q "not defined" ; then
		GATEWAYIP=`astparam r gatewayip`
		if echo "$GATEWAYIP" | grep -q "not defined" ; then
			GATEWAYIP='169.254.0.254'
		fi
	fi

	V_BCD_THRESHOLD=`astparam g v_bcd_threshold`
	if echo "$V_BCD_THRESHOLD" | grep -q "not defined" ; then
		V_BCD_THRESHOLD=`astparam r v_bcd_threshold`
		if echo "$V_BCD_THRESHOLD" | grep -q "not defined" ; then
			if [ "$SOC_VER" != '1' ]; then
				#V_BCD_THRESHOLD='1' Resolve RctBug#2012071200
				V_BCD_THRESHOLD='0'
			else
				V_BCD_THRESHOLD='0'
			fi
		fi
	fi

	UI_FEATURE=`astparam g ui_feature`
	if echo "$UI_FEATURE" | grep -q "not defined" ; then
		UI_FEATURE=`astparam r ui_feature`
		if echo "$UI_FEATURE" | grep -q "not defined" ; then
			UI_FEATURE='n'
		fi
	fi

	UI_OPTION=`astparam g ui_option`
	if echo "$UI_OPTION" | grep -q "not defined" ; then
		UI_OPTION=`astparam r ui_option`
		if echo "$UI_OPTION" | grep -q "not defined" ; then
			#UIO_CONVERT_TO_HEX   (1 << 0)
			UI_OPTION='0'
		fi
	fi

	_p=`astparam g debug`
	if ! { echo "$_p" | grep -q "not defined"; }; then
		DBG=$_p
	fi

	# Used to construct $MULTICAST_IP. MUST read before using $MULTICAST_IP.
	MULTICAST_IP_PREFIX=`astparam g multicast_ip_prefix`
	if echo "$MULTICAST_IP_PREFIX" | grep -q "not defined" ; then
		MULTICAST_IP_PREFIX=`astparam r multicast_ip_prefix`
		if echo "$MULTICAST_IP_PREFIX" | grep -q "not defined" ; then
			# MULTICAST_IP="${MULTICAST_IP_PREFIX}${CH0}.${CH1}${CH2}${CH3}"
			# 225.1.0.0 is used by name_service
			#MULTICAST_IP_PREFIX='225.0.'
			MULTICAST_IP_PREFIX='225.0.10'
		fi
	fi

	CS_GPIO_INV=`astparam g cs_gpio_inv`
	if echo "$CS_GPIO_INV" | grep -q "not defined" ; then
		CS_GPIO_INV=`astparam r cs_gpio_inv`
		if echo "$CS_GPIO_INV" | grep -q "not defined" ; then
			# CH0,CH1,CH2,CH3
			# 0 means normal read, 1 means invert
			CS_GPIO_INV="0000"
		fi
	fi
	_CHSLGP0INV=`expr "$CS_GPIO_INV" : '\(.\)...'`
	_CHSLGP1INV=`expr "$CS_GPIO_INV" : '.\(.\)..'`
	_CHSLGP2INV=`expr "$CS_GPIO_INV" : '..\(.\).'`
	_CHSLGP3INV=`expr "$CS_GPIO_INV" : '...\(.\)'`

	CS_GPIO_ORDER=`astparam g cs_gpio_order`
	if echo "$CS_GPIO_ORDER" | grep -q "not defined" ; then
		CS_GPIO_ORDER=`astparam r cs_gpio_order`
		if echo "$CS_GPIO_ORDER" | grep -q "not defined" ; then
			CS_GPIO_ORDER="0123"
		fi
	fi
	_CHSLGP0=ch`expr "$CS_GPIO_ORDER" : '\(.\)...'`
	_CHSLGP1=ch`expr "$CS_GPIO_ORDER" : '.\(.\)..'`
	_CHSLGP2=ch`expr "$CS_GPIO_ORDER" : '..\(.\).'`
	_CHSLGP3=ch`expr "$CS_GPIO_ORDER" : '...\(.\)'`

	# NOTE: _CHSLGP0..3, _CHSLGPINV0..3 MUST be ready before calling refresh_4bits_ch()
	refresh_4bits_ch
	refresh_hostname_params
	refresh_ch_params

	RELOAD_AVAHID='n'

	CH_SELECT_I2S=`astparam g ch_select_i2s`
	if echo "$CH_SELECT_I2S" | grep -q "not defined" ; then
		CH_SELECT_I2S=`astparam r ch_select_i2s`
		if echo "$CH_SELECT_I2S" | grep -q "not defined" ; then
			CH_SELECT_I2S=''
		fi
	fi

	MULTICAST_IP_I2S=`astparam g multicast_ip_i2s`
	if echo "$MULTICAST_IP_I2S" | grep -q "not defined" ; then
		MULTICAST_IP_I2S=`astparam r multicast_ip_i2s`
		if echo "$MULTICAST_IP_I2S" | grep -q "not defined" ; then
			MULTICAST_IP_I2S=''
		fi
	fi

	HOSTNAME_PREFIX=`astparam g hostname_prefix`
	if echo "$HOSTNAME_PREFIX" | grep -q "not defined" ; then
		HOSTNAME_PREFIX=`astparam r hostname_prefix`
		if echo "$HOSTNAME_PREFIX" | grep -q "not defined" ; then
			case "$SOC_OP_MODE" in
				1)
					HOSTNAME_PREFIX='ast'
				;;
				*)
					HOSTNAME_PREFIX="ast$SOC_OP_MODE"
				;;
			esac
		fi
	fi

	V_1080I_TO_720P=`astparam g v_1080i_to_720p`
	if echo "$V_1080I_TO_720P" | grep -q "not defined" ; then
		V_1080I_TO_720P=`astparam r v_1080i_to_720p`
		if echo "$V_1080I_TO_720P" | grep -q "not defined" ; then
			V_1080I_TO_720P='n'
		fi
	fi

	IGNORE_E_BUTTON_LINK=`astparam g ignore_e_button_link`
	if echo "$IGNORE_E_BUTTON_LINK" | grep -q "not defined" ; then
		IGNORE_E_BUTTON_LINK=`astparam r ignore_e_button_link`
		if echo "$IGNORE_E_BUTTON_LINK" | grep -q "not defined" ; then
			if [ "$SCENARIO" = 'usb_only' ]; then
				IGNORE_E_BUTTON_LINK='y'
			else
				IGNORE_E_BUTTON_LINK='n'
			fi
		fi
	fi

	IGNORE_E_BUTTON_LINK_1=`astparam g ignore_e_button_link_1`
	if echo "$IGNORE_E_BUTTON_LINK_1" | grep -q "not defined" ; then
		IGNORE_E_BUTTON_LINK_1=`astparam r ignore_e_button_link_1`
		if echo "$IGNORE_E_BUTTON_LINK_1" | grep -q "not defined" ; then
			if [ "$SCENARIO" = 'usb_only' ] && [ "$IS_HOST" = 'y' ]; then
				IGNORE_E_BUTTON_LINK_1='y'
			else
				IGNORE_E_BUTTON_LINK_1='n'
			fi
		fi
	fi

	PWR_LED_TYPE=`astparam g pwr_led_type`
	if echo "$PWR_LED_TYPE" | grep -q "not defined" ; then
		PWR_LED_TYPE=`astparam r pwr_led_type`
		if echo "$PWR_LED_TYPE" | grep -q "not defined" ; then
			if [ "$SCENARIO" = 'usb_only' ] && [ "$SHARE_USB" = 'y' ]; then
				PWR_LED_TYPE='share_usb'
			else
				PWR_LED_TYPE='default'
			fi

		fi
	fi

	if [ "$EN_VIDEO_WALL" = 'y' ]; then
		# Considering non-RS232 chain mode, we can support SoIP
		#if [ "$IS_HOST" = 'y' ]; then
		#	NO_SOIP='y'
		#else
		#	SOIP_GUEST_ON='y'
		#fi
		init_video_wall_params
	fi

	EN_LOG=`astparam g en_log`
	if echo "$EN_LOG" | grep -q "not defined" ; then
		EN_LOG=`astparam r en_log`
		if echo "$EN_LOG" | grep -q "not defined" ; then
			EN_LOG='y'
		fi
	fi

	JUMBO_MTU=`astparam g jumbo_mtu`
	if echo "$JUMBO_MTU" | grep -q "not defined" ; then
		JUMBO_MTU=`astparam r jumbo_mtu`
		if echo "$JUMBO_MTU" | grep -q "not defined" ; then
			JUMBO_MTU='8000'
		fi
	fi

	STOP_ON_BOOT_TEST_FAIL=`astparam g stop_on_boot_test_fail`
	if echo "$STOP_ON_BOOT_TEST_FAIL" | grep -q "not defined" ; then
		STOP_ON_BOOT_TEST_FAIL=`astparam r stop_on_boot_test_fail`
		if echo "$STOP_ON_BOOT_TEST_FAIL" | grep -q "not defined" ; then
			STOP_ON_BOOT_TEST_FAIL='n'
		fi
	fi

	TELNETD_PARAM=`astparam g telnetd_param`
	if echo "$TELNETD_PARAM" | grep -q "not defined" ; then
		TELNETD_PARAM=`astparam r telnetd_param`
		if echo "$TELNETD_PARAM" | grep -q "not defined" ; then
			TELNETD_PARAM='-p 23 -l /bin/sh'
		fi
	fi

	LM_LINK_OFF_TIMEOUT=`astparam g lm_link_off_timeout`
	if echo "$LM_LINK_OFF_TIMEOUT" | grep -q "not defined" ; then
		LM_LINK_OFF_TIMEOUT=`astparam r lm_link_off_timeout`
		if echo "$LM_LINK_OFF_TIMEOUT" | grep -q "not defined" ; then
			LM_LINK_OFF_TIMEOUT='8'
		fi
	fi

	HDCP_ALWAYS_ON=`astparam g hdcp_always_on`
	if echo "$HDCP_ALWAYS_ON" | grep -q "not defined" ; then
		HDCP_ALWAYS_ON=`astparam r hdcp_always_on`
		if echo "$HDCP_ALWAYS_ON" | grep -q "not defined" ; then
			HDCP_ALWAYS_ON='n'
		fi
	fi

	HDCP_ALWAYS_ON_22=`astparam g hdcp_always_on_22`
	if echo "$HDCP_ALWAYS_ON_22" | grep -q "not defined" ; then
		HDCP_ALWAYS_ON_22=`astparam r hdcp_always_on_22`
		if echo "$HDCP_ALWAYS_ON_22" | grep -q "not defined" ; then
			HDCP_ALWAYS_ON_22='n'
		fi
	fi

	HDCP_CTS_OPTION=`astparam g hdcp_cts_option`
	if echo "$HDCP_CTS_OPTION" | grep -q "not defined" ; then
		HDCP_CTS_OPTION=`astparam r hdcp_cts_option`
		if echo "$HDCP_CTS_OPTION" | grep -q "not defined" ; then
			HDCP_CTS_OPTION='0'
		fi
	fi

	HDCP_MODE=`astparam g hdcp_mode`
	if echo "$HDCP_MODE" | grep -q "not defined" ; then
		HDCP_MODE=`astparam r hdcp_mode`
		if echo "$HDCP_MODE" | grep -q "not defined" ; then
			# 0: legency HDCP
			# 1: standard HDCP 2.0
			# 2: fast HDCP 2.0
			HDCP_MODE='0'
		fi
	fi
	
	HDCP2_VERSION=`astparam g hdcp2_version`
	if echo "$HDCP2_VERSION" | grep -q "not defined" ; then
		HDCP2_VERSION=`astparam r hdcp2_version`
		if echo "$HDCP2_VERSION" | grep -q "not defined" ; then
			HDCP2_VERSION='0'
		fi
	fi
	
	EN_AES=`astparam g en_aes`
	if echo "$EN_AES" | grep -q "not defined" ; then
		EN_AES=`astparam r en_aes`
		if echo "$EN_AES" | grep -q "not defined" ; then
			EN_AES='n'
		fi
	fi
	
	HDCP2_GLOBAL_CONSTANT=`astparam g hdcp2_global_constant`
	if echo "$HDCP2_GLOBAL_CONSTANT" | grep -q "not defined" ; then
		HDCP2_GLOBAL_CONSTANT=`astparam r hdcp2_global_constant`
		if echo "$HDCP2_GLOBAL_CONSTANT" | grep -q "not defined" ; then
			HDCP2_GLOBAL_CONSTANT='unavailable'
		fi
	fi

	V_RX_DRV_OPTION=`astparam g v_rx_drv_option`
	if echo "$V_RX_DRV_OPTION" | grep -q "not defined" ; then
		V_RX_DRV_OPTION=`astparam r v_rx_drv_option`
		if echo "$V_RX_DRV_OPTION" | grep -q "not defined" ; then
			V_RX_DRV_OPTION='0'
		fi
	fi

	V_REJECT_HDCP=`astparam g v_reject_hdcp`
	if echo "$V_REJECT_HDCP" | grep -q "not defined" ; then
		V_REJECT_HDCP=`astparam r v_reject_hdcp`
		if echo "$V_REJECT_HDCP" | grep -q "not defined" ; then
			V_REJECT_HDCP='n'
		fi
	fi
	if [ "$V_REJECT_HDCP" = 'y' ]; then
		V_RX_DRV_OPTION=$(( $V_RX_DRV_OPTION | 1 ))
	fi

	V_IGNORE_CTS7_33=`astparam g v_ignore_cts7_33`
	if echo "$V_IGNORE_CTS7_33" | grep -q "not defined" ; then
		V_IGNORE_CTS7_33=`astparam r v_ignore_cts7_33`
		if echo "$V_IGNORE_CTS7_33" | grep -q "not defined" ; then
			V_IGNORE_CTS7_33='n'
		fi
	fi

	V_CHUNK_SIZE=`astparam g v_chunk_size`
	if echo "$V_CHUNK_SIZE" | grep -q "not defined" ; then
		V_CHUNK_SIZE=`astparam r v_chunk_size`
		if echo "$V_CHUNK_SIZE" | grep -q "not defined" ; then
			case "$SOC_VER" in
				1)
					V_CHUNK_SIZE='64512' # Use '7376' to smooth network burst
				;;
				2)
					V_CHUNK_SIZE='64512' #63x1024
				;;
				*)
					V_CHUNK_SIZE='64512' #63x1024
				;;
			esac
		fi
	fi
	
	A_IO_SELECT=`astparam g a_io_select`
	if echo "$A_IO_SELECT" | grep -q "not defined" ; then
		A_IO_SELECT=`astparam r a_io_select`
		if echo "$A_IO_SELECT" | grep -q "not defined" ; then
			# 'auto', 'auto_1', 'auto_2', 'hdmi' or 'analog'
			#auto: HDMI per GPIO, VGA fixed codec.
			#auto_1: always per GPIO.
			#auto_2: always per video port. HDMI/DVI use HDMI audio, VGA use codec audio.
			A_IO_SELECT='auto'
		fi
	fi

	A_OUTPUT_DELAY=`astparam g a_output_delay`
	if echo "$A_OUTPUT_DELAY" | grep -q "not defined" ; then
		A_OUTPUT_DELAY=`astparam r a_output_delay`
		if echo "$A_OUTPUT_DELAY" | grep -q "not defined" ; then
			# in ms. From 0 to 100 ms. For SoC >= V3
			A_OUTPUT_DELAY='0'
		fi
	fi

	A_ANALOG_IN_VOL=`astparam g a_analog_in_vol`
	if echo "$A_ANALOG_IN_VOL" | grep -q "not defined" ; then
		A_ANALOG_IN_VOL=`astparam r a_analog_in_vol`
		if echo "$A_ANALOG_IN_VOL" | grep -q "not defined" ; then
			A_ANALOG_IN_VOL='-1'
		fi
	fi

	A_ANALOG_OUT_VOL=`astparam g a_analog_out_vol`
	if echo "$A_ANALOG_OUT_VOL" | grep -q "not defined" ; then
		A_ANALOG_OUT_VOL=`astparam r a_analog_out_vol`
		if echo "$A_ANALOG_OUT_VOL" | grep -q "not defined" ; then
			A_ANALOG_OUT_VOL='-1'
		fi
	fi

	V_HDMI_FORCE_RGB_OUTPUT=`astparam g v_hdmi_force_rgb_output`
	if echo "$V_HDMI_FORCE_RGB_OUTPUT=" | grep -q "not defined" ; then
		V_HDMI_FORCE_RGB_OUTPUT=`astparam r v_hdmi_force_rgb_output`
		if echo "$V_HDMI_FORCE_RGB_OUTPUT" | grep -q "not defined" ; then
			# 5: all output RGB. (OF_DE_RGB | OF_SE_RGB)
			# 1: non-4K RGB, 4K YUV. (OF_DE_YUV | OF_SE_RGB)
			V_HDMI_FORCE_RGB_OUTPUT='5'
		fi
	fi

	V_OUTPUT_TIMING_CONVERT=`astparam g v_output_timing_convert`
	if echo "$V_OUTPUT_TIMING_CONVERT=" | grep -q "not defined" ; then
		V_OUTPUT_TIMING_CONVERT=`astparam r v_output_timing_convert`
		if echo "$V_OUTPUT_TIMING_CONVERT" | grep -q "not defined" ; then
			V_OUTPUT_TIMING_CONVERT='0'
		fi
	fi

	V_HDMI_HDR_MODE=`astparam g v_hdmi_hdr_mode`
	if echo "$V_HDMI_HDR_MODE=" | grep -q "not defined" ; then
		V_HDMI_HDR_MODE=`astparam r v_hdmi_hdr_mode`
		if echo "$V_HDMI_HDR_MODE" | grep -q "not defined" ; then
			# 0: HDR passthrough 1: Force HDR off
			V_HDMI_HDR_MODE='0'
		fi
	fi

	######### Always buttom ##############################################
	WEB_UI_CFG=`astparam g web_ui_cfg`
	if echo "$WEB_UI_CFG" | grep -q "not defined" ; then
		WEB_UI_CFG=`astparam r web_ui_cfg`
		if echo "$WEB_UI_CFG" | grep -q "not defined" ; then
			# e: essential. The dummy keyword to keep only essential web UI.
			# n: network
			# v: video
			# w: video wall
			# a: audio (i2s)
			# u: usb
			# s: serial over ip
			# r: IR
			# g: god mode. TBD
			WEB_UI_CFG='ne'
			if [ "$NO_VIDEO" = 'n' ]; then
				WEB_UI_CFG="${WEB_UI_CFG}v"
			fi
			if [ "$EN_VIDEO_WALL" = 'y' ]; then
				WEB_UI_CFG="${WEB_UI_CFG}w"
			fi
			if [ "$NO_I2S" = 'n' ]; then
				WEB_UI_CFG="${WEB_UI_CFG}a"
			fi
			if [ "$NO_USB" = 'n' ]; then
				WEB_UI_CFG="${WEB_UI_CFG}u"
			fi
			if [ "$NO_SOIP" = 'n' ]; then
				WEB_UI_CFG="${WEB_UI_CFG}s"
			fi
			if [ "$NO_IR" = 'n' ]; then
				WEB_UI_CFG="${WEB_UI_CFG}r"
			fi
			# Initial WEB_UI_CFG only once and use the setting forever. 
			# Otherwise, when user disable XX function, WEB UI won't display the enable option anymore,
			# since WEB_UI_CFG is changed after xx function disabled.
			astparam s web_ui_cfg $WEB_UI_CFG
			astparam save
		fi
	fi

	if [ "$IS_HOST" = 'y' ]; then
		. ./button_handler_h.sh
	else
		. ./button_handler_c.sh
	fi
	_t=`astparam g btn1_short`
	if echo "$_t" | grep -q "not defined" ; then
		_t=`astparam r btn1_short`
		if ! { echo "$_t" | grep -q "not defined"; }; then
			BTN1_SHORT="$_t"
		fi
	else
		BTN1_SHORT="$_t"
	fi
	_t=`astparam g btn1_long`
	if echo "$_t" | grep -q "not defined" ; then
		_t=`astparam r btn1_long`
		if ! { echo "$_t" | grep -q "not defined"; }; then
			BTN1_LONG="$_t"
		fi
	else
		BTN1_LONG="$_t"
	fi
	_t=`astparam g btn1_short_on_boot`
	if echo "$_t" | grep -q "not defined" ; then
		_t=`astparam r btn1_short_on_boot`
		if ! { echo "$_t" | grep -q "not defined"; }; then
			BTN1_SHORT_ON_BOOT="$_t"
		fi
	else
		BTN1_SHORT_ON_BOOT="$_t"
	fi
	_t=`astparam g btn1_long_on_boot`
	if echo "$_t" | grep -q "not defined" ; then
		_t=`astparam r btn1_long_on_boot`
		if ! { echo "$_t" | grep -q "not defined"; }; then
			BTN1_LONG_ON_BOOT="$_t"
		fi
	else
		BTN1_LONG_ON_BOOT="$_t"
	fi
	_t=`astparam g btn1_short_on_eth_off`
	if echo "$_t" | grep -q "not defined" ; then
		_t=`astparam r btn1_short_on_eth_off`
		if ! { echo "$_t" | grep -q "not defined"; }; then
			BTN1_SHORT_ON_ETH_OFF="$_t"
		fi
	else
		BTN1_SHORT_ON_ETH_OFF="$_t"
	fi
	_t=`astparam g btn1_long_on_eth_off`
	if echo "$_t" | grep -q "not defined" ; then
		_t=`astparam r btn1_long_on_eth_off`
		if ! { echo "$_t" | grep -q "not defined"; }; then
			BTN1_LONG_ON_ETH_OFF="$_t"
		fi
	else
		BTN1_LONG_ON_ETH_OFF="$_t"
	fi
	_t=`astparam g btn2_short`
	if echo "$_t" | grep -q "not defined" ; then
		_t=`astparam r btn2_short`
		if ! { echo "$_t" | grep -q "not defined"; }; then
			BTN2_SHORT="$_t"
		fi
	else
		BTN2_SHORT="$_t"
	fi
	_t=`astparam g btn2_long`
	if echo "$_t" | grep -q "not defined" ; then
		_t=`astparam r btn2_long`
		if ! { echo "$_t" | grep -q "not defined"; }; then
			BTN2_LONG="$_t"
		fi
	else
		BTN2_LONG="$_t"
	fi
	_t=`astparam g btn2_short_on_boot`
	if echo "$_t" | grep -q "not defined" ; then
		_t=`astparam r btn2_short_on_boot`
		if ! { echo "$_t" | grep -q "not defined"; }; then
			BTN2_SHORT_ON_BOOT="$_t"
		fi
	else
		BTN2_SHORT_ON_BOOT="$_t"
	fi
	_t=`astparam g btn2_long_on_boot`
	if echo "$_t" | grep -q "not defined" ; then
		_t=`astparam r btn2_long_on_boot`
		if ! { echo "$_t" | grep -q "not defined"; }; then
			BTN2_LONG_ON_BOOT="$_t"
		fi
	else
		BTN2_LONG_ON_BOOT="$_t"
	fi
	_t=`astparam g btn2_short_on_eth_off`
	if echo "$_t" | grep -q "not defined" ; then
		_t=`astparam r btn2_short_on_eth_off`
		if ! { echo "$_t" | grep -q "not defined"; }; then
			BTN2_SHORT_ON_ETH_OFF="$_t"
		fi
	else
		BTN2_SHORT_ON_ETH_OFF="$_t"
	fi
	_t=`astparam g btn2_long_on_eth_off`
	if echo "$_t" | grep -q "not defined" ; then
		_t=`astparam r btn2_long_on_eth_off`
		if ! { echo "$_t" | grep -q "not defined"; }; then
			BTN2_LONG_ON_ETH_OFF="$_t"
		fi
	else
		BTN2_LONG_ON_ETH_OFF="$_t"
	fi
	_t=`astparam g btn_init`
	if echo "$_t" | grep -q "not defined" ; then
		_t=`astparam r btn_init`
		if ! { echo "$_t" | grep -q "not defined"; }; then
			BTN_INIT="$_t"
		fi
	else
		BTN_INIT="$_t"
	fi
	_t=`astparam g btn1_delay`
	if echo "$_t" | grep -q "not defined" ; then
		_t=`astparam r btn1_delay`
		if ! { echo "$_t" | grep -q "not defined"; }; then
			BTN1_DELAY="$_t"
		fi
	else
		BTN1_DELAY="$_t"
	fi
	_t=`astparam g btn2_delay`
	if echo "$_t" | grep -q "not defined" ; then
		_t=`astparam r btn2_delay`
		if ! { echo "$_t" | grep -q "not defined"; }; then
			BTN2_DELAY="$_t"
		fi
	else
		BTN2_DELAY="$_t"
	fi

	echo "==============================="
	cat /etc/version
	echo "==============================="
}

start_network()
{
	if [ "$PROFILE" = "wifi" ]; then
		if [ "$IS_HOST" = 'y' ]; then
			# For WiFi host, we force to 100Mbps to avoid traffic jam.
			echo 1 > /sys/devices/platform/ftgmac/link_mode
			echo "Force MAC to 100Mbps"
		fi
	fi
	#ifconfig lo up
	config_ip_addr "$1"
}

to_mfg_mode()
{
	# Check the link button again. If it is still pressed, then reset to factory default.
	if [ "$1" = 'clear_rw' ]; then
		echo "Reset to factory default"
		astparam flush
		astparam save
	fi
	
	# Set static ip address
	ipaddr=`astparam g asthostip`
	if [ "$ipaddr" = "\"asthostip\" not defined" ]; then
		ipaddr="192.168.0.88"
	fi
	ifconfig eth0:stat "$ipaddr"
	# Start web server
	httpd -h /www &
	# Start telnet server
	start_telnetd
	# Set LEDs
	led_blink "$LED_PWR"
	led_blink "$LED_LINK"
	inform_gui_echo "In MFG mode. IP:$ipaddr"
}

handle_button_on_boot()
{
	if [ "$FPGA_TEST" = '1' ]; then
		return
	fi
	echo "$BTN1_DELAY" > "$GPIO_SYS_PATH"/button_link/delay
	echo "$BTN2_DELAY" > "$GPIO_SYS_PATH"/button_pairing/delay

	handle_"$BTN_INIT"
	
	if [ `cat "$GPIO_SYS_PATH"/button_link/state_on_active` = 'On' ]; then
		# Check the link button again. If it is still pressed, then execute BTN1_LONG_ON_BOOT
		echo 4 > "$GPIO_SYS_PATH"/button_link/brightness
		_bs=`cat "$GPIO_SYS_PATH"/button_link/brightness`
		if [ "$_bs" = '1' ] && [ "$BTN1_LONG_ON_BOOT" != 'e_btn_ignore' ]; then
			handle_"$BTN1_LONG_ON_BOOT"
		else
			handle_"$BTN1_SHORT_ON_BOOT"
		fi
	fi

	if [ `cat "$GPIO_SYS_PATH"/button_pairing/state_on_active` = 'On' ]; then
		echo 4 > "$GPIO_SYS_PATH"/button_pairing/brightness
		_bs=`cat "$GPIO_SYS_PATH"/button_pairing/brightness`
		if [ "$_bs" = '1' ] && [ "$BTN2_LONG_ON_BOOT" != 'e_btn_ignore' ]; then
			handle_"$BTN2_LONG_ON_BOOT"
		else
			handle_"$BTN2_SHORT_ON_BOOT"
		fi
	fi
}

unlink_client()
{
	if [ $NO_VIDEO = 'n' ]; then
		echo "$1" > "$VIDEO_SYS_PATH/unlink"
	fi
	if [ $NO_I2S = 'n' ]; then
		echo "$1" > "$I2S_SYS_PATH/unlink"
	fi
	if [ $NO_IR = 'n' ]; then
		echo "$1" > "$IR_SYS_PATH/unlink"
	fi
	# To Do. USBoIP
}

start_telnetd()
{
	# Start telnetd
	mount -t devpts devpts /dev/pts
	chown root.root /bin/busybox
	chmod 4755 /bin/busybox
	telnetd $TELNETD_PARAM
}

eth_link_is_off()
{
	# return 0 (true) if link off, otherwise return 1(false)
	ETH_LINK_STATE=`cat $MAC_SYS_PATH/link_state`
	if [ "$ETH_LINK_STATE" = "on" ]; then
		return 1
	fi
	
	return 0
}

to_readable_ip()
{
	# This function convert LM used IP format (ex:BA04FEA9) to human readable IP format.
	if [ -z "$1" ]; then
		echo 'N/A'
		return
	fi
	_d4='0x'`expr "$1" : '\(..\)......'`
	_d3='0x'`expr "$1" : '..\(..\)....'`
	sleep 0.01
	_d2='0x'`expr "$1" : '....\(..\)..'`
	_d1='0x'`expr "$1" : '......\(..\)'`
	sleep 0.01
	_ip=`printf "%d.%d.%d.%d" $_d1 $_d2 $_d3 $_d4`
	echo "$_ip"

}

client_list_hex()
{
	if ! [ -e "${VIDEO_SYS_PATH}/unlink" ]; then
		return
	fi

	_ifs="$IFS"
IFS='
'
	for ip in `cat ${VIDEO_SYS_PATH}/unlink`; do
		# Parse "xxx.xxx.xxx.xxx  (AABBCCDD)"
		_IFS="$IFS";IFS="()";set -- $ip;IFS="$_IFS"
		echo "$2"
		#echo `expr "$ip" : '[[:digit:]]\{1,\}.[[:digit:]]\{1,\}.[[:digit:]]\{1,\}.[[:digit:]]\{1,\}..\(........\).'`
	done
	IFS="$_ifs"
}

next_client_idx()
{
	CLIENT_LIST=`client_list_hex`
	if [ -z "$CLIENT_LIST" ]; then
		return
	fi
	_max='0'
	for i in $CLIENT_LIST; do
		#_max=`expr $_max + 1`
		_max=$(( $_max + 1 ))
	done
	#CLIENT_LIST_IDX=`expr \( $CLIENT_LIST_IDX + 1 \) % $_max`
	CLIENT_LIST_IDX=$(( ($CLIENT_LIST_IDX + 1) % $_max ))
	echo "idx=$CLIENT_LIST_IDX"
}

the_client_ip_hex()
{
	_max='0'
	for i in $CLIENT_LIST; do
		if [ "$_max" = "$CLIENT_LIST_IDX" ]; then
			echo -n "$i"
			return
		fi
		#_max=`expr $_max + 1`
		_max=$(( $_max + 1 ))
	done
	echo -n '00000000'
}

# For host video wall rs232 cascading
send_to_next_host()
{
	echo > /dev/ttyS0
	echo "e $*" > /dev/ttyS0
	#echo "send to next host: $*"
}

# For host video wall rs232 cascading
next_row_id()
{
	#_max=`expr $VW_VAR_TAIL_IDX + 1`
	_max=$(( $VW_VAR_TAIL_IDX + 1 ))
	#THE_ROW_ID=`expr \( $THE_ROW_ID + 1 \) % $_max`
	THE_ROW_ID=$(( ($THE_ROW_ID + 1) % $_max ))
}

get_current_time()
{
	#expr "`cat /proc/uptime`" : '\([[:digit:]]\{1,\}\).*'
	_IFS="$IFS";IFS='. ';set -- $(cat /proc/uptime);IFS="$_IFS"
	echo "$1"
}

igmp_leave_all()
{
	# Bruce101103. Dirty patch. sleep in between is necessary because SMC switch seems lost packets which are sending too fast.
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}0.000 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}0.001 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}0.010 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}0.011 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}0.100 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}0.101 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}0.110 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}0.111 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}1.000 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}1.001 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}1.010 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}1.011 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}1.100 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}1.101 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}1.110 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}1.111 2>&1 1>/dev/null
	sleep 3
	# Send them twice
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}1.111 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}1.110 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}1.101 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}1.100 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}1.011 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}1.010 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}1.001 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}1.000 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}0.111 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}0.110 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}0.101 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}0.100 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}0.011 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}0.010 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}0.001 2>&1 1>/dev/null
	sleep 1
	igmp -t 0x17 -m ${MULTICAST_IP_PREFIX}0.000 2>&1 1>/dev/null
}

_echo_parameters_client()
{
	echo "USB_DISABLE_DEVICES=$USB_DISABLE_DEVICES"
	echo "USB_ENABLE_DEVICES=$USB_ENABLE_DEVICES"
	echo "USB_DISABLE_CLASSES=$USB_DISABLE_CLASSES"
	echo "USB_ENABLE_CLASSES=$USB_ENABLE_CLASSES"
	echo "USB_CONFLICT_POLICY=$USB_CONFLICT_POLICY"
	sleep 0.01
	echo "USB_DEFAULT_POLICY=$USB_DEFAULT_POLICY"
	echo "GUI_SHOW_TEXT_INIT=$GUI_SHOW_TEXT_INIT"
	echo "SHOW_CH_OSD=$SHOW_CH_OSD"
	echo "V_TURN_OFF_SCREEN_ON_PWR_SAVE=$V_TURN_OFF_SCREEN_ON_PWR_SAVE"
	echo "V_SRC_UNAVAILABLE_TIMEOUT=$V_SRC_UNAVAILABLE_TIMEOUT"
	echo "I2S_CLOCK_LOCK_MODE=$I2S_CLOCK_LOCK_MODE"
	sleep 0.01
}

_echo_parameters_host()
{
	echo "USB_SET_ADDR_HACK=$USB_SET_ADDR_HACK"
	echo "USB_HID_URB_INTERVAL=$USB_HID_URB_INTERVAL"
	echo "USB_QUIRK=$USB_QUIRK"
	echo "REMOTE_EDID_PATCH=$REMOTE_EDID_PATCH"
	echo "LOOPBACK_EDID_PATCH=$LOOPBACK_EDID_PATCH"
	echo "LOOPBACK_DEFAULT_ON=$LOOPBACK_DEFAULT_ON"
	echo "V_RX_DRV=$V_RX_DRV"
	echo "V_FRAME_RATE=$V_FRAME_RATE"
	sleep 0.01
}

echo_parameters()
{
	sleep 0.01
	echo "IS_HOST=$IS_HOST"
	echo "STATE=$STATE"
	echo "ACCESS_ON=$ACCESS_ON"
	echo "VIDEOIP_RDY=$VIDEOIP_RDY"
	echo "USBIP_RDY=$USBIP_RDY"
	echo "HEARTBEAT_RDY=$HEARTBEAT_RDY"
	echo "USBIP_USER_RDY=$USBIP_USER_RDY"
	echo "I2S_RDY=$I2S_RDY"
	sleep 0.01
	echo "IR_RDY=$IR_RDY"
	echo "DBG=$DBG"
	echo "SHARE_USB=$SHARE_USB"
	echo "SHARE_USB_AUTO_MODE=$SHARE_USB_AUTO_MODE"
	echo "SHARE_USB_ON_FIRST_PEER=$SHARE_USB_ON_FIRST_PEER"
	echo "SHARE_USB_STATE=$SHARE_USB_STATE"
	echo "SHARE_USBIP_RDY=$SHARE_USBIP_RDY"
	echo "SHARE_USBIP_USER_RDY=$SHARE_USBIP_USER_RDY"
	sleep 0.01
	echo "USB_CLIENT_IP="`to_readable_ip $USB_CLIENT_IP`"($USB_CLIENT_IP)"
	sleep 0.01
	echo "CH_SELECT=$CH_SELECT"
	echo "MULTICAST_IP=$MULTICAST_IP"
	echo "HOSTNAMEBYDIPSWITCH=$HOSTNAMEBYDIPSWITCH"
	echo "RESET_CH_ON_BOOT=$RESET_CH_ON_BOOT"
	echo "HOSTNAME_ID=$HOSTNAME_ID"
	echo "IP_MODE=$IP_MODE"
	echo "IPADDR=$IPADDR"
	echo "NETMASK=$NETMASK"
	echo "GATEWAYIP=$GATEWAYIP"
	sleep 0.01
	echo "MULTICAST_ON=$MULTICAST_ON"
	echo "UI_FEATURE=$UI_FEATURE"
	echo "HOSTNAME_PREFIX=$HOSTNAME_PREFIX"
	echo "SCENARIO=$SCENARIO"
	echo "SOC_VER=$SOC_VER"
	echo "SOC_OP_MODE=$SOC_OP_MODE"
	echo "AST_PLATFORM=$AST_PLATFORM"
	echo "MY_MAC=$MY_MAC"
	echo "MY_IP=$MY_IP"
	echo "MY_NETMASK=$MY_NETMASK"
	echo "MY_GATEWAYIP=$MY_GATEWAYIP"
	echo "GWIP=$GWIP"
	sleep 0.01
	echo "ETH_LINK_STATE="`cat $MAC_SYS_PATH/link_state`
	sleep 0.01
	echo "ETH_LINK_MODE="`cat $MAC_SYS_PATH/link_mode`
	sleep 0.01
	echo "LM_LINK_OFF_TIMEOUT=$LM_LINK_OFF_TIMEOUT"
	echo "EDID_USE=$EDID_USE"
	echo "WEB_UI_CFG=$WEB_UI_CFG"
	echo "SEAMLESS_SWITCH=$SEAMLESS_SWITCH"
	echo "JUMBO_MTU=$JUMBO_MTU"
	echo "V_1080I_TO_720P=$V_1080I_TO_720P"
	echo "V_BCD_THRESHOLD=$V_BCD_THRESHOLD"
	echo "V_QUALITY_MODE=$V_QUALITY_MODE"
	echo "NO_PWRBTN=$NO_PWRBTN"
	echo "MFG_MODE=$MFG_MODE"
	sleep 0.01
	echo "PROFILE=$PROFILE"
	echo "SOIP_GUEST_ON=$SOIP_GUEST_ON"
	echo "SOIP_TYPE2=$SOIP_TYPE2"
	echo "S0_BAUDRATE=$S0_BAUDRATE"
	echo "NO_SOIP=$NO_SOIP"
	echo "NO_VIDEO=$NO_VIDEO"
	echo "NO_USB=$NO_USB"
	echo "NO_KMOIP=$NO_KMOIP"
	echo "NO_IR=$NO_IR"
	echo "NO_I2S=$NO_I2S"
	sleep 0.01
	echo "UDP_ON=$UDP_ON"
	echo "EN_LOG=$EN_LOG"
	echo "V_REJECT_HDCP=$V_REJECT_HDCP"
	echo "V_IGNORE_CTS7_33=$V_IGNORE_CTS7_33"
	echo "V_CHUNK_SIZE=$V_CHUNK_SIZE"
	echo "V_OUTPUT_TIMING_CONVERT=$V_OUTPUT_TIMING_CONVERT"
	echo "V_HDMI_HDR_MODE=$V_HDMI_HDR_MODE"
	echo "A_IO_SELECT=$A_IO_SELECT"
	echo "A_OUTPUT_DELAY=$A_OUTPUT_DELAY"
	echo "A_ANALOG_IN_VOL=$A_ANALOG_IN_VOL"
	echo "A_ANALOG_OUT_VOL=$A_ANALOG_OUT_VOL"
	sleep 0.01
	# Video Wall Stuff
	echo "EN_VIDEO_WALL=$EN_VIDEO_WALL"
	echo "VW_VAR_MAX_ROW=$VW_VAR_MAX_ROW"
	echo "VW_VAR_MAX_COLUMN=$VW_VAR_MAX_COLUMN"
	echo "VW_VAR_ROW=$VW_VAR_ROW"
	echo "VW_VAR_COLUMN=$VW_VAR_COLUMN"
	echo "VW_VAR_MONINFO_HA=$VW_VAR_MONINFO_HA"
	echo "VW_VAR_MONINFO_HT=$VW_VAR_MONINFO_HT"
	echo "VW_VAR_MONINFO_VA=$VW_VAR_MONINFO_VA"
	echo "VW_VAR_MONINFO_VT=$VW_VAR_MONINFO_VT"
	echo "VW_VAR_POS_IDX=$VW_VAR_POS_IDX"
	sleep 0.01
	echo "VW_VAR_H_SHIFT=$VW_VAR_H_SHIFT"
	echo "VW_VAR_V_SHIFT=$VW_VAR_V_SHIFT"
	echo "VW_VAR_H_SCALE=$VW_VAR_H_SCALE"
	echo "VW_VAR_V_SCALE=$VW_VAR_V_SCALE"
	echo "MY_ROW_ID=$MY_ROW_ID"
	echo "THE_ROW_ID=$THE_ROW_ID"
	echo "VW_VAR_POS_MAX_ROW=$VW_VAR_POS_MAX_ROW"
	echo "VW_VAR_POS_MAX_COL=$VW_VAR_POS_MAX_COL"
	sleep 0.01
	echo "VW_VAR_POS_R=$VW_VAR_POS_R"
	echo "VW_VAR_POS_C=$VW_VAR_POS_C"
	echo "VW_VAR_DELAY_KICK=$VW_VAR_DELAY_KICK"
	echo "VW_VAR_TAIL_IDX=$VW_VAR_TAIL_IDX"
	echo "VW_VAR_STRETCH_TYPE=$VW_VAR_STRETCH_TYPE"
	echo "VW_VAR_ROTATE=$VW_VAR_ROTATE"
	# Button handlers
	echo "BTN1_SHORT=$BTN1_SHORT"
	echo "BTN1_LONG=$BTN1_LONG"
	echo "BTN1_SHORT_ON_BOOT=$BTN1_SHORT_ON_BOOT"
	echo "BTN1_LONG_ON_BOOT=$BTN1_LONG_ON_BOOT"
	echo "BTN1_SHORT_ON_ETH_OFF=$BTN1_SHORT_ON_ETH_OFF"
	echo "BTN1_LONG_ON_ETH_OFF=$BTN1_LONG_ON_ETH_OFF"
	sleep 0.01
	echo "BTN2_SHORT=$BTN2_SHORT"
	echo "BTN2_LONG=$BTN2_LONG"
	echo "BTN2_SHORT_ON_BOOT=$BTN2_SHORT_ON_BOOT"
	echo "BTN2_LONG_ON_BOOT=$BTN2_LONG_ON_BOOT"
	echo "BTN2_SHORT_ON_ETH_OFF=$BTN2_SHORT_ON_ETH_OFF"
	echo "BTN2_LONG_ON_ETH_OFF=$BTN2_LONG_ON_ETH_OFF"
	echo "BTN_INIT=$BTN_INIT"
	echo "BTN1_DELAY=$BTN1_DELAY"
	echo "BTN2_DELAY=$BTN2_DELAY"
	sleep 0.01

	if [ "$IS_HOST" = 'y' ]; then
		_echo_parameters_host
	else
		_echo_parameters_client
	fi
}

_echo_parameters_json_client()
{
	echo "\"USB_DISABLE_DEVICES\":\"$USB_DISABLE_DEVICES\","
	echo "\"USB_ENABLE_DEVICES\":\"$USB_ENABLE_DEVICES\","
	echo "\"USB_DISABLE_CLASSES\":\"$USB_DISABLE_CLASSES\","
	echo "\"USB_ENABLE_CLASSES\":\"$USB_ENABLE_CLASSES\","
	echo "\"USB_CONFLICT_POLICY\":\"$USB_CONFLICT_POLICY\","
	sleep 0.01
	echo "\"USB_DEFAULT_POLICY\":\"$USB_DEFAULT_POLICY\","
	echo "\"GUI_SHOW_TEXT_INIT\":\"$GUI_SHOW_TEXT_INIT\","
	echo "\"SHOW_CH_OSD\":\"$SHOW_CH_OSD\","
	echo "\"V_TURN_OFF_SCREEN_ON_PWR_SAVE\":\"$V_TURN_OFF_SCREEN_ON_PWR_SAVE\","
	echo "\"V_SRC_UNAVAILABLE_TIMEOUT\":\"$V_SRC_UNAVAILABLE_TIMEOUT\","
	echo "\"I2S_CLOCK_LOCK_MODE\":\"$I2S_CLOCK_LOCK_MODE\","
	sleep 0.01
}
	
_echo_parameters_json_host()
{
	echo "\"USB_SET_ADDR_HACK\":\"$USB_SET_ADDR_HACK\","
	echo "\"USB_HID_URB_INTERVAL\":\"$USB_HID_URB_INTERVAL\","
	echo "\"USB_QUIRK\":\"$USB_QUIRK\","
	echo "\"REMOTE_EDID_PATCH\":\"$REMOTE_EDID_PATCH\","
	echo "\"LOOPBACK_EDID_PATCH\":\"$LOOPBACK_EDID_PATCH\","
	echo "\"LOOPBACK_DEFAULT_ON\":\"$LOOPBACK_DEFAULT_ON\","
	echo "\"V_RX_DRV\":\"$V_RX_DRV\","
	echo "\"V_FRAME_RATE\":\"$V_FRAME_RATE\","
	sleep 0.01
}

echo_parameters_json()
{
	sleep 0.01
	echo "{"
	echo "\"IS_HOST\":\"$IS_HOST\","
	echo "\"STATE\":\"$STATE\","
	echo "\"ACCESS_ON\":\"$ACCESS_ON\","
	echo "\"VIDEOIP_RDY\":\"$VIDEOIP_RDY\","
	echo "\"USBIP_RDY\":\"$USBIP_RDY\","
	echo "\"HEARTBEAT_RDY\":\"$HEARTBEAT_RDY\","
	echo "\"USBIP_USER_RDY\":\"$USBIP_USER_RDY\","
	sleep 0.01
	echo "\"I2S_RDY\":\"$I2S_RDY\","
	echo "\"IR_RDY\":\"$IR_RDY\","
	echo "\"DBG\":\"$DBG\","
	echo "\"SHARE_USB\":\"$SHARE_USB\","
	echo "\"SHARE_USB_AUTO_MODE\":\"$SHARE_USB_AUTO_MODE\","
	echo "\"SHARE_USB_ON_FIRST_PEER\":\"$SHARE_USB_ON_FIRST_PEER\","
	echo "\"SHARE_USB_STATE\":\"$SHARE_USB_STATE\","
	echo "\"SHARE_USBIP_RDY\":\"$SHARE_USBIP_RDY\","
	echo "\"SHARE_USBIP_USER_RDY\":\"$SHARE_USBIP_USER_RDY\","
	sleep 0.01
	echo "\"USB_CLIENT_IP\":\""`to_readable_ip $USB_CLIENT_IP`"($USB_CLIENT_IP)\","
	sleep 0.01
	echo "\"CH_SELECT\":\"$CH_SELECT\","
	echo "\"MULTICAST_IP\":\"$MULTICAST_IP\","
	echo "\"HOSTNAMEBYDIPSWITCH\":\"$HOSTNAMEBYDIPSWITCH\","
	echo "\"RESET_CH_ON_BOOT\":\"$RESET_CH_ON_BOOT\","
	echo "\"HOSTNAME_ID\":\"$HOSTNAME_ID\","
	echo "\"IP_MODE\":\"$IP_MODE\","
	echo "\"IPADDR\":\"$IPADDR\","
	echo "\"NETMASK\":\"$NETMASK\","
	echo "\"GATEWAYIP\":\"$GATEWAYIP\","
	sleep 0.01
	echo "\"MULTICAST_ON\":\"$MULTICAST_ON\","
	echo "\"UI_FEATURE\":\"$UI_FEATURE\","
	echo "\"HOSTNAME_PREFIX\":\"$HOSTNAME_PREFIX\","
	echo "\"SCENARIO\":\"$SCENARIO\","
	echo "\"SOC_VER\":\"$SOC_VER\","
	echo "\"SOC_OP_MODE\":\"$SOC_OP_MODE\","
	echo "\"AST_PLATFORM\":\"$AST_PLATFORM\","
	echo "\"MY_MAC\":\"$MY_MAC\","
	echo "\"MY_IP\":\"$MY_IP\","
	echo "\"MY_NETMASK\":\"$MY_NETMASK\","
	echo "\"MY_GATEWAYIP\":\"$MY_GATEWAYIP\","
	echo "\"GWIP\":\"$GWIP\","
	sleep 0.01
	echo "\"ETH_LINK_STATE\":\""`cat $MAC_SYS_PATH/link_state`"\","
	sleep 0.01
	echo "\"ETH_LINK_MODE\":\""`cat $MAC_SYS_PATH/link_mode`"\","
	sleep 0.01
	echo "\"LM_LINK_OFF_TIMEOUT\":\"$LM_LINK_OFF_TIMEOUT\","
	echo "\"EDID_USE\":\"$EDID_USE\","
	echo "\"WEB_UI_CFG\":\"$WEB_UI_CFG\","
	echo "\"SEAMLESS_SWITCH\":\"$SEAMLESS_SWITCH\","
	echo "\"JUMBO_MTU\":\"$JUMBO_MTU\","
	echo "\"V_1080I_TO_720P\":\"$V_1080I_TO_720P\","
	echo "\"V_BCD_THRESHOLD\":\"$V_BCD_THRESHOLD\","
	echo "\"V_QUALITY_MODE\":\"$V_QUALITY_MODE\","
	echo "\"NO_PWRBTN\":\"$NO_PWRBTN\","
	echo "\"MFG_MODE\":\"$MFG_MODE\","
	echo "\"PROFILE\":\"$PROFILE\","
	sleep 0.01
	echo "\"SOIP_GUEST_ON\":\"$SOIP_GUEST_ON\","
	echo "\"SOIP_TYPE2\":\"$SOIP_TYPE2\","
	echo "\"NO_SOIP\":\"$NO_SOIP\","
	echo "\"S0_BAUDRATE\":\"$S0_BAUDRATE\","
	echo "\"NO_VIDEO\":\"$NO_VIDEO\","
	echo "\"NO_USB\":\"$NO_USB\","
	echo "\"NO_KMOIP\":\"$NO_KMOIP\","
	echo "\"NO_IR\":\"$NO_IR\","
	echo "\"NO_I2S\":\"$NO_I2S\","
	echo "\"UDP_ON\":\"$UDP_ON\","
	echo "\"EN_LOG\":\"$EN_LOG\","
	sleep 0.01
	echo "\"V_REJECT_HDCP\":\"$V_REJECT_HDCP\","
	echo "\"V_IGNORE_CTS7_33\":\"$V_IGNORE_CTS7_33\","
	echo "\"V_CHUNK_SIZE\":\"$V_CHUNK_SIZE\","
	echo "\"V_OUTPUT_TIMING_CONVERT\":\"$V_OUTPUT_TIMING_CONVERT\","
	echo "\"V_HDMI_HDR_MODE\":\"$V_HDMI_HDR_MODE\","
	echo "\"A_IO_SELECT\":\"$A_IO_SELECT\","
	echo "\"A_OUTPUT_DELAY\":\"$A_OUTPUT_DELAY\","
	echo "\"A_ANALOG_IN_VOL\":\"$A_ANALOG_IN_VOL\","
	echo "\"A_ANALOG_OUT_VOL\":\"$A_ANALOG_OUT_VOL\","
	sleep 0.01
	# Video Wall Stuff
	echo "\"EN_VIDEO_WALL\":\"$EN_VIDEO_WALL\","
	echo "\"VW_VAR_MAX_ROW\":\"$VW_VAR_MAX_ROW\","
	echo "\"VW_VAR_MAX_COLUMN\":\"$VW_VAR_MAX_COLUMN\","
	echo "\"VW_VAR_ROW\":\"$VW_VAR_ROW\","
	echo "\"VW_VAR_COLUMN\":\"$VW_VAR_COLUMN\","
	echo "\"VW_VAR_MONINFO_HA\":\"$VW_VAR_MONINFO_HA\","
	echo "\"VW_VAR_MONINFO_HT\":\"$VW_VAR_MONINFO_HT\","
	echo "\"VW_VAR_MONINFO_VA\":\"$VW_VAR_MONINFO_VA\","
	echo "\"VW_VAR_MONINFO_VT\":\"$VW_VAR_MONINFO_VT\","
	sleep 0.01
	echo "\"VW_VAR_POS_IDX\":\"$VW_VAR_POS_IDX\","
	echo "\"VW_VAR_H_SHIFT\":\"$VW_VAR_H_SHIFT\","
	echo "\"VW_VAR_V_SHIFT\":\"$VW_VAR_V_SHIFT\","
	echo "\"VW_VAR_H_SCALE\":\"$VW_VAR_H_SCALE\","
	echo "\"VW_VAR_V_SCALE\":\"$VW_VAR_V_SCALE\","
	echo "\"MY_ROW_ID\":\"$MY_ROW_ID\","
	echo "\"THE_ROW_ID\":\"$THE_ROW_ID\","
	echo "\"VW_VAR_POS_MAX_ROW\":\"$VW_VAR_POS_MAX_ROW\","
	echo "\"VW_VAR_POS_MAX_COL\":\"$VW_VAR_POS_MAX_COL\","
	echo "\"VW_VAR_POS_R\":\"$VW_VAR_POS_R\","
	echo "\"VW_VAR_POS_C\":\"$VW_VAR_POS_C\","
	sleep 0.01
	echo "\"VW_VAR_DELAY_KICK\":\"$VW_VAR_DELAY_KICK\","
	echo "\"VW_VAR_TAIL_IDX\":\"$VW_VAR_TAIL_IDX\","
	echo "\"VW_VAR_STRETCH_TYPE\":\"$VW_VAR_STRETCH_TYPE\","
	echo "\"VW_VAR_ROTATE\":\"$VW_VAR_ROTATE\","
	# Button handlers
	echo "\"BTN1_SHORT\":\"$BTN1_SHORT\","
	echo "\"BTN1_LONG\":\"$BTN1_LONG\","
	echo "\"BTN1_SHORT_ON_BOOT\":\"$BTN1_SHORT_ON_BOOT\","
	echo "\"BTN1_LONG_ON_BOOT\":\"$BTN1_LONG_ON_BOOT\","
	echo "\"BTN1_SHORT_ON_ETH_OFF\":\"$BTN1_SHORT_ON_ETH_OFF\","
	echo "\"BTN1_LONG_ON_ETH_OFF\":\"$BTN1_LONG_ON_ETH_OFF\","
	sleep 0.01
	echo "\"BTN2_SHORT\":\"$BTN2_SHORT\","
	echo "\"BTN2_LONG\":\"$BTN2_LONG\","
	echo "\"BTN2_SHORT_ON_BOOT\":\"$BTN2_SHORT_ON_BOOT\","
	echo "\"BTN2_LONG_ON_BOOT\":\"$BTN2_LONG_ON_BOOT\","
	echo "\"BTN2_SHORT_ON_ETH_OFF\":\"$BTN2_SHORT_ON_ETH_OFF\","
	echo "\"BTN2_LONG_ON_ETH_OFF\":\"$BTN2_LONG_ON_ETH_OFF\","
	echo "\"BTN_INIT\":\"$BTN_INIT\","
	echo "\"BTN1_DELAY\":\"$BTN1_DELAY\","
	echo "\"BTN2_DELAY\":\"$BTN2_DELAY\","
	sleep 0.01

	if [ "$IS_HOST" = 'y' ]; then
		_echo_parameters_json_host
	else
		_echo_parameters_json_client
	fi

	# End
	echo "\"_result\":\"pass\""
	echo "}"
	sleep 0.01
}

dump_parameters_json()
{
	echo_parameters_json > lm_params_json
}

dump_parameters()
{
	echo_parameters
	echo_parameters > lm_params
}


# Reference from bashlib
parse_n_exec()
{
	QUERY_STRING="$*"
	if [ -n "${QUERY_STRING}" ]; then 
		# name=value params, separated by either '&' or ';'
		if echo ${QUERY_STRING} | grep '=' >/dev/null ; then
			for Q in $(echo ${QUERY_STRING} | tr ";&" "\012") ; do
				#
				# Clear our local variables
				#
				unset name
				unset value
				unset tmpvalue

				#
				# get the name of the key, and decode it
				#
				name=${Q%%=*}
				#name=$(echo ${name} | \
				#	 sed -e 's/%\(\)/\\\x/g' | \
				#	 tr "+" " ")
				#name=$(echo ${name} | \
				#	 tr -d ".-")
				#name=$(printf ${name})
				name=$(httpd -d ${name})

				#
				# get the value and decode it. This is tricky... printf chokes on
				# hex values in the form \xNN when there is another hex-ish value
				# (i.e., a-fA-F) immediately after the first two. My (horrible)
				# solution is to put a space aftet the \xNN, give the value to
				# printf, and then remove it.
				#
				tmpvalue=${Q#*=}
				#tmpvalue=$(echo ${tmpvalue} | \
				#		 sed -e 's/%\(..\)/\\\x\1 /g')
				# Replace '-' as '\x2D', otherwise following printf won't recongize it.
				#tmpvalue=$(echo ${tmpvalue} | \
				#		 sed -e 's/\(-\)/\\\x2D /g')
				#echo "Intermediate \$value: ${tmpvalue}" 1>&2

				#
				# Iterate through tmpvalue and printf each string, and append it to
				# value
				#
				#for i in ${tmpvalue}; do
				#	g=$(printf ${i})
				#	value="${value}${g}"
				#done
				#value=$(echo ${value})
				value=$(httpd -d ${tmpvalue})

				#eval "export FORM_${name}='${value}'"
				if [ "$name" = 'cmd' ]; then
					# Replace "+" with space
					#cmd=$(echo ${value} | tr "+" "\x20")
					cmd=${value}
					echo "cmd:$cmd"
					#Bruce120510. 
					#Invalid shell $cmd will cause "eval" exit itself and hence kills LM.
					#Run "eval" in background protects LM.
					{ eval "$cmd"; } &
				fi
			done
		else # keywords: foo.cgi?a+b+c
			Q=$(echo ${QUERY_STRING} | tr '+' ' ')
			{ eval "export KEYWORDS='${Q}'"; } &
		fi
	fi

}

set_mtu()
{
	if [ "$SOC_OP_MODE" = '1' ]; then
		return
	fi
	# For SoC supporting Jumbo frame
	if eth_link_is_off ; then
		ifconfig eth0 mtu 1500
	else
		ETH_LINK_MODE=`cat ${MAC_SYS_PATH}/link_mode`
		if [ "$ETH_LINK_MODE" = "1G" ] ; then
			ifconfig eth0 mtu "$JUMBO_MTU"
		fi
	fi
}

# Construct scriptlet
######################################################
# link_off_timer.sh $LM_LINK_OFF_TIMEOUT
echo "#!/bin/sh

sleep \"\$1\"
ast_send_event -1 e_link_off_time_up
" > /usr/local/bin/link_off_timer.sh
chmod a+x /usr/local/bin/link_off_timer.sh

start_link_off_timer()
{
	link_off_timer.sh "$1" &
}
stop_link_off_timer()
{
	pkill link_off_timer 2>/dev/null
}
######################################################
######################################################
# srv_hp_timer.sh $timeout $S_SEARCH_TOKEN
echo "#!/bin/sh

sleep \"\$1\"
ast_send_event -1 e_start_srv_hp_time_up::\$2
" > /usr/local/bin/srv_hp_timer.sh
chmod a+x /usr/local/bin/srv_hp_timer.sh

start_srv_hp_timer()
{
	srv_hp_timer.sh "$1" "$2" &
}
stop_srv_hp_timer()
{
	pkill srv_hp_timer 2>/dev/null
}
######################################################
######################################################
# srv_lp_timer.sh $timeout $S_SEARCH_TOKEN
echo "#!/bin/sh

sleep \"\$1\"
ast_send_event -1 e_start_srv_lp_time_up::\$2
" > /usr/local/bin/srv_lp_timer.sh
chmod a+x /usr/local/bin/srv_lp_timer.sh

start_srv_lp_timer()
{
	srv_lp_timer.sh "$1" "$2" &
}
stop_srv_lp_timer()
{
	pkill srv_lp_timer 2>/dev/null
}
######################################################
######################################################
# lmparam g/s arg1 [arg2]
echo "#!/bin/sh

. /usr/local/bin/bash/utilities.sh

cmd=\"\$1\"
shift
arg1=\"\$1\"
shift
arg2=\"\$*\"

case \"\$cmd\" in
	g)
		__token=\$RANDOM
		if [ -f /var/lm_var\$__token ]; then
		rm -f /var/lm_var\$__token
			sleep 0.01
		fi
		mknod /var/lm_var\$__token p
		sleep 0.01
		( ast_send_event -1 e_var_get::\$arg1::\$__token ) &
		sleep 0.01
		cat /var/lm_var\$__token
		sleep 0.01
		rm -f /var/lm_var\$__token
	;;
	s)
		e e_var_set::\$arg1::\$arg2
	;;
	dump)
		__token=\$RANDOM
		if [ -f /var/lmparams\$__token ]; then
		rm -f /var/lmparams\$__token
			sleep 0.01
		fi
		mknod /var/lmparams\$__token p
		sleep 0.01
		(  ast_send_event -1 e_var_dump::ini::\$__token ) &
		sleep 0.01
		cat /var/lmparams\$__token
		sleep 0.01
		rm -f /var/lmparams\$__token
	;;
	jdump)
		__token=\$RANDOM
		if [ -f /var/lmparams\$__token ]; then
		rm -f /var/lmparams\$__token
			sleep 0.01
		fi
		mknod /var/lmparams\$__token p
		sleep 0.01
		( ast_send_event -1 e_var_dump::json::\$__token ) &
		sleep 0.01
		cat /var/lmparams\$__token
		sleep 0.01
		rm -f /var/lmparams\$__token
	;;
	*)
		echo \"invalid command\"
	;;
esac
" > /usr/local/bin/lmparam
chmod a+x /usr/local/bin/lmparam

_var_dump()
{
	# Parse e_var_dump::${type}::${_token}
	_IFS="$IFS";IFS='::';set -- $*;IFS="$_IFS"
	_type="$3"
	_token="$5"

	# Use PIPE here takes risk to block LM forever.
	if [ -p /var/lmparams$_token ]; then
		case "$_type" in
			json)
				# Bruce151021. Multiple Web UI lmparam jdump refresh kills LM.
				# For unknown reason, above sequence may causes below write
				# into pipe command block forever. Even I cat the pipe manually, LM still blocked.
				# To avoid LM block forever, I put below command into background process.
				# The bonus is the problem disappeared after put this command into background. (!!?)
				# Bruce160310. I believe it is caused by 'broken pipe' that will terminate LM.
				# We MUST put every PIPE write into background to avoid LM crash.
				sleep 0.01
				{ echo_parameters_json; } > /var/lmparams$_token &
				sleep 0.01
			;;
			*)
				# default 'ini'
				sleep 0.01
				{ echo_parameters; } > /var/lmparams$_token &
				sleep 0.01
			;;
		esac
	else
		case "$_type" in
			json)
				echo_parameters_json
			;;
			*)
				# default 'ini'
				echo_parameters
			;;
		esac
	fi
}

_var_get()
{
	# Parse e_var_get::${_var}::${_token}
	_IFS="$IFS";IFS='::';set -- $*;IFS="$_IFS"
	_var="$3"
	_token="$5"
	_value=`eval echo "\\$$_var"`

	# Use PIPE here takes risk to block LM forever.
	if [ -p /var/lm_var$_token ]; then
		sleep 0.01
		#echo "$_var=$_value" > /var/lm_var
		#echo "$_value" > /var/lm_var$_token &
		{ printf "%s" "$_value"; } > /var/lm_var$_token &
		sleep 0.01
	else
		#echo "$_var=$_value"
		echo "$_value"
		if [ "$_var" != "" ]; then
			#echo "$_value" > /var/$_var
			{ printf "%s" "$_value"; } > /var/$_var &
		fi
	fi
}

_var_set()
{
	# Parse e_var_set::${_var}::${_value}
	_IFS="$IFS";IFS='::';set -- $*;IFS="$_IFS"
	_var="$3"
	_value="$5"
	eval "$_var=\"$_value\""
	echo "$_var=$_value"
}
######################################################
