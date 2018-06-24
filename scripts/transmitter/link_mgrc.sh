#!/bin/sh

##
## Copyright (c) 2004-2012
## ASPEED Technology Inc. All Rights Reserved
## Proprietary and Confidential
##
## By using this code you acknowledge that you have signed and accepted
## the terms of the ASPEED SDK license agreement.
##

# 0: This value does not exist.
# 1: GUI screen
# 2: Decode screen
CURRENT_SCREEN='1'
GUI_PICTURE_NAME='default.jpg'
GUI_SHOW_TEXT_INIT=""
GUI_SHOW_TEXT_RUNTIME=""
GUI_PICTURE_DAEMON=""

# OSD globals ##################################################################
# OSD_STR_UUID: a token for tracking OSD_STR session.
OSD_STR_UUID=''
# OSD_PIC_UUID: a token for tracking OSD_PIC session.
OSD_PIC_UUID=''
# OSDSTR_XXX current OSD_STR session setting for CRT
OSDSTR_OSD_Y_START=''
OSDSTR_OSD_MAX_Y_SIZE=''
OSDSTR_OSD_TRANSPARENT=''
OSDSTR_OSD_BKGRND_MASK_EN=''
OSDSTR_OSD_OFF_TIMER=''
OSDSTR_OSD_STR_FILE=''
OSDSTR_OSD_FONT_SIZE=''
OSDSTR_OSD_FONT_COLOR=''
# OSDPIC_XXX current OSD_PIC session setting for CRT
OSDPIC_OSD_Y_START=''
OSDPIC_OSD_MAX_Y_SIZE=''
OSDPIC_OSD_TRANSPARENT=''
OSDPIC_OSD_BKGRND_MASK_EN=''
OSDPIC_OSD_OFF_TIMER=''
OSDPIC_OSD_PIC_FILE=''
OSDPIC_OSD_PIC_OPTION=''
OSDPIC_OSD_POSITION_ALIGN='0'
OSDPIC_OSD_POSITION_X_START_OFFSET='0'
OSDPIC_OSD_POSITION_Y_START_OFFSET='0'
################################################################################

stop_all_service()
{
	unload_soip_c 2>/dev/null

	#if [ -f "/usr/local/bin/remote" ]; then
	#	pkill remote 2>/dev/null
	#	rm -f /etc/gw_ip 2>/dev/null
	#	rm -f /etc/hosts 2>/dev/null
	#fi

	pkill -9 ast_heartbeat 2>/dev/null
	pkill -9 name_service 2> /dev/null
	/sbin/avahi-daemon -k 2>/dev/null
	pkill -9 astclient 2>/dev/null
	rmvhubc.sh "$GWIP"
	stop_i2s_c 2>/dev/null
	stop_ir_c 2>/dev/null
	rmmod videoip 2>/dev/null
	stop_cec  2>/dev/null # GreatWall adds

	pkill GUI 2>/dev/null
	pkill msgd 2>/dev/null
}

# NOTICE: This function run on different process scope. (not in state_machine scope)
# Bruce130123. Now moved into state_machine scope.
do_s_init()
{
	# Bruce150820. Call _switch_to_GUI_screen to init GUI's GUI_SHOW_TEXT_RUNTIME behavior.
	_switch_to_GUI_screen

	echo "Memory Controller Setting:"
	echo "0x1e6e2040:"
	/usr/local/bin/io 0 0x1e6e2040
	echo "0x1e6e0068:"
	/usr/local/bin/io 0 0x1e6e0068

	case $SOC_VER in
		1)
		# If CPU frequency down to 266MHz, the board's memory is bad.
		if { /usr/local/bin/io 0 0x1e6e2024 | grep -iq "44120"; }; then
			echo "ERROR!!!!!! Board Memory Test FAIL!"
			if [ "$STOP_ON_BOOT_TEST_FAIL" = 'y' ]; then
				ast_send_event -1 e_kill
				return 1
			fi
		fi
		;;
		2)
		if ! boot_test_v2.sh; then
			if [ "$STOP_ON_BOOT_TEST_FAIL" = 'y' ]; then
				ast_send_event -1 e_kill
				return 1
			fi
		fi
		;;
		3) # ToDo. for AST1520
			echo "" > /dev/null
		;;
		*)
			echo "" > /dev/null
		;;
	esac

	if [ "$EN_LOG" = 'n' ]; then
		/usr/local/bin/log.sh off
	fi
	if [ "$NO_VIDEO" = 'n' ]; then
		# Overwrite default EDID
		if [ -f "/share/edid_hdmi.txt" ]; then
			cat /share/edid_hdmi.txt > $DISPLAY_SYS_PATH/default_edid_hdmi
		fi
		if [ -f "/share/edid_dvi.txt" ]; then
			cat /share/edid_dvi.txt > $DISPLAY_SYS_PATH/default_edid_dvi
		fi
		if [ -f "/share/edid_vga.txt" ]; then
			cat /share/edid_vga.txt > $DISPLAY_SYS_PATH/default_edid_vga
		fi
	fi
	# Indicate that system is stable.
	if [ "$PWR_LED_TYPE" = 'share_usb' ]; then
		led_off $LED_PWR
	else
		led_on $LED_PWR
	fi

	load_sii9678_drv

	#ast_send_event "$EM_PID" "e_sys_init_ok"
	post_ip_addr
}

_switch_to_GUI_screen()
{
	if [ "$HAS_CRT" = 'n' ]; then
		return
	fi
	# Switch to GUI(console) screen
	# Bruce121214. Should always fire the switch command in case of power saving.
	#if ! { cat "$DISPLAY_SYS_PATH"/screen | grep -q 'message screen'; }; then
		echo "Switch to GUI screen"
		osd_off 0
		echo 1 > "$DISPLAY_SYS_PATH"/screen
	#fi
	if [ "$ACCESS_ON" = 'n' ]; then
		echo "GUI_show_dialog"
		inform_gui_ui_feature_action "GUI show dialog"
	else
		echo "GUI_hide_dialog"
		inform_gui_ui_feature_action "GUI hide dialog"
	fi

    inform_gui_action "GUI_show_picture::$GUI_PICTURE_NAME::$GUI_SHOW_TEXT_RUNTIME"
    CURRENT_SCREEN='1'

	if [ "$GUI_PICTURE_DAEMON" != '' ]; then
		echo "Restart the scritp : $GUI_PICTURE_DAEMON"
		$GUI_PICTURE_DAEMON &
	fi

	if [ "$(( $HDCP_CTS_OPTION & 0x8 ))" -eq '8' ]; then
		echo "Start HDCP 2.2 Testing Mode"
		# Overwrite ACCESS_ON so that test mode won't auto link on boot up.
		ACCESS_ON='n'
		# According to Jerry, enabling dual port causes HDCP 2.2 CTS fail.
		# There is no root cause found yet. It is something related to CRT driver's
		# crt_get_display_edid() behavior. The quick fix is disabling dual output.
		echo 0 > "$DISPLAY_SYS_PATH"/dual_port
		# Enable 1920x1080 60Hz, HDMI, HDCP 2.2, Color Bar
		(
			# sleep 2 in order to avoid GUI garbage.
			sleep 2
			echo 1920 1080 60 1 2 6 > "$DISPLAY_SYS_PATH"/test_mode
		) &
	fi
}

warn()
{
	echo "!!!!! $1 !!!!!"
	#to_s_error
}

to_s_error()
{
	inform_gui_echo "Last state=$STATE event=$event"
	STATE='s_error'
	echo $STATE > $DEVICE_STATUS_FILE
	handle_e_kill
}

handle_e_link_off_time_up()
{
	case "$STATE" in
		s_pre_idle | s_idle | s_search)
			if ! is_all_stopped_lp ; then
				do_stop_srv_lp
			fi
			# Bruce120913. If client is attached to an extra Ethernet switch,
			# client can't detect physical link off. And will hit the avahid
			# can't find node issue. Add an RELOAD_AVAHID here can resolve.
			RELOAD_AVAHID='y'
			_switch_to_GUI_screen
			# Bruce121219. Remove to avoid "bonjour list" fresh.
			#if [ "$STATE" = 's_search' ]; then
			#	# Bruce120917. RctBug#2012091300. Resolve "Eth link off 10mins" issue.
			#	# Reload avahid can resolve this issue, but the side effect
			#	# is user will see "IE bonjour list" fresh.
			#	start_link_off_timer $LM_LINK_OFF_TIMEOUT
			#fi
		;;
		*)
			echo "Ignore e_link_off_time_up"
	esac
}

handle_e_start_srv_hp_time_up()
{
	case "$STATE" in
		s_start_srv_hp)
			#Parse e_start_srv_hp_time_up::S_SEARCH_TOKEN
			_IFS="$IFS";IFS=':';set -- $*;IFS="$_IFS"
			_S_SEARCH_TOKEN=$3
			if [ "$_S_SEARCH_TOKEN" != "$S_SEARCH_TOKEN" ]; then
				# Should ignore this event
				echo "Ignore. Token is not matched $_S_SEARCH_TOKEN vs $S_SEARCH_TOKEN"
				return
			fi
			# We force the s_start_srv_hp state complete with 'e_reconnect' PENDING_EVENT.
			if [ -z "$PENDING_EVENT" ]; then
				PENDING_EVENT='e_reconnect'
			fi
			handle_e_all_init_ok_hp
		;;
		*)
			echo "Ignore e_start_srv_hp_time_up"
	esac
}

handle_e_start_srv_lp_time_up()
{
	case "$STATE" in
		s_start_srv_lp)
			#Parse e_start_srv_lp_time_up::S_SEARCH_TOKEN
			_IFS="$IFS";IFS=':';set -- $*;IFS="$_IFS"
			_S_SEARCH_TOKEN=$3
			if [ "$_S_SEARCH_TOKEN" != "$S_SEARCH_TOKEN" ]; then
				# Should ignore this event
				echo "Ignore. Token is not matched $_S_SEARCH_TOKEN vs $S_SEARCH_TOKEN"
				return
			fi
			# We force the s_start_srv_lp state complete with 'e_reconnect' PENDING_EVENT.
			if [ -z "$PENDING_EVENT" ]; then
				PENDING_EVENT='e_reconnect'
			fi
			handle_e_all_init_ok_lp
		;;
		*)
			echo "Ignore e_start_srv_lp_time_up"
	esac
}

_stop_heartbeat()
{
	pkill ast_heartbeat 2>/dev/null
	HEARTBEAT_RDY='n'
}

# This function will be called as background process. So, the "S_SEARCH_TOKEN" won't be changed by LM.
_resolve_host_ip_addr()
{
	gwip=`get_host_ip_addr`
	if [ "$gwip" = "Unknown host" ]; then
		if [ "$RELOAD_AVAHID" = 'y' ]; then
			avahi-daemon -k 2>/dev/null
			avahi-daemon -D
		fi
		ast_send_event -1 "e_no_gw::${S_SEARCH_TOKEN}"
		return 0
	fi
	ast_send_event -1 "e_ip_remote_got_ex::${S_SEARCH_TOKEN}::$gwip"
	#ast_send_event -1 "e_ip_remote_got::$gwip"
}

handle_e_ip_remote_got_ex()
{
	case "$STATE" in
		s_search)
			# Parse event: e_ip_remote_got_ex::_S_SEARCH_TOKEN::GWIP
			# "expr" take about 0.02 seconds
			#_S_SEARCH_TOKEN=`expr "$*" : 'e_ip_remote_got_ex::\(.*\)::.*'`
			#GWIP=`expr "$*" : 'e_ip_remote_got_ex::.*::\(.*\)'`
			_IFS="$IFS";IFS=':';set -- $*;IFS="$_IFS"
			_S_SEARCH_TOKEN="$3"
			_GWIP="$5"
			# Handle the case of zombie "e_no_gw" or "e_ip_remote_got_ex"
			if [ "$_S_SEARCH_TOKEN" != "$S_SEARCH_TOKEN" ]; then
				echo "Ignore. Token doesn't match $_S_SEARCH_TOKEN vs $S_SEARCH_TOKEN"
				# zombie "e_no_gw" and "e_ip_remote_got_ex" should just die. No need to trigger re-search.
				return
			fi
			# Only save GWIP when _S_SEARCH_TOKEN is valid.
			GWIP=$_GWIP
			# Try to connect the heartbeat. 
			# If connected (got e_heartbeat_init_ok), we get the access right to the gw and we will fire a e_found_gw.
			# Otherwise, we need a timer to go back to s_idle.
			if [ "$MULTICAST_ON" = 'n' ]; then
				ast_heartbeat -c -d "$GWIP" -t "$S_SEARCH_TOKEN" &
			else
				if [ "$SEAMLESS_SWITCH" = 'y' ]; then
					#ast_send_event -1 "e_heartbeat_init_ok"
					ast_heartbeat_no_tcp -c -m -d "$MULTICAST_IP" -t "$S_SEARCH_TOKEN" &
				else
					#ast_heartbeat -c -m -d "$MULTICAST_IP" &
					ast_heartbeat -c -m -d "$GWIP" -t "$S_SEARCH_TOKEN" &
				fi
			fi
			# inform GUI. Replace "e_ip_remote_got"
			inform_gui "e_ip_remote_got::$GWIP::$STATE"
		;;
		*)
			warn "Wrong state?!"
		;;
	esac
}

do_search_gw()
{
	if eth_link_is_off ; then
		stop_link_off_timer
		# RctBug#2012030100. Network link may be down between multiple "to_s_search"
		to_s_pre_idle
		return 0
	fi

	# State machine may loop under this state (s_search) forever,
	# but do_search_gw will be called periodically.
	# So, I add a watchdog here to ensure do_search_gw is called periodically.
	tickle_watchdog

	inform_gui_echo "Connecting to Transmitter..."
	# Bruce120619. New handler to process it asynchronously
	S_SEARCH_TOKEN="$!"
	_resolve_host_ip_addr &
	#Since _resolve_host_ip_addr() runs in background thread, We reset RELOAD_AVAHID here.
	RELOAD_AVAHID='n'
}

to_s_search()
{
	STATE='s_search'
	echo $STATE > $DEVICE_STATUS_FILE
	tickle_watchdog
	#stop watchdog daemon
	stop_watchdog_daemon
	# Stop heartbeat in case it is started
	_stop_heartbeat

	led_blink $LED_LINK

	# reload avahi-daemon to clear the mDNS cache
	# Doing the reload here avoids the daemon keeps reloading under search state. Resolves Bonjor flashing issue.
	# avahi-daemon -k takes 0.03 s
	# avahi-daemon -D takes 0.06 s
	#avahi-daemon -k 2>/dev/null
	#avahi-daemon -D
	# Bruce120718. New SIGUSR2 to flush avahi caches
	pkill -SIGUSR2 avahi-daemon
	PENDING_EVENT=''

	stop_link_off_timer

	if [ "$ACCESS_ON" = 'y' ]; then
		inform_gui_ui_feature_action "GUI_hide_dialog"
		inform_gui_echo "Connecting to Transmitter..."
		# set idle timeout to $LM_LINK_OFF_TIMEOUT seconds later
		start_link_off_timer $LM_LINK_OFF_TIMEOUT
		# Refresh 4-bits dip switch here, so that ch_select get updated under cases like "e_reconnect"
		refresh_4bits_ch
		refresh_ch_params
		do_search_gw
	else
		to_s_pre_idle
	fi
}

to_s_start_srv_hp()
{
	STATE='s_start_srv_hp'
	echo $STATE > $DEVICE_STATUS_FILE
	#tickle watchdog
	tickle_watchdog
	# Reset PENDING_EVENT
	PENDING_EVENT=''
	# It will takes longer than 5 seconds to unload USBoIP under some cases.
	#{ sleep 5; ast_send_event -1 e_start_srv_hp_time_up::$S_SEARCH_TOKEN; } &
	start_srv_hp_timer 8 $S_SEARCH_TOKEN

	if [ $USB_FAST_SWITCH = 'y' ]; then
		if [ $NO_USB = 'n' ] && [ $SHARE_USB = 'n' ]; then
			vhubc.sh $GWIP &
		else
			USBIP_RDY='y'
			USBIP_USER_RDY='y'
		fi
	fi

	if [ $NO_VIDEO = 'n' ]; then
		load_videoip_c &
	else
		#ast_send_event "$EM_PID" 'e_videoip_init_ok'
		VIDEOIP_RDY='y'
		VIDEO_STATE='V_STATE_INITIALIZING'
		ast_send_event "$EM_PID" 'e_video_start_working'
	fi

	if [ $NO_I2S = 'n' ]; then
		start_i2s_c &
	else
		#ast_send_event "$EM_PID" 'e_i2s_init_ok'
		I2S_RDY='y'
	fi

	if [ $NO_KMOIP = 'n' ]; then
		start_kmoip_c
	fi

  # GreatWall adds
  if [ $CEC_GUEST_MODE = 'y' ]; then
		start_cec & 
	fi

	if is_all_started_hp ; then
		ast_send_event "$EM_PID" 'e_all_init_ok_hp'
	fi
}

to_s_start_srv_lp()
{
	STATE='s_start_srv_lp'
	echo $STATE > $DEVICE_STATUS_FILE
	#tickle watchdog
	tickle_watchdog

	# Reset PENDING_EVENT
	PENDING_EVENT=''
	#{ sleep 8; ast_send_event -1 e_start_srv_lp_time_up::$S_SEARCH_TOKEN; } &
	start_srv_lp_timer 8 $S_SEARCH_TOKEN

	if [ $USB_FAST_SWITCH = 'n' ]; then
		if [ $NO_USB = 'n' ] && [ $SHARE_USB = 'n' ]; then
			vhubc.sh $GWIP &
		else
			USBIP_RDY='y'
			USBIP_USER_RDY='y'
		fi
	fi

	if [ $NO_IR = 'n' ]; then
		start_ir_c &
	else
		#ast_send_event "$EM_PID" 'e_iroip_init_ok'
		IR_RDY='y'
	fi

	if [ $NO_COIP = 'n' ]; then
		load_coip_c &
	fi

	if [ $NO_SOIP = 'n' ] && [ "$SOIP_GUEST_ON" = 'n' ]; then
		load_soip_c &
	fi

  # GreatWall adds
  if [ $CEC_GUEST_MODE = 'y' ]; then
		start_cec & 
	fi

	if is_all_started_lp; then
		ast_send_event "$EM_PID" 'e_all_init_ok_lp'
	fi

}

to_s_srv_on()
{
	STATE='s_srv_on'
	echo $STATE > $DEVICE_STATUS_FILE

	PENDING_EVENT=''
	# Why hide again here?
	inform_gui_ui_feature_action "GUI hide dialog"

	if [ $MULTICAST_ON = 'y' ]; then
		pkill igmp_daemon 2> /dev/null
		igmp_daemon.sh $MULTICAST_IP &
	fi
	
	#tickle watchdog
	tickle_watchdog
	#start watchdog daemon
	start_watchdog_daemon

	if [ $NO_VIDEO = 'y' ] || [ "$VIDEO_STATE" = 'V_STATE_OPERATING' ]; then
		led_on $LED_LINK
	fi
}

do_stop_srv_hp()
{
	if [ $MULTICAST_ON = 'y' ]; then
		pkill igmp_daemon 2> /dev/null
		igmp_daemon.sh &
	fi

	if [ $USB_FAST_SWITCH = 'y' ]; then
		if [ $NO_USB = 'n' ] && [ $SHARE_USB = 'n' ]; then
			rmvhubc.sh "$GWIP" &
		else
			if [ $NO_USB = 'n' ] && [ $SHARE_USB = 'y' ]; then
				usb_link_off
			fi
			#ast_send_event "$EM_PID" 'e_usbip_stopped'
			USBIP_RDY='n'
			#ast_send_event "$EM_PID" 'e_usbip_user_stopped'
			USBIP_USER_RDY='n'
		fi
	fi

	if [ $NO_VIDEO = 'n' ]; then
		# unloading videoIP driver will switch back to console screen unexpectly. Turn osd off here.
		osd_off 0
		unload_videoip_c
	else
		#ast_send_event "$EM_PID" 'e_videoip_stopped'
		VIDEOIP_RDY='n'
	fi

	if [ $NO_I2S = 'n' ]; then
		stop_i2s_c &
	else
		#ast_send_event "$EM_PID" 'e_i2s_stopped'
		I2S_RDY='n'
	fi

	if [ $NO_KMOIP = 'n' ]; then
		stop_kmoip_c
	fi

	if is_all_stopped_hp ; then 
		ast_send_event -1 'e_all_stopped_hp'
	fi
}

do_stop_srv_lp()
{
	if [ $USB_FAST_SWITCH = 'n' ]; then
		if [ $NO_USB = 'n' ] && [ $SHARE_USB = 'n' ]; then
			rmvhubc.sh "$GWIP" &
		else
			if [ $NO_USB = 'n' ] && [ $SHARE_USB = 'y' ]; then
				usb_link_off
			fi
			#ast_send_event "$EM_PID" 'e_usbip_stopped'
			USBIP_RDY='n'
			#ast_send_event "$EM_PID" 'e_usbip_user_stopped'
			USBIP_USER_RDY='n'
		fi
	fi

	if [ $NO_IR = 'n' ]; then
		stop_ir_c &
	else
		#ast_send_event "$EM_PID" 'e_iroip_stopped'
		IR_RDY='n'
	fi

	if [ $NO_COIP = 'n' ]; then
		unload_coip_c &
	fi

  #"GreatWall adds"
  if [ $CEC_GUEST_MODE = 'y' ]; then
		stop_cec &
	fi  

	if [ $NO_SOIP = 'n' ] && [ "$SOIP_GUEST_ON" = 'n' ]; then
		unload_soip_c
	fi

	if [ $NO_PWRBTN = 'n' ]; then
		# Turn off remote power status LED
		ast_send_event -1 e_pwr_status_chg_0
	fi

	if is_all_stopped_lp ; then 
		ast_send_event -1 'e_all_stopped_lp'
	fi
}

#do_stop_srv()
#{
#	if [ $MULTICAST_ON = 'y' ]; then
#		pkill igmp_daemon 2> /dev/null
#		igmp_daemon.sh &
#	fi
#	
#	if [ $NO_USB = 'n' ]; then
#		rmvhubc.sh "$GWIP" &
#	else
#		if [ $SHARE_USB = 'y' ]; then
#			usb_link_off
#		fi
#		#ast_send_event "$EM_PID" 'e_usbip_stopped'
#		USBIP_RDY='n'
#		#ast_send_event "$EM_PID" 'e_usbip_user_stopped'
#		USBIP_USER_RDY='n'
#	fi
#
#	if [ $NO_I2S = 'n' ]; then
#		stop_i2s_c &
#	else
#		#ast_send_event "$EM_PID" 'e_i2s_stopped'
#		I2S_RDY='n'
#	fi
#
#	if [ $NO_IR = 'n' ]; then
#		stop_ir_c &
#	else
#		#ast_send_event "$EM_PID" 'e_iroip_stopped'
#		IR_RDY='n'
#	fi
#
#	if [ $NO_VIDEO = 'n' ]; then
#		# unloading videoIP driver will switch back to console screen unexpectly. Turn osd off here.
#		osd_off 0
#		unload_videoip_c
#	else
#		#ast_send_event "$EM_PID" 'e_videoip_stopped'
#		VIDEOIP_RDY='n'
#	fi
#
#	if [ $NO_COIP = 'n' ]; then
#		unload_coip_c &
#	fi
#
#	if [ $NO_SOIP = 'n' ] && [ "$SOIP_GUEST_ON" = 'n' ]; then
#		unload_soip_c
#	fi
#
#	if [ $NO_PWRBTN = 'n' ]; then
#		# Turn off remote power status LED
#		ast_send_event -1 e_pwr_status_chg_0
#	fi
#}

to_s_idle()
{
	STATE='s_idle'
	echo $STATE > $DEVICE_STATUS_FILE
	tickle_watchdog
	#start watchdog daemon
	start_watchdog_daemon

	led_off $LED_LINK
	
	if eth_link_is_off ; then
		inform_gui_echo "Network link is down"
	else

		if [ -n "$PENDING_EVENT" ]; then
			case "$PENDING_EVENT" in
				e_reconnect)
					e e_reconnect
				;;
				*)
					warn "Unknown pending event $PENDING_EVENT"
				;;
			esac
		fi

		inform_gui "Press the link button to connect"
	fi

	# Reset PENDING_EVENT
	PENDING_EVENT=''
}

to_s_pre_idle()
{
	STATE='s_pre_idle'
	echo $STATE > $DEVICE_STATUS_FILE
	#tickle watchdog
	tickle_watchdog

	# Reset the S_SEARCH_TOKEN. S_SEARCH_TOKEN is generated from "last background pid"
	S_SEARCH_TOKEN=''
	# Reset PENDING_EVENT
	PENDING_EVENT=''

	if [ $MULTICAST_ON = 'y' ]; then
		igmp_leave_daemon.sh $MULTICAST_IP &
	fi

	if [ "$ACCESS_ON" = 'y' ]; then
		# For the case when Ethernet link OFF, but LM still want to reconnect after link ON.
		# Switch back to GUI earlier (then 15 sec) when entered s_pre_idle state
		start_link_off_timer 5
	else
		if ! is_all_stopped_lp ; then
			do_stop_srv_lp
		fi
		# Switch to GUI(console) screen
		_switch_to_GUI_screen
	fi
	inform_gui "Press the link button to connect"

	if is_all_stopped_hp && is_all_stopped_lp ; then
		to_s_idle
	fi
}


#video_shrink_update()
#{
#	# Following code is not used anymore. Just return
#	return
#
#	# set shrink only when video service is in operating state
#	if !( [ "$STATE" = 's_srv_on' ] && [ "$VIDEO_STATE" = 'V_STATE_OPERATING' ] ); then
#		return
#	fi
#
#	# Shrink only in 1080P mode
#	if ! [ "$VIDEO_MODE" = 'V_MODE_1080P' ]; then
#		return
#	fi
#
#	if [ "$VIDEO_SHRINK" = 'y' ] \
#	    && ! video_shrink_is_on ;
#	then
#		video_shrink_set 2
#	elif [ "$VIDEO_SHRINK" = 'n' ] \
#	    && video_shrink_is_on ;
#	then
#		video_shrink_set 1
#	fi
#}

set_kmoip_export_conf()
{
	local CONFIG_FILE="/etc/usbip/usbip_export.conf"
	local _busid
	local _port

	for _busid in $USB_DISABLE_CLASSES; do
		echo "class $_busid no_auto_export" >> $CONFIG_FILE
	done

	if [ "$KMOIP_PORTS" = 'all' ]; then
		echo "kmoip all" >> $CONFIG_FILE
		echo ""
		return
	fi
	
	for _port in $KMOIP_PORTS; do
		case $_port in
			1)
				for _busid in $USB_P1_BUSID; do
					echo "kmoip $_busid" >> $CONFIG_FILE
				done
			;;
			2)
				for _busid in $USB_P2_BUSID; do
					echo "kmoip $_busid" >> $CONFIG_FILE
				done
			;;
			3)
				for _busid in $USB_P3_BUSID; do
					echo "kmoip $_busid" >> $CONFIG_FILE
				done
			;;
			4)
				for _busid in $USB_P4_BUSID; do
					echo "kmoip $_busid" >> $CONFIG_FILE
				done
			;;
			5)
				for _busid in $USB_P5_BUSID; do
					echo "kmoip $_busid" >> $CONFIG_FILE
				done
			;;
			*)
				echo "not supported"
			;;
		esac
	done
	
	echo "" >> $CONFIG_FILE
}

set_usbip_export_conf()
{
	local CONFIG_FILE="/etc/usbip/usbip_export.conf"
	local _tmp

	echo "enable_auto_export=yes" > $CONFIG_FILE
	echo "server file /etc/vhub_host_ip" >> $CONFIG_FILE
	# auto_export or no_auto_export
	echo "policy=$USB_DEFAULT_POLICY" >> $CONFIG_FILE
	# auto_export or no_auto_export
	echo "if_interface_conflict=$USB_CONFLICT_POLICY" >> $CONFIG_FILE

	for _tmp in $USB_DISABLE_CLASSES; do
		echo "class $_tmp no_auto_export" >> $CONFIG_FILE
	done

	for _tmp in $USB_ENABLE_CLASSES; do
		echo "class $_tmp auto_export" >> $CONFIG_FILE
	done

	for _tmp in $USB_DISABLE_DEVICES; do
		echo "device $_tmp no_auto_export" >> $CONFIG_FILE
	done

	for _tmp in $USB_ENABLE_DEVICES; do
		echo "device $_tmp auto_export" >> $CONFIG_FILE
	done

	echo "" >> $CONFIG_FILE
}

handle_e_sys_init_ok()
{
	if [ "$STATE" = 's_init' ]; then
		#if [ "$EN_VIDEO_WALL" = 'y' ]; then
		#	# reduce the response time of long press to 0.5 sec (default is 2 sec)
		#	echo 50 > "$GPIO_SYS_PATH"/button_link/delay
		#	echo 50 > "$GPIO_SYS_PATH"/button_pairing/delay
		#fi
		# Initialize flags
		USBIP_RDY='n'
		USBIP_USER_RDY='n'
		VIDEOIP_RDY='n'
		HEARTBEAT_RDY='n'
		I2S_RDY='n'
		IR_RDY='n'
		PENDING_EVENT=''

		if [ -f "$DISPLAY_SYS_PATH"/logo ]; then
			echo 0 > $DISPLAY_SYS_PATH/logo
		fi

		if [ "$NO_VIDEO" = 'n' ]; then
			if [ "$SOC_OP_MODE" -ge '2' ]; then
				echo "$V_DUAL_PORT" > $DISPLAY_SYS_PATH/dual_port
			fi
			if [ "$V_IGNORE_CTS7_33" = 'y' ]; then
				echo 1 > $DISPLAY_SYS_PATH/ignore_cts7_33
			fi
			load_videoip_driver_c
			if [ "$HDCP2_GLOBAL_CONSTANT" != 'unavailable' ]; then
				echo "$HDCP2_GLOBAL_CONSTANT" > $VIDEO_SYS_PATH/hdcp2_global_constant
			fi
			if [ "$HDCP2_RX_ID" != 'unavailable' ]; then
				echo "$HDCP2_RX_ID" > $VIDEO_SYS_PATH/receiver_id
			fi
#			if [ "$HDCP2_RX_CERT" != 'unavailable' ]; then
#				echo "$HDCP2_RX_CERT" > $VIDEO_SYS_PATH/hdcp2_rx_cert
#			fi
			if [ "$HDCP2_RX_CERT_DATA" != 'unavailable' ]; then
				echo "$HDCP2_RX_CERT_DATA" > $VIDEO_SYS_PATH/hdcp2_rx_cert_data
			fi
			if [ "$HDCP2_RX_CERT_SIG" != 'unavailable' ]; then
				echo "$HDCP2_RX_CERT_SIG" > $VIDEO_SYS_PATH/hdcp2_rx_cert_sig
			fi
			if [ "$HDCP2_RX_PRIVATE_KEY_CRT" != 'unavailable' ]; then
				echo "$HDCP2_RX_PRIVATE_KEY_CRT" > $VIDEO_SYS_PATH/hdcp2_rx_private_key_crt
			fi
			if [ "$SOC_OP_MODE" -ge "3" ]; then
				echo "$V_OUTPUT_TIMING_CONVERT" > $VIDEO_SYS_PATH/output_timing_convert
				echo "$V_HDMI_HDR_MODE" > $VIDEO_SYS_PATH/hdmi_hdr_mode
			fi
			echo $EDID_USE > /sys/devices/platform/videoip/edid_use
			echo "$V_1080I_TO_720P" > $VIDEO_SYS_PATH/force_1080i_to_720p
			echo "$V_SRC_UNAVAILABLE_TIMEOUT" > $VIDEO_SYS_PATH/src_unavailable_timeout
			echo "$V_DBG_MODE" > $VIDEO_SYS_PATH/videoip_debug
			cp -f ./V$SOC_OP_MODE/* . 2>/dev/null
		fi
		
		# Always load SoIP under SOIP_GUEST_ON mode.
		if [ $NO_SOIP = 'n' ] && [ "$SOIP_GUEST_ON" = 'y' ]; then
			load_soip_c &
		fi
		if [ $NO_PWRBTN = 'n' ]; then
			enable_remote_ctrl_button &
		fi
		
		# Bruce140313. usbip export config may be used by both USBoIP and KMoIP
		set_usbip_export_conf
		if [ $NO_KMOIP = 'n' ]; then
			# Bruce140401. We should only set kmoip_ports export policy under KMoIP enabled case.
			# Otherwise, HID won't export to USBoIP when KMoIP is disabled (due to the setting.)
			set_kmoip_export_conf
			echo $KMOIP_HOTKEYS > $KMOIP_SYS_PATH/hotkey
			echo $KMOIP_TOKEN_INTERVAL > $KMOIP_SYS_PATH/token_interval
		fi

  # GreatWall adds
	  if [ $CEC_GUEST_MODE = 'y' ]; then
			start_cec & 
		fi
		
		igmp_daemon.sh &
		
		to_s_search
	fi
}

_link_on_off()
{
	if [ "$ACCESS_ON" = 'y' ]; then
		handle_e_stop_link
	else
		handle_e_reconnect
	fi
}

#_link_on_off()
#{
#	#_link_on_off is a link command, set ACCESS_ON to y will toggle it to stop
#	#set ACCESS_ON to n will toggle it to link, STATE factors are taken care of in it
#
#	# Save the state into flash
#	if [ "$ACCESS_ON" = 'y' ]; then
#		ACCESS_ON='n'
#		#astparam s astaccess n
#	else
#		ACCESS_ON='y'
#		#astparam s astaccess y
#	fi
#	
#	if [ "$STATE" = 's_idle' ]; then
#		# Refresh 4-bits dip switch here, so that user can do "button link off -> change channel -> button link on".
#		#refresh_ch_params
#		#to_s_search
#		# Bruce110421. Use to_s_idle instead so that IDLE_TIMEOUT can be refreshed.
#		to_s_idle
#	elif [ "$STATE" = 's_search' ]; then
#		inform_gui_echo "Stop searching for the Transmitter"
#		# Bruce101116. There is a race condition where e_no_gw is fired after e_reconnect under s_search state.
#		# Under this case, if the state machine go directly to to_s_stop_srv ==> to_s_idle ==> to_s_search,
#		# The redundent e_no_gw will be handled under s_search state which cause client state machine confused.
#		# When it happens, ast_hearbeat is running and may be attached to host, but client state machine staies
#		# in s_search state, so that client will never connect to host.
#		# To resolve this issue, we force state machine to s_idle state (with ACCESS_ON='n') and send a
#		# e_reconnect event here if necessary. This way, the e_reconnect event will append after the redundent e_no_gw
#		# event. And the redundent e_no_gw event will be handle under s_idle state (will be ignored). Then the appended
#		# e_reconnect event will trigger new connection.
#		# Bruce120720. This workaround is no longer needed because of the usage of S_SEARCH_TOKEN.
#		# Bruce believe this workaround is buggy.
#		#if [ "$ACCESS_ON" = 'y' ]; then
#		#	ast_send_event -1 e_reconnect
#		#fi
#		ACCESS_ON='n'
#		to_s_stop_srv
#	elif [ "$STATE" = 's_start_srv' ]; then
#		inform_gui_echo "Stop the link while attaching"
#		#to_s_stop_srv
#		# Bruce110407. If drivers are not loaded yet and we call to_s_stop_srv, the driver will fail to unload.
#		# Hence state machine will stock in s_stop_srv forever. 
#		# To resolve this issue, we resend e_reconnect or e_stop_link event.
#		if [ "$ACCESS_ON" = 'y' ]; then
#			ast_send_event -1 e_reconnect
#		else
#			ast_send_event -1 e_stop_link
#		fi
#	elif [ "$STATE" = 's_srv_on' ]; then
#		inform_gui_echo "Stop the link"
#		to_s_stop_srv
#		warn "Wrong state?!"
#	fi
#}

handle_e_button_link()
{
	if [ "$IGNORE_E_BUTTON_LINK" = 'y' ]; then
		return
	fi

	if [ "$STATE" = 's_idle' ] && eth_link_is_off && [ "$BTN1_SHORT_ON_ETH_OFF" != 'e_btn_ignore' ]; then
		handle_"$BTN1_SHORT_ON_ETH_OFF"
		return
	fi

	handle_"$BTN1_SHORT"
}

handle_e_button_pairing()
{
	if [ "$STATE" = 's_idle' ] && eth_link_is_off && [ "$BTN2_SHORT_ON_ETH_OFF" != 'e_btn_ignore' ]; then
		handle_"$BTN2_SHORT_ON_ETH_OFF"
		return
	fi

	handle_"$BTN2_SHORT"
}

handle_e_button_pairing_1()
{
	if [ "$STATE" = 's_idle' ] && eth_link_is_off && [ "$BTN2_LONG_ON_ETH_OFF" != 'e_btn_ignore' ]; then
		handle_"$BTN2_LONG_ON_ETH_OFF"
		return
	fi

	handle_"$BTN2_LONG"
}

_switch_to_decode_screen()
{
	if [ "$HAS_CRT" = 'n' ]; then
		return
	fi

	if [ "$GUI_PICTURE_DAEMON" != '' ]; then
	  echo "Kill the script : $GUI_PICTURE_DAEMON"
	  ps -A | grep $GUI_PICTURE_DAEMON | kill `awk '{print $1}'`
	fi

	CURRENT_SCREEN='2'
	inform_gui_action "GUI_show_picture::../usr/local/bin/mono.jpg::$GUI_SHOW_TEXT_RUNTIME"
	echo 2 > "$DISPLAY_SYS_PATH"/screen

	osd_recover
}

_switch_console_screen()
{
	if [ "$HAS_CRT" = 'n' ]; then
		return
	fi

	SCREEN=`cat $DISPLAY_SYS_PATH/screen`
	if [ "$SCREEN" = '[2] decode screen' ]; then
		_switch_to_GUI_screen
		echo 1 > '/sys/devices/platform/ftgmac/net_debug'
	else
		echo 2 > "$DISPLAY_SYS_PATH"/screen
		echo 0 > '/sys/devices/platform/ftgmac/net_debug'
	fi
}

handle_e_vw_delay_kick()
{
	_IFS="$IFS";IFS='_';set -- $*;IFS="$_IFS"
	# Parse e_vw_delay_kick_XXXX
	VW_VAR_DELAY_KICK=$5
	
	#VW_VAR_DELAY_KICK=`expr "$*" : 'e_vw_delay_kick_\([[:digit:]]\{1,\}\)'`
	if [ -z "$VW_VAR_DELAY_KICK" ]; then
		VW_VAR_DELAY_KICK='0'
	fi
	echo "$VW_VAR_DELAY_KICK" > "$VIDEO_SYS_PATH"/delay_dequeue
	astparam s vw_delay_kick "$VW_VAR_DELAY_KICK"
	astparam save
}

handle_e_vwbtn_menu_on()
{
	if [ "$EN_VIDEO_WALL" = 'y' ]; then
		if [ "$VIDEO_STATE" = 'V_STATE_OPERATING' ]; then
			vw_osd 'btn_menu_on'
		else
			{ sleep 1; ast_send_event -1 e_vwbtn_menu_on; } &
		fi
	fi
}

handle_e_vwbtn_menu_cancel()
{
	if [ "$EN_VIDEO_WALL" = 'y' ]; then
		vw_osd 'btn_menu_cancel'
	fi
}

handle_e_vwbtn_menu_off()
{
	if [ "$EN_VIDEO_WALL" = 'y' ]; then
		vw_osd 'btn_menu_off'
	fi
}

handle_e_vwbtn_toggle()
{
	if [ "$EN_VIDEO_WALL" = 'y' ]; then
		vw_osd 'btn_toggle'
	fi
}

handle_e_button_link_1()
{
	if [ "$IGNORE_E_BUTTON_LINK_1" = 'y' ]; then
		return
	fi

	if [ "$STATE" = 's_idle' ] && eth_link_is_off && [ "$BTN1_LONG_ON_ETH_OFF" != 'e_btn_ignore' ]; then
		handle_"$BTN1_LONG_ON_ETH_OFF"
		return
	fi

	handle_"$BTN1_LONG"
}

#handle_e_button_link_2()
#{
#	if [ $SHARE_USB = 'y' ]; then
#		_switch_console_screen
#	fi
#}

handle_e_usb_request_on_off()
{
	if [ $NO_USB = 'n' ] && [ $SHARE_USB = 'y' ]; then
		#usb_link_on_off
		usb_request_on_off
	#else
	#	_switch_console_screen
	fi
}

handle_e_kill()
{
	rm -f "$PIPE" 2>/dev/null
	kill "$EM_PID"
	
	stop_all_service
	led_off $LED_LINK

	disable_watchdog
	to_mfg_mode

	exit 0;
}

handle_e_no_gw()
{
	#Parse e_no_gw::S_SEARCH_TOKEN
	_IFS="$IFS";IFS=':';set -- $*;IFS="$_IFS"
	_t=$3
	
	#_t=`expr "$*" : 'e_no_gw::\(.*\)'`
	if [ "$S_SEARCH_TOKEN" != "$_t" ]; then
		echo "Ignore. Token doesn't match $_t vs $S_SEARCH_TOKEN"
		return
	fi

	case "$STATE" in
		s_search)
			#inform_gui_echo "Trying again.."
			do_search_gw
		;;
		s_pre_idle | s_idle)
			# handleing e_reconnect on s_search state will get redundent e_no_gw under s_idle state.
			return
		;;
		*)
			warn "Wrong state?!"
		;;
	esac
}

handle_e_found_gw()
{
	_e=$*
	# Parse e_found_gw::$S_SEARCH_TOKEN
	_IFS="$IFS";IFS=':';set -- $*;IFS="$_IFS"
	_S_SEARCH_TOKEN=$3

	if [ "$_S_SEARCH_TOKEN" != "$S_SEARCH_TOKEN" ]; then
		# Should ignore this event
		echo "Ignore. Token is not matched $_S_SEARCH_TOKEN vs $S_SEARCH_TOKEN"
		return
	fi

	case "$STATE" in
		s_search)
			if is_all_stopped_hp ; then
				stop_link_off_timer
				inform_gui_echo "Found $GWIP, starting link.."
				to_s_start_srv_hp
			else
				# Wait for is_all_stopped_hp being true.
				PENDING_EVENT=$_e
			fi
		;;
		*)
			warn "Wrong state?!"
		;;
	esac
}

igmp_leave_immediately()
{
	if [ $MULTICAST_ON = 'y' ]; then 
		igmp -t 0x17 -m $MULTICAST_IP 2>&1 1>/dev/null
		igmp -t 0x17 -m $MULTICAST_IP 2>&1 1>/dev/null
		igmp -t 0x17 -m $MULTICAST_IP 2>&1 1>/dev/null
	fi
}

handle_e_reconnect()
{
	igmp_leave_immediately
	case "$STATE" in
		s_idle | s_search)
			ACCESS_ON='y'
			to_s_search
		;;
		s_pre_idle | s_start_srv_hp | s_start_srv_lp)
			PENDING_EVENT='e_reconnect'
		;;
		s_srv_on)
			#_switch_to_decode_screen
			ACCESS_ON='y'
			do_stop_srv_hp
			to_s_search
		;;
		*)
			warn "Wrong state?!"
		;;
	esac
}

handle_e_chg_hostname()
{
	/sbin/avahi-daemon -k 2>/dev/null
	#start avahi-daemon
	#hostname=`astparam g asthostname`
	#if [ "$hostname" = "\"asthostname\" not defined" ]; then
	#	hostname=ast-client
	#fi
	# The $HOSTNAME_ID is now decided in refresh_hostname_params()
	refresh_4bits_ch
	refresh_hostname_params
	hostname="${HOSTNAME_PREFIX}-client${HOSTNAME_ID}"

	echo "hostname=$hostname"
	astsetname $hostname
	echo $hostname > /etc/hostname
	hostname -F /etc/hostname

	/sbin/avahi-daemon -D
}

handle_e_stop_link()
{
	case "$STATE" in
		s_pre_idle | s_idle)
			ACCESS_ON='n'
		;;
		s_search)
			ACCESS_ON='n'
			to_s_search
		;;
		s_start_srv_hp | s_start_srv_lp)
			PENDING_EVENT='e_stop_link'
		;;
		s_srv_on)
			ACCESS_ON='n'
			do_stop_srv_hp
			to_s_search
		;;
		*)
			warn "Wrong state?!"
		;;
	esac
}

handle_e_usbip_init_ok()
{
	if [ $NO_USB = 'n' ] && [ "$SHARE_USB" = 'y' ]; then
		usb_handle_e_usbip_init_ok
		return
	fi
	
	USBIP_RDY='y'
	case "$STATE" in
		s_start_srv_lp)
			if [ $USB_FAST_SWITCH = 'n' ] && is_all_started_lp ; then 
				ast_send_event "$EM_PID" 'e_all_init_ok_lp'
			fi
		;;
		s_start_srv_hp)
			if [ $USB_FAST_SWITCH = 'y' ] && is_all_started_hp ; then 
				ast_send_event "$EM_PID" 'e_all_init_ok_hp'
			fi
		;;
		*)
			warn "Wrong state?!"
		;;
	esac
}

handle_e_usbip_user_init_ok()
{
	if [ $NO_USB = 'n' ] && [ "$SHARE_USB" = 'y' ]; then
		usb_handle_e_usbip_user_init_ok
		return
	fi

	USBIP_USER_RDY='y'
	case "$STATE" in
		s_start_srv_lp)
			if [ $USB_FAST_SWITCH = 'n' ] && is_all_started_lp ; then 
				ast_send_event "$EM_PID" 'e_all_init_ok_lp'
			fi
		;;
		s_start_srv_hp)
			if [ $USB_FAST_SWITCH = 'y' ] && is_all_started_hp ; then 
				ast_send_event "$EM_PID" 'e_all_init_ok_hp'
			fi
		;;
		*)
			warn "Wrong state?!"
		;;
	esac
}

handle_e_videoip_init_ok()
{
	VIDEOIP_RDY='y'
	VIDEO_STATE='V_STATE_INITIALIZING'
	
	case "$STATE" in
		s_start_srv_hp)
			if is_all_started_hp ; then 
				ast_send_event "$EM_PID" 'e_all_init_ok_hp'
			fi
		;;
		*)
			warn "Wrong state?!"
		;;
	esac
}

handle_e_i2s_init_ok()
{
	#I2S_RDY='y'

	case "$STATE" in
		s_start_srv_hp)
			# e_i2s_init_ok event may be fired later then unload_i2s. If we set I2S_RDY = y under ANY state, it will confuse LM.
			I2S_RDY='y'
			if is_all_started_hp ; then 
				ast_send_event "$EM_PID" 'e_all_init_ok_hp'
			fi
		;;
		*)
			warn "Wrong state?!"
		;;
	esac
}

handle_e_iroip_init_ok()
{
	IR_RDY='y'

	case "$STATE" in
		s_start_srv_lp)
			if is_all_started_lp ; then 
				ast_send_event "$EM_PID" 'e_all_init_ok_lp'
			fi
		;;
		*)
			warn "Wrong state?!"
		;;
	esac
}

handle_e_heartbeat_init_ok()
{
	# Parse e_heartbeat_init_ok::$S_SEARCH_TOKEN
	_IFS="$IFS";IFS=':';set -- $*;IFS="$_IFS"
	_S_SEARCH_TOKEN=$3

	if [ "$_S_SEARCH_TOKEN" != "$S_SEARCH_TOKEN" ]; then
		# Should ignore this event
		echo "Ignore. Token is not matched $_S_SEARCH_TOKEN vs $S_SEARCH_TOKEN"
		return
	fi
	HEARTBEAT_RDY='y'
	case "$STATE" in
		s_search)
			inform_gui_echo "System connects OK!"
			ast_send_event "$EM_PID" "e_found_gw::${S_SEARCH_TOKEN}"
		;;
		*)
			warn "Wrong state?!"
		;;
	esac
}

handle_e_vhub_heartbeat_init_ok()
{
	if [ $NO_USB = 'n' ] && [ $SHARE_USB = 'y' ]; then
		usb_handle_e_vhub_heartbeat_init_ok
	fi
}

handle_e_all_init_ok_hp()
{
	case "$STATE" in
		s_start_srv_hp)
			if [ -n "$PENDING_EVENT" ]; then
				case "$PENDING_EVENT" in
					e_reconnect)
						ACCESS_ON='y'
						do_stop_srv_hp
						to_s_search
						stop_srv_hp_timer
					;;
					e_stop_link)
						ACCESS_ON='n'
						do_stop_srv_hp
						to_s_search
						stop_srv_hp_timer
					;;
					*)
						warn "Unknown pending event $PENDING_EVENT"
					;;
				esac
			elif is_all_stopped_lp ; then
				#inform_gui_echo "All high priority services initialized..."
				stop_srv_hp_timer
				to_s_start_srv_lp
			else
				# Stop/Start Low priority service after high priority service loaded.
				stop_srv_hp_timer
				start_srv_hp_timer 10 $S_SEARCH_TOKEN
				do_stop_srv_lp
			fi
		;;
		*)
			warn "Wrong state?!"
		;;
	esac
}

handle_e_all_init_ok_lp()
{
	case "$STATE" in
		s_start_srv_lp)
			if [ -n "$PENDING_EVENT" ]; then
				case "$PENDING_EVENT" in
					e_reconnect)
						ACCESS_ON='y'
						do_stop_srv_hp
						to_s_search
						stop_srv_lp_timer
					;;
					e_stop_link)
						ACCESS_ON='n'
						do_stop_srv_hp
						to_s_search
						stop_srv_lp_timer
					;;
					*)
						warn "Unknown pending event $PENDING_EVENT"
					;;
				esac
			else
				inform_gui_echo "Connected - waiting for video source"
				stop_srv_lp_timer
				to_s_srv_on
			fi
		;;
		*)
			warn "Wrong state?!"
		;;
	esac
}

#auto_shrink_video()
#{
#	# Shrink only in 1080P mode
#	#return
#	sleep 5
#	if [ "$VIDEO_MODE" = 'V_MODE_1080P' ];
#	then
#		video_shrink_update
#		#video_shrink_set 2
#	#lif video_shrink_is_on ; then
#	#video_shrink_set 1
#	fi
#}

post_config()
{
	if [ "$EN_VIDEO_WALL" = 'y' ]; then
		vw_enable
	fi

	_switch_to_decode_screen
}

handle_e_video_start_working()
{
	case "$STATE" in
		s_start_srv_hp | s_start_srv_lp)
			VIDEO_STATE='V_STATE_OPERATING'
			# Turn off "Wait for Video Input" msg. Should delay 2 sec so that the up coming OSD has chance to cancel it.
			osd_set_to "VIDEO_START_DECODE" 8
			#led_on $LED_LINK # Turn LED on on entering s_srv_on state
			#auto_shrink_video &
			post_config
			if [ "$EN_VIDEO_WALL" = 'y' ]; then
				vw_osd 'btn_menu_recover'
			fi
		;;
		s_srv_on)
			VIDEO_STATE='V_STATE_OPERATING'
			# Turn off "Wait for Video Input" msg. Should delay 2 sec so that the up coming OSD has chance to cancel it.
			osd_set_to "VIDEO_START_DECODE" 8
			# We stay in s_srv_on state, but stop blinking the LED_LINK
			led_on $LED_LINK
			#auto_shrink_video &
			post_config
			if [ "$EN_VIDEO_WALL" = 'y' ]; then
				vw_osd 'btn_menu_recover'
			fi
		;;
		*)
			warn "Wrong state?!"
		;;
	esac
}

handle_e_video_stop_working()
{
	case "$STATE" in
		s_start_srv_hp | s_start_srv_lp)
			VIDEO_STATE='V_STATE_RESETING'
		;;
		s_srv_on)
			VIDEO_STATE='V_STATE_RESETING'
			# We stay in s_srv_on state, but start blinking the LED_LINK
			led_blink $LED_LINK
		;;
		s_pre_idle | s_idle)
			VIDEO_STATE='V_STATE_RESETING'
		;;
		*)
			warn "Wrong state?!"
		;;
	esac
}

is_all_started_hp()
{
	if [ "$USB_FAST_SWITCH" = 'y' ]; then
		if [ "$USBIP_RDY" = 'n' ] || [ "$USBIP_USER_RDY" = 'n' ]; then
			return 1
		fi
	fi
	if [ "$VIDEOIP_RDY" = 'y' ] && [ "$I2S_RDY" = 'y' ]; then
		return 0
	fi
	return 1
}

is_all_started_lp()
{
	if [ "$USB_FAST_SWITCH" = 'n' ]; then
		if [ "$USBIP_RDY" = 'n' ] || [ "$USBIP_USER_RDY" = 'n' ]; then
			return 1
		fi
	fi
	if [ "$IR_RDY" = 'y' ]; then
		return 0
	fi
	return 1
}

is_all_stopped_hp()
{
	if [ "$USB_FAST_SWITCH" = 'y' ]; then
		if [ "$USBIP_RDY" = 'y' ] || [ "$USBIP_USER_RDY" = 'y' ]; then
			return 1
		fi
	fi
	if [ "$VIDEOIP_RDY" = 'n' ] && [ "$I2S_RDY" = 'n' ]; then
		return 0
	fi
	return 1
}

is_all_stopped_lp()
{
	if [ "$USB_FAST_SWITCH" = 'n' ]; then
		if [ "$USBIP_RDY" = 'y' ] || [ "$USBIP_USER_RDY" = 'y' ]; then
			return 1
		fi
	fi
	if [ "$IR_RDY" = 'n' ]; then
		return 0
	fi
	return 1
}

handle_e_usbip_stopped()
{
	if [ $NO_USB = 'n' ] && [ "$SHARE_USB" = 'y' ]; then
		usb_handle_e_usbip_stopped
		return
	fi

	USBIP_RDY='n'
	case "$STATE" in
		*)
			if [ $USB_FAST_SWITCH = 'n' ] && is_all_stopped_lp ; then 
				ast_send_event "$EM_PID" 'e_all_stopped_lp'
			fi
			if [ $USB_FAST_SWITCH = 'y' ] && is_all_stopped_hp ; then 
				ast_send_event "$EM_PID" 'e_all_stopped_hp'
			fi
		;;
	esac
}

handle_e_usbip_user_stopped()
{
	if [ $NO_USB = 'n' ] && [ "$SHARE_USB" = 'y' ]; then
		usb_handle_e_usbip_user_stopped
		return
	fi

	USBIP_USER_RDY='n'
	case "$STATE" in
		*)
			if [ $USB_FAST_SWITCH = 'n' ] && is_all_stopped_lp ; then 
				ast_send_event "$EM_PID" 'e_all_stopped_lp'
			fi
			if [ $USB_FAST_SWITCH = 'y' ] && is_all_stopped_hp ; then 
				ast_send_event "$EM_PID" 'e_all_stopped_hp'
			fi
		;;
	esac
}

handle_e_videoip_stopped()
{
	VIDEOIP_RDY='n'
	VIDEO_STATE='V_STATE_REMOVING'

	case "$STATE" in
		*)
			if is_all_stopped_hp ; then 
				ast_send_event "$EM_PID" 'e_all_stopped_hp'
			fi
		;;
	esac
}

handle_e_i2s_stopped()
{
	I2S_RDY='n'
	case "$STATE" in
		*)
			if is_all_stopped_hp ; then 
				ast_send_event "$EM_PID" 'e_all_stopped_hp'
			fi
		;;
	esac
}

handle_e_iroip_stopped()
{
	IR_RDY='n'
	case "$STATE" in
		*)
			if is_all_stopped_lp ; then 
				ast_send_event "$EM_PID" 'e_all_stopped_lp'
			fi
		;;
	esac
}

#handle_e_heartbeat_stopped()
#{
#	HEARTBEAT_RDY='n'
#	if [ "$STATE" = 's_stop_srv' ]; then
#		#inform_gui_echo "System stopped!"
#		if is_all_stopped ; then 
#			ast_send_event "$EM_PID" 'e_all_stopped'
#		fi
#	elif [ "$STATE" = 's_search' ]; then
#		# Ignore.
#		return
#	else
#		warn "Wrong state?!"
#	fi
#}

handle_e_all_stopped_hp()
{
	case "$STATE" in
		s_idle)
			# Donothing
		;;
		s_pre_idle)
			if is_all_stopped_lp; then
				to_s_idle
			fi
		;;
		s_search)
			if [ -n "$PENDING_EVENT" ]; then
				case "$PENDING_EVENT" in
					e_found_gw*)
						handle_e_found_gw "$PENDING_EVENT"
					;;
					*)
						warn "Unknown pending event $PENDING_EVENT"
					;;
				esac
			fi
		;;
		*)
			warn "Wrong state?!"
		;;
	esac
}

handle_e_all_stopped_lp()
{
	case "$STATE" in
		s_pre_idle)
			if is_all_stopped_hp; then
				to_s_idle
			fi
		;;
		s_start_srv_hp)
			if is_all_started_hp; then
				handle_e_all_init_ok_hp
			fi
		;;
		s_search | s_idle)
			# Don't care
		;;
		*)
			warn "Wrong state?!"
		;;
	esac
}

handle_e_no_heartbeat()
{
	# Parse e_no_heartbeat::$S_SEARCH_TOKEN
	_IFS="$IFS";IFS=':';set -- $*;IFS="$_IFS"
	_S_SEARCH_TOKEN=$3

	if [ "$_S_SEARCH_TOKEN" != "$S_SEARCH_TOKEN" ]; then
		# Should ignore this event
		echo "Ignore. Token is not matched. $_S_SEARCH_TOKEN vs $S_SEARCH_TOKEN"
		return
	fi

	inform_gui_echo "NO Heartbeat!!"

	# Bruce120619. LM may receive redundent e_no_heartbeat event. kill ast_heartbeat here to ensure ast_heartbeat is always stopped.
	# Bruce120724. S_SEARCH_TOKEN should resolve this issue. Comment it for now.
	#pkill ast_heartbeat 2>/dev/null

	case "$STATE" in
		s_search)
			# We got this event when the gateway restart itself and assign the same IP address after reboot.
			# Client will find the gw again, but failed to connect to the heartbeat socket, and then fired e_no_heartbeat event.
			# We try again under this condition.
			# Bruce100805. above issue is mDNS cache issue. Reloading avahi-daemon resolves this issue.
			inform_gui_echo "Transmitter is not ready yet"
			if [ "$ACCESS_ON" = 'y' ]; then
				do_search_gw
			fi
		;;
		s_start_srv_hp | s_start_srv_lp)
			if [ "$PENDING_EVENT" != 'e_stop_link' ]; then
				PENDING_EVENT='e_reconnect'
			fi
		;;
		s_srv_on)
			do_stop_srv_hp
			to_s_search
		;;
		*)
			warn "Wrong state?!"
		;;
	esac
}

handle_e_no_vhub_heartbeat()
{
	# Ignore this event no matter NO_USB is 'y' or 'n'.
	if [ $SHARE_USB = 'n' ]; then
		return
	fi

	echo "NO VHUB Heartbeat!!"
	if [ "$SHARE_USB_STATE" = 's_srv_on' ] || [ "$SHARE_USB_STATE" = 's_start_srv' ]; then
		usb_link_off
	elif [ "$SHARE_USB_STATE" = 's_search' ]; then
		# This is the case where host's vhub_heartbeat is not ready yet.
		echo "VHUB is not ready yet"
		sleep 1
		if [ "$USB_ACCESS_ON" = 'y' ]; then
			usb_to_s_search
		fi
	else
		warn "Wrong state?!"
	fi
}

handle_e_no_usb()
{
	if [ "$STATE" = 's_idle' ]; then
		if [ "$NO_USB" = 'n' ]; then
			NO_USB='y'
		else
			NO_USB='n'
		fi
		#inform_gui_echo "NO_USB=$NO_USB"
	else
		warn "Please go back to IDLE state first"
	fi
}

handle_e_no_video()
{
	if [ "$STATE" = 's_idle' ]; then
		if [ "$NO_VIDEO" = 'n' ]; then
			NO_VIDEO='y'
		else
			NO_VIDEO='n'
		fi
		#inform_gui_echo "NO_VIDEO=$NO_VIDEO"
	else
		warn "Please go back to IDLE state first"
	fi
}

handle_e_video_hdcp_fail()
{
	osd_set_to "VIDEO_HDCP_FAIL" 3
}

handle_e_video_unsupported_mode()
{
	osd_set_to "VIDEO_UNSUPPORTED_MODE" 10
}

handle_e_video_unsupported_refresh_rate()
{
	osd_set_to "VIDEO_UNSUPPORTED_REFRESH_RATE" 10
}


handle_e_video_mode_changed()
{
	# It is unnecessary now.
	return
	osd_set_to "VIDEO_MODE_CHANGED" 25
}

handle_e_no_i2s()
{
	if [ "$STATE" = 's_idle' ]; then
		if [ "$NO_I2S" = 'n' ]; then
			NO_I2S='y'
		else
			NO_I2S='n'
		fi
		#inform_gui_echo "NO_I2S=$NO_I2S"
	else
		warn "Please go back to IDLE state first"
	fi
}

handle_e_no_ir()
{
	if [ "$STATE" = 's_idle' ]; then
		if [ "$NO_IR" = 'n' ]; then
			NO_IR='y'
		else
			NO_IR='n'
		fi
		#inform_gui_echo "NO_IR=$NO_IR"
	else
		warn "Please go back to IDLE state first"
	fi
}

handle_e_debug()
{
	dump_parameters

	# set -x is annoying. Disable it.
	return

	if [ "$DBG" = '0' ]; then
		DBG='1'
		set -x
	else
		DBG='0'
		set +x
	fi
}

handle_e_debug_json()
{
	dump_parameters_json
}

handle_e_video_stat()
{
	case "$1" in
		e_video_stat_client_read_edid)
			#osd_set_to "VIDEO_CLIENT_READ_EDID"
		;;
		e_video_stat_client_wait_host_info)
			#osd_set_to "VIDEO_CLIENT_WAIT_HOST_INFO"
			case "$STATE" in
				s_start_srv_hp | s_start_srv_lp | s_srv_on)
					inform_gui_echo "Connected - Waiting for video source"
				;;
				*)
				;;
			esac
		;;
		e_video_stat_mode_1080p)
			VIDEO_MODE='V_MODE_1080P'
		;;
		e_video_stat_mode_non_1080p)
			VIDEO_MODE='V_MODE_NON_1080P'
		;;
		*)
		;;
	esac
}

handle_e_ip_got()
{
	# Parse e_ip_got::MY_IP
	_IFS="$IFS";IFS=':';set -- $*;IFS="$_IFS"
	MY_IP=$3
	
	case "$IP_MODE" in
	autoip)
		# I statically set the value here.
		MY_NETMASK='255.255.0.0'
		MY_GATEWAYIP='169.254.0.254'
		route add default gw '169.254.0.254'
	;;
	dhcp)
		#MY_NETMASK and $MY_GATEWAYIP will be assigned in /usr/share/udhcpc/default.script
		;;
	static)
		MY_NETMASK="$NETMASK"
		MY_GATEWAYIP="$GATEWAYIP"
	;;
	*)
	;;
	esac
	#MY_IP=`expr "$*" : 'e_ip_got::\(.*\)'`

	if [ "$STATE" = 's_init' ]; then
		tickle_watchdog
		if [ "$SOC_OP_MODE" -ge '2' ]; then
			tcp.sh
			set_mtu
		else
			tcp.sh
		fi

		# The $HOSTNAME_ID is now decided in init_share_param_from_flash()
		hostname="${HOSTNAME_PREFIX}-client${HOSTNAME_ID}"
		ast_send_event "$EM_PID" "e_name_id::$HOSTNAME_ID"
		inform_gui_ui_feature_action "GUI hide dialog"

		echo "hostname:$hostname"
		astsetname $hostname
		echo $hostname > /etc/hostname
		hostname -F /etc/hostname

		mknod /dev/videoip c 250 0

		route add -net 224.0.0.0 netmask 240.0.0.0 dev eth0
		# Force IGMP version to Version 2
		echo 2 > /proc/sys/net/ipv4/conf/eth0/force_igmp_version

		#avahi-daemon will be restarted in to_s_idle(). Skip here.
		#Bruce120718. Now use -SIGUSR2 to flush mDNS, so load avahi-d here.
		avahi-daemon -D
		name_service -tclient

		# Start inetd
		inetd &
		httpd -h /www &
		# Start telnetd
		start_telnetd
		# it is harmless to send igmp leave in background because the switch will query immediately after a leave received.
		igmp_leave_all &
		inform_gui_ui_feature_action "GUI refresh node"
		ast_send_event -1 "e_sys_init_ok"
	fi
}

handle_e_button_remote_ctrl()
{
	if [ "$1" = "e_button_remote_ctrl_pressed" ]; then
		echo "e_button_remote_ctrl_pressed"
		ast_send_event -1 'msg_pwr_ctrl_press'
	elif [ "$1" = "e_button_remote_ctrl_released" ]; then
		echo "e_button_remote_ctrl_released"
		ast_send_event -1 'msg_pwr_ctrl_release'
	fi
}

handle_e_button_chg_ch()
{
	refresh_4bits_ch
	# re-connect is not enough. We need to save the ch_select in case of board reboot.
	astparam s ch_select "${CH0}${CH1}${CH2}${CH3}"

	# Bruce120618. Multicast IP need to be saved, too.
	astparam s multicast_ip "${MULTICAST_IP_PREFIX}${CH0}.${CH1}${CH2}${CH3}"

	astparam save
	ast_send_event -1 'e_reconnect'
}

handle_e_start_usb()
{
	if [ $NO_USB = 'n' ] && [ $SHARE_USB = 'y' ]; then
		usb_link_on
	fi
}

handle_e_stop_usb()
{
	if [ $NO_USB = 'n' ] && [ $SHARE_USB = 'y' ]; then
		usb_link_off
	fi
}

handle_e_vw_enable()
{
	# Parse e_vw_enable_${VW_VAR_MAX_ROW}_${VW_VAR_MAX_COLUMN}_${VW_VAR_ROW}_${VW_VAR_COLUMN}
	_IFS="$IFS";IFS='_';set -- $*;IFS="$_IFS"
	_VW_VAR_MAX_ROW=$4
	_VW_VAR_MAX_COLUMN=$5
	_VW_VAR_ROW=$6
	_VW_VAR_COLUMN=$7
	
	#_VW_VAR_MAX_ROW=`expr "$1" : 'e_vw_enable_\([[:alnum:]]\{1,\}\)_[[:alnum:]]\{1,\}_[[:alnum:]]\{1,\}_[[:alnum:]]\{1,\}'`
	#_VW_VAR_MAX_COLUMN=`expr "$1" : 'e_vw_enable_[[:alnum:]]\{1,\}_\([[:alnum:]]\{1,\}\)_[[:alnum:]]\{1,\}_[[:alnum:]]\{1,\}'`
	#_VW_VAR_ROW=`expr "$1" : 'e_vw_enable_[[:alnum:]]\{1,\}_[[:alnum:]]\{1,\}_\([[:alnum:]]\{1,\}\)_[[:alnum:]]\{1,\}'`
	#_VW_VAR_COLUMN=`expr "$1" : 'e_vw_enable_[[:alnum:]]\{1,\}_[[:alnum:]]\{1,\}_[[:alnum:]]\{1,\}_\([[:alnum:]]\{1,\}\)'`

	if [ -z "$_VW_VAR_MAX_ROW" ]; then
		_VW_VAR_MAX_ROW='x'
	fi
	if [ -z "$_VW_VAR_MAX_COLUMN" ]; then
		_VW_VAR_MAX_COLUMN='x'
	fi
	if [ -z "$_VW_VAR_ROW" ]; then
		_VW_VAR_ROW='x'
	fi
	if [ -z "$_VW_VAR_COLUMN" ]; then
		_VW_VAR_COLUMN='x'
	fi
	if [ "$_VW_VAR_MAX_ROW" = 'd' ]; then
		VW_VAR_MAX_ROW="$MY_ROW_ID"
	elif [ "$_VW_VAR_MAX_ROW" != 'x' ]; then
		VW_VAR_MAX_ROW="$_VW_VAR_MAX_ROW"
	fi
	if [ "$_VW_VAR_MAX_COLUMN" = 'd' ]; then
		VW_VAR_MAX_COLUMN="$MY_ROW_ID"
	elif [ "$_VW_VAR_MAX_COLUMN" != 'x' ]; then
		VW_VAR_MAX_COLUMN="$_VW_VAR_MAX_COLUMN"
	fi

	if [ "$_VW_VAR_ROW" = 'd' ]; then
		VW_VAR_ROW='0'
	elif [ "$_VW_VAR_ROW" != 'x' ]; then
		VW_VAR_ROW="$_VW_VAR_ROW"
		#VW_VAR_ROW=`expr $VW_VAR_ROW % \( $VW_VAR_MAX_ROW + 1 \)`
		VW_VAR_ROW=$(( $VW_VAR_ROW % ($VW_VAR_MAX_ROW + 1) ))
		if [ -z "$VW_VAR_ROW" ]; then
			VW_VAR_ROW='0'
		fi
	fi
	if [ "$_VW_VAR_COLUMN" = 'd' ]; then
		VW_VAR_COLUMN='0'
	elif [ "$_VW_VAR_COLUMN" != 'x' ]; then
		VW_VAR_COLUMN="$_VW_VAR_COLUMN"
		#VW_VAR_COLUMN=`expr $VW_VAR_COLUMN % \( $VW_VAR_MAX_COLUMN + 1 \)`
		VW_VAR_COLUMN=$(( $VW_VAR_COLUMN % ($VW_VAR_MAX_COLUMN + 1) ))
		if [ -z "$VW_VAR_COLUMN" ]; then
			VW_VAR_COLUMN='0'
		fi
	fi
	#VW_VAR_LAYOUT=`expr $VW_VAR_MAX_ROW + 1`x`expr $VW_VAR_MAX_COLUMN + 1`
	VW_VAR_LAYOUT="$(( $VW_VAR_MAX_ROW + 1 ))x$(( $VW_VAR_MAX_COLUMN + 1 ))"

	vw_enable
	./astparam s vw_max_row ${VW_VAR_MAX_ROW}
	./astparam s vw_max_column ${VW_VAR_MAX_COLUMN}
	./astparam s vw_row ${VW_VAR_ROW}
	./astparam s vw_column ${VW_VAR_COLUMN}
	./astparam save
}

handle_e_vw_moninfo()
{
	# Parse e_vw_moninfo_${VW_VAR_MONINFO_HA}_${VW_VAR_MONINFO_HT}_${VW_VAR_MONINFO_VA}_${VW_VAR_MONINFO_VT}
	_IFS="$IFS";IFS='_';set -- $*;IFS="$_IFS"
	VW_VAR_MONINFO_HA=$4
	VW_VAR_MONINFO_HT=$5
	VW_VAR_MONINFO_VA=$6
	VW_VAR_MONINFO_VT=$7
	
	#VW_VAR_MONINFO_HA=`expr "$1" : 'e_vw_moninfo_\([[:digit:]]\{1,\}\)_[[:digit:]]\{1,\}_[[:digit:]]\{1,\}_[[:digit:]]\{1,\}'`
	#VW_VAR_MONINFO_HT=`expr "$1" : 'e_vw_moninfo_[[:digit:]]\{1,\}_\([[:digit:]]\{1,\}\)_[[:digit:]]\{1,\}_[[:digit:]]\{1,\}'`
	#VW_VAR_MONINFO_VA=`expr "$1" : 'e_vw_moninfo_[[:digit:]]\{1,\}_[[:digit:]]\{1,\}_\([[:digit:]]\{1,\}\)_[[:digit:]]\{1,\}'`
	#VW_VAR_MONINFO_VT=`expr "$1" : 'e_vw_moninfo_[[:digit:]]\{1,\}_[[:digit:]]\{1,\}_[[:digit:]]\{1,\}_\([[:digit:]]\{1,\}\)'`
	echo "HA=$VW_VAR_MONINFO_HA HT=$VW_VAR_MONINFO_HT VA=$VW_VAR_MONINFO_VA VT=$VW_VAR_MONINFO_VT"
	if [ -z "$VW_VAR_MONINFO_HA" ]; then
		VW_VAR_MONINFO_HA='0'
	fi
	if [ -z "$VW_VAR_MONINFO_HT" ]; then
		VW_VAR_MONINFO_HT='0'
	fi
	if [ -z "$VW_VAR_MONINFO_VA" ]; then
		VW_VAR_MONINFO_VA='0'
	fi
	if [ -z "$VW_VAR_MONINFO_VT" ]; then
		VW_VAR_MONINFO_VT='0'
	fi
	echo "$VW_VAR_MONINFO_HA $VW_VAR_MONINFO_HT $VW_VAR_MONINFO_VA $VW_VAR_MONINFO_VT" > "$DISPLAY_SYS_PATH"/vw_frame_comp

	astparam s vw_moninfo_ha "$VW_VAR_MONINFO_HA"
	astparam s vw_moninfo_ht "$VW_VAR_MONINFO_HT"
	astparam s vw_moninfo_va "$VW_VAR_MONINFO_VA"
	astparam s vw_moninfo_vt "$VW_VAR_MONINFO_VT"
	astparam save
}

# New method takes only 0.04s
handle_action()
{
	# Action string format: "act_XXXXXXXX_ActionString" where XXXXXXXX is the IP of requester
	# Parse "act_XXXXXXXX_ActionString"
	_IFS="$IFS";IFS='_';set -- $*;IFS="$_IFS"
	# Remove act_XXXXXXXX
	shift 2
	# ActionString: osd_on_${_osd_num}
	# _osd_num will be $3 if exists
	_osd_num="$3"
	# Start construct $_action_str
	# 'echo $*' is actually different from 'echo "$*"'
	# When "$*" is used, $* will be converted to a string first then echo out.
	# "$*" will generate a string by connecting $n with $IFS.
	# When $* is used, 'echo' will use $IFS to echo out $* one by one.
	_IFS="$IFS";IFS='_';_action_str="$*";IFS="$_IFS"
	case "$_action_str" in
		osd_on_?*)
			echo "_osd_num=$_osd_num"
			osd_on "$_osd_num" 5
		;;
		e_start_usb*)
			ast_send_event -1 e_start_usb
		;;
		e_stop_usb*)
			ast_send_event -1 e_stop_usb
		;;
		*)
			if [ -n "$_action_str" ]; then
				# treat any ActionString as event
				ast_send_event -1 "$_action_str"
			fi
		;;
	esac
	return
	# Old method takes 0.10s in worst case
#	# Action string format: "act_XXXXXXXX_ActionString" where XXXXXXXX is the IP of requester
#	_action_str=`expr "$1" : 'act_........_\(.*\)'`
#	
#	if echo "$_action_str" | grep -q "^osd_on_" ; then
#		_osd_num=`expr "$1" : 'act_........_osd_on_\(.\)'`
#		echo "_osd_num=$_osd_num"
#		osd_on "$_osd_num"
#		osd_off 5
#	elif echo "$_action_str" | grep -q '^e_start_usb' ; then
#		ast_send_event -1 e_start_usb
#	elif echo "$_action_str" | grep -q '^e_stop_usb' ; then
#		ast_send_event -1 e_stop_usb
#	elif [ -n "$_action_str" ]; then
#		# treat any ActionString as event
#		ast_send_event -1 "$_action_str"
#	fi
}

handle_e_eth_link_off()
{
	set_mtu

	case "$STATE" in
		s_init)
			#  Actually, eth_link_off event can be ignored under s_init state. 
			return
		;;
		*)
			# In client, link off triggers reconnect (stop and start link).
			# link manager will double check eth link state in "s_search" state.
			# If eth link is off in "s_search" state, LM should try not sending out packets and go to "s_idle" state.
			if [ "$ACCESS_ON" = 'y' ]; then
				handle_e_reconnect
			else
				handle_e_stop_link
			fi
		;;
	esac
}

handle_e_eth_link_on()
{
	# Double check
	if eth_link_is_off ; then
		inform_gui_echo "Network link is down again"
		return
	fi
	set_mtu

	case "$STATE" in
		s_init)
			# Bug. avahi-daemon is loaded when to_s_init(). We should not kill avahi-daemon under this state.
			#  Actually, eth_link_on event can be ignored under s_init state. 
			return
		;;
		s_pre_idle | s_idle)
			# Bug. avahi-daemon may not respond to astresname if eth link on/off frequently.
			# To resolve this issue, we try to reload avahi-daemon on each eth link on.
			#avahi-daemon -k
			#avahi-daemon -D
			RELOAD_AVAHID='y'
			if [ "$ACCESS_ON" = 'y' ]; then
				handle_e_reconnect
			else
				inform_gui "Press the link button to connect"
			fi
		;;
		s_search)
			# e_eth_link_on will be fired again when calling "set_mtu", 
			# so we got e_eth_link_on event under s_search state.
		;;
		*)
			warn "Wrong state?!"
		;;
	esac
}

handle_e_osd_test()
{
	for _num in '0' '1' '2' '3' '4' '5' '6' '7' '8' '9' '10'; do
		osd_on $_num 3
	done
}

# Used to save the host's position layout for WebUI. Set once when performing basic setup.
handle_e_vw_pos_layout()
{
	# Parse e_vw_pos_layout_${_VW_VAR_POS_MAX_ROW}_${_VW_VAR_POS_MAX_COL}
	_IFS="$IFS";IFS='_';set -- $*;IFS="$_IFS"
	_VW_VAR_POS_MAX_ROW=$5
	_VW_VAR_POS_MAX_COL=$6
	
	#_VW_VAR_POS_MAX_ROW=`expr "$1" : 'e_vw_pos_layout_\([[:alnum:]]\{1,\}\)_[[:alnum:]]\{1,\}'`
	#_VW_VAR_POS_MAX_COL=`expr "$1" : 'e_vw_pos_layout_[[:alnum:]]\{1,\}_\([[:alnum:]]\{1,\}\)'`
	if [ -z "$_VW_VAR_POS_MAX_ROW" ]; then
		_VW_VAR_POS_MAX_ROW='x'
	fi
	if [ -z "$_VW_VAR_POS_MAX_COL" ]; then
		_VW_VAR_POS_MAX_COL='x'
	fi

	if [ "$_VW_VAR_POS_MAX_ROW" = 'd' ]; then
		VW_VAR_POS_MAX_ROW="$VW_VAR_POS_IDX"
	elif [ "$_VW_VAR_POS_MAX_ROW" != 'x' ]; then
		VW_VAR_POS_MAX_ROW="$_VW_VAR_POS_MAX_ROW"
	fi

	if [ "$_VW_VAR_POS_MAX_COL" = 'd' ]; then
		VW_VAR_POS_MAX_COL="$VW_VAR_POS_IDX"
	elif [ "$_VW_VAR_POS_MAX_COL" != 'x' ]; then
		VW_VAR_POS_MAX_COL="$_VW_VAR_POS_MAX_COL"
	fi

	astparam s vw_pos_max_row "$VW_VAR_POS_MAX_ROW"
	astparam s vw_pos_max_col "$VW_VAR_POS_MAX_COL"
	astparam save
}

handle_e_vw_refresh_pos_idx()
{
	# Parse e_vw_refresh_pos_idx_${_VW_VAR_POS_R}_${_VW_VAR_POS_C}
	_IFS="$IFS";IFS='_';set -- $*;IFS="$_IFS"
	_VW_VAR_POS_R=$6
	_VW_VAR_POS_C=$7
	
	#_VW_VAR_POS_R=`expr "$*" : 'e_vw_refresh_pos_idx_\([[:alnum:]]\{1,\}\)_[[:alnum:]]\{1,\}'`
	#_VW_VAR_POS_C=`expr "$*" : 'e_vw_refresh_pos_idx_[[:alnum:]]\{1,\}_\([[:alnum:]]\{1,\}\)'`
	if [ -z "$_VW_VAR_POS_R" ]; then
		_VW_VAR_POS_R='x'
	fi
	if [ -z "$_VW_VAR_POS_C" ]; then
		_VW_VAR_POS_C='x'
	fi
	if [ "$_VW_VAR_POS_R" = 'd' ]; then
		VW_VAR_POS_R="$MY_ROW_ID"
	elif [ "$_VW_VAR_POS_R" != 'x' ]; then
		VW_VAR_POS_R="$_VW_VAR_POS_R"
	fi
	if [ "$_VW_VAR_POS_C" = 'd' ]; then
		VW_VAR_POS_C='VW_VAR_COLUMN'
	elif [ "$_VW_VAR_POS_C" != 'x' ]; then
		VW_VAR_POS_C="$_VW_VAR_POS_C"
	fi

	VW_VAR_POS_IDX="r${VW_VAR_POS_R}c${VW_VAR_POS_C}"
	./astparam s vw_pos_idx ${VW_VAR_POS_IDX}
	./astparam save
}

handle_rXcX()
{
	# Seperate rXcX and from event
	_IFS="$IFS";IFS='_';set -- $*;
	_idx="$1"
	shift
	_e="$*"
	IFS="$_IFS"
	# Parse rXcX
	_IFS="$IFS";IFS='rc';set -- $_idx;IFS="$_IFS"
	_R="$2"
	_C="$3"
	#_R=`expr "$*" : 'r\([[:digit:]x]\{1,\}\)c[[:digit:]x]\{1,\}_.*'`
	#_C=`expr "$*" : 'r[[:digit:]x]\{1,\}c\([[:digit:]x]\{1,\}\)_.*'`
	if [ "$_R" = 'x' ]; then
		_R="$VW_VAR_POS_R"
	fi
	if [ "$_C" = 'x' ]; then
		_C="$VW_VAR_POS_C"
	fi
	_idx="r${_R}c${_C}"
	if [ "$_idx" = "$VW_VAR_POS_IDX" ]; then
		#_e=`expr "$*" : 'r[[:digit:]x]\{1,\}c[[:digit:]x]\{1,\}_\(.*\)'`
		ast_send_event -1 "$_e"
	fi
}
handle_e_vw_v_shift_d()
{
	# Parse e_vw_v_shift_d_${VW_VAR_V_SHIFT}
	_IFS="$IFS";IFS='_';set -- $*;IFS="$_IFS"
	VW_VAR_V_SHIFT=$6
	
	#VW_VAR_V_SHIFT=`expr "$*" : 'e_vw_v_shift_d_\([[:digit:]]\{1,\}\)'`
	if [ -z "$VW_VAR_V_SHIFT" ]; then
		VW_VAR_V_SHIFT='0'
	fi
	echo "$VW_VAR_V_SHIFT" > "$DISPLAY_SYS_PATH"/vw_v_shift
	astparam s vw_v_shift "$VW_VAR_V_SHIFT"
	astparam save
}
handle_e_vw_v_shift_u()
{
	# Parse e_vw_v_shift_u_${VW_VAR_V_SHIFT}
	_IFS="$IFS";IFS='_';set -- $*;IFS="$_IFS"
	VW_VAR_V_SHIFT=$6
	
	#VW_VAR_V_SHIFT=`expr "$*" : 'e_vw_v_shift_u_\([[:digit:]]\{1,\}\)'`
	if [ -z "$VW_VAR_V_SHIFT" ]; then
		VW_VAR_V_SHIFT='0'
	fi
	if [ "$VW_VAR_V_SHIFT" != '0' ]; then
		VW_VAR_V_SHIFT="-$VW_VAR_V_SHIFT"
	fi
	echo "$VW_VAR_V_SHIFT" > "$DISPLAY_SYS_PATH"/vw_v_shift
	astparam s vw_v_shift "$VW_VAR_V_SHIFT"
	astparam save
}
handle_e_vw_h_shift_r()
{
	# Parse e_vw_h_shift_r_${VW_VAR_H_SHIFT}
	_IFS="$IFS";IFS='_';set -- $*;IFS="$_IFS"
	VW_VAR_H_SHIFT=$6
	
	#VW_VAR_H_SHIFT=`expr "$*" : 'e_vw_h_shift_r_\([[:digit:]]\{1,\}\)'`
	if [ -z "$VW_VAR_H_SHIFT" ]; then
		VW_VAR_H_SHIFT='0'
	fi
	echo "$VW_VAR_H_SHIFT" > "$DISPLAY_SYS_PATH"/vw_h_shift
	astparam s vw_h_shift "$VW_VAR_H_SHIFT"
	astparam save
}
handle_e_vw_h_shift_l()
{
	# Parse e_vw_h_shift_l_${VW_VAR_H_SHIFT}
	_IFS="$IFS";IFS='_';set -- $*;IFS="$_IFS"
	VW_VAR_H_SHIFT=$6
	
	#VW_VAR_H_SHIFT=`expr "$*" : 'e_vw_h_shift_l_\([[:digit:]]\{1,\}\)'`
	if [ -z "$VW_VAR_H_SHIFT" ]; then
		VW_VAR_H_SHIFT='0'
	fi
	if [ "$VW_VAR_H_SHIFT" != '0' ]; then
		VW_VAR_H_SHIFT="-$VW_VAR_H_SHIFT"
	fi
	echo "$VW_VAR_H_SHIFT" > "$DISPLAY_SYS_PATH"/vw_h_shift
	astparam s vw_h_shift "$VW_VAR_H_SHIFT"
	astparam save
}
handle_e_vw_h_scale()
{
	# Parse e_vw_h_scale_${VW_VAR_H_SCALE}
	_IFS="$IFS";IFS='_';set -- $*;IFS="$_IFS"
	VW_VAR_H_SCALE=$5
	
	#VW_VAR_H_SCALE=`expr "$*" : 'e_vw_h_scale_\([[:digit:]]\{1,\}\)'`
	if [ -z "$VW_VAR_H_SCALE" ]; then
		VW_VAR_H_SCALE='0'
	fi
	echo "$VW_VAR_H_SCALE $VW_VAR_V_SCALE" > "$DISPLAY_SYS_PATH"/vw_scale_up
	astparam s vw_h_scale "$VW_VAR_H_SCALE"
	astparam save
}
handle_e_vw_v_scale()
{
	# Parse e_vw_v_scale_${VW_VAR_V_SCALE}
	_IFS="$IFS";IFS='_';set -- $*;IFS="$_IFS"
	VW_VAR_V_SCALE=$5
	
	#VW_VAR_V_SCALE=`expr "$*" : 'e_vw_v_scale_\([[:digit:]]\{1,\}\)'`
	if [ -z "$VW_VAR_V_SCALE" ]; then
		VW_VAR_V_SCALE='0'
	fi
	echo "$VW_VAR_H_SCALE $VW_VAR_V_SCALE" > "$DISPLAY_SYS_PATH"/vw_scale_up
	astparam s vw_v_scale "$VW_VAR_V_SCALE"
	astparam save
}

handle_e_vw_stretch_type()
{
	if [ "$SOC_OP_MODE" -lt "3" ]; then
		return
	fi
	# Parse e_vw_stretch_type_${VW_VAR_STRETCH_TYPE}
	_IFS="$IFS";IFS='_';set -- $*;IFS="$_IFS"
	VW_VAR_STRETCH_TYPE=$5
	
	if [ -z "$VW_VAR_STRETCH_TYPE" ]; then
		VW_VAR_STRETCH_TYPE='2'
	fi
	echo "$VW_VAR_STRETCH_TYPE" > "$DISPLAY_SYS_PATH"/vw_stretch_type
	astparam s vw_stretch_type "$VW_VAR_STRETCH_TYPE"
	astparam save
}

handle_e_vw_rotate()
{
	if [ "$SOC_OP_MODE" -lt "3" ]; then
		return
	fi
	# Parse e_vw_rotate_${VW_VAR_ROTATE}
	_IFS="$IFS";IFS='_';set -- $*;IFS="$_IFS"
	VW_VAR_ROTATE=$4
	
	if [ -z "$VW_VAR_ROTATE" ]; then
		VW_VAR_ROTATE='0'
	fi
	echo "$VW_VAR_ROTATE" > "$DISPLAY_SYS_PATH"/vw_rotate
	astparam s vw_rotate "$VW_VAR_ROTATE"
	astparam save
}

handle_e_vw_reset_to_pos()
{
	# Parse e_vw_reset_to_pos_${_VW_VAR_MAX_ROW}_${_VW_VAR_MAX_COLUMN}
	_IFS="$IFS";IFS='_';set -- $*;IFS="$_IFS"
	_VW_VAR_MAX_ROW=$6
	_VW_VAR_MAX_COLUMN=$7
	
	#_VW_VAR_MAX_ROW=`expr "$*" : 'e_vw_reset_to_pos_\([[:alnum:]]\{1,\}\)_[[:alnum:]]\{1,\}'`
	#_VW_VAR_MAX_COLUMN=`expr "$*" : 'e_vw_reset_to_pos_[[:alnum:]]\{1,\}_\([[:alnum:]]\{1,\}\)'`
	if [ -z "$_VW_VAR_MAX_ROW" ]; then
		_VW_VAR_MAX_ROW='x'
	fi
	if [ -z "$_VW_VAR_MAX_COLUMN" ]; then
		_VW_VAR_MAX_COLUMN='x'
	fi

	if [ "$_VW_VAR_MAX_ROW" = 'd' ]; then
		VW_VAR_MAX_ROW="$MY_ROW_ID"
	elif [ "$_VW_VAR_MAX_ROW" != 'x' ]; then
		VW_VAR_MAX_ROW="$_VW_VAR_MAX_ROW"
	fi
	if [ "$_VW_VAR_MAX_COLUMN" = 'd' ]; then
		VW_VAR_MAX_COLUMN="$MY_ROW_ID"
	elif [ "$_VW_VAR_MAX_COLUMN" != 'x' ]; then
		VW_VAR_MAX_COLUMN="$_VW_VAR_MAX_COLUMN"
	fi

	VW_VAR_ROW='0' # multiple host video wall always 0
	VW_VAR_COLUMN="$VW_VAR_POS_C"
	#VW_VAR_MONINFO_HA='0'
	#VW_VAR_MONINFO_HT='0'
	#VW_VAR_MONINFO_VA='0'
	#VW_VAR_MONINFO_VT='0'
	VW_VAR_H_SHIFT='0'
	VW_VAR_V_SHIFT='0'
	VW_VAR_H_SCALE='0'
	VW_VAR_V_SCALE='0'
	VW_VAR_DELAY_KICK='0'
	VW_VAR_ROTATE='0'
	VW_VAR_STRETCH_TYPE='2'
	#echo "$VW_VAR_H_SHIFT" > "$DISPLAY_SYS_PATH"/vw_h_shift
	#echo "$VW_VAR_V_SHIFT" > "$DISPLAY_SYS_PATH"/vw_v_shift
	#echo "$VW_VAR_H_SCALE $VW_VAR_V_SCALE" > "$DISPLAY_SYS_PATH"/vw_scale_up
	#echo "$VW_VAR_DELAY_KICK" > "$VIDEO_SYS_PATH"/delay_dequeue
	vw_enable
	astparam s vw_max_row "$VW_VAR_MAX_ROW"
	astparam s vw_max_column "$VW_VAR_MAX_COLUMN"
	astparam s vw_row "$VW_VAR_ROW"
	astparam s vw_column "$VW_VAR_COLUMN"
	astparam s vw_h_shift "$VW_VAR_H_SHIFT"
	astparam s vw_v_shift "$VW_VAR_V_SHIFT"
	astparam s vw_h_scale "$VW_VAR_H_SCALE"
	astparam s vw_v_scale "$VW_VAR_V_SCALE"
	astparam s vw_delay_kick "$VW_VAR_DELAY_KICK"
	astparam s vw_rotate "$VW_VAR_ROTATE"
	astparam s vw_stretch_type "$VW_VAR_STRETCH_TYPE"
	astparam save
}

# For single host mode
handle_e_vw_reset_to_pos_s()
{
	# Parse e_vw_reset_to_pos_s_${_VW_VAR_MAX_ROW}_${_VW_VAR_MAX_COLUMN}
	_IFS="$IFS";IFS='_';set -- $*;IFS="$_IFS"
	_VW_VAR_MAX_ROW=$7
	_VW_VAR_MAX_COLUMN=$8
	
	#_VW_VAR_MAX_ROW=`expr "$*" : 'e_vw_reset_to_pos_s_\([[:alnum:]]\{1,\}\)_[[:alnum:]]\{1,\}'`
	#_VW_VAR_MAX_COLUMN=`expr "$*" : 'e_vw_reset_to_pos_s_[[:alnum:]]\{1,\}_\([[:alnum:]]\{1,\}\)'`
	if [ -z "$_VW_VAR_MAX_ROW" ]; then
		_VW_VAR_MAX_ROW='x'
	fi
	if [ -z "$_VW_VAR_MAX_COLUMN" ]; then
		_VW_VAR_MAX_COLUMN='x'
	fi

	if [ "$_VW_VAR_MAX_ROW" = 'd' ]; then
		VW_VAR_MAX_ROW="$MY_ROW_ID"
	elif [ "$_VW_VAR_MAX_ROW" != 'x' ]; then
		VW_VAR_MAX_ROW="$_VW_VAR_MAX_ROW"
	fi
	if [ "$_VW_VAR_MAX_COLUMN" = 'd' ]; then
		VW_VAR_MAX_COLUMN="$MY_ROW_ID"
	elif [ "$_VW_VAR_MAX_COLUMN" != 'x' ]; then
		VW_VAR_MAX_COLUMN="$_VW_VAR_MAX_COLUMN"
	fi

	VW_VAR_ROW="$VW_VAR_POS_R"
	VW_VAR_COLUMN="$VW_VAR_POS_C"
	#VW_VAR_MONINFO_HA='0'
	#VW_VAR_MONINFO_HT='0'
	#VW_VAR_MONINFO_VA='0'
	#VW_VAR_MONINFO_VT='0'
	VW_VAR_H_SHIFT='0'
	VW_VAR_V_SHIFT='0'
	VW_VAR_H_SCALE='0'
	VW_VAR_V_SCALE='0'
	VW_VAR_DELAY_KICK='0'
	VW_VAR_ROTATE='0'
	VW_VAR_STRETCH_TYPE='2'
	#echo "$VW_VAR_H_SHIFT" > "$DISPLAY_SYS_PATH"/vw_h_shift
	#echo "$VW_VAR_V_SHIFT" > "$DISPLAY_SYS_PATH"/vw_v_shift
	#echo "$VW_VAR_H_SCALE $VW_VAR_V_SCALE" > "$DISPLAY_SYS_PATH"/vw_scale_up
	#echo "$VW_VAR_DELAY_KICK" > "$VIDEO_SYS_PATH"/delay_dequeue
	vw_enable
	astparam s vw_max_row "$VW_VAR_MAX_ROW"
	astparam s vw_max_column "$VW_VAR_MAX_COLUMN"
	astparam s vw_row "$VW_VAR_ROW"
	astparam s vw_column "$VW_VAR_COLUMN"
	astparam s vw_h_shift "$VW_VAR_H_SHIFT"
	astparam s vw_v_shift "$VW_VAR_V_SHIFT"
	astparam s vw_h_scale "$VW_VAR_H_SCALE"
	astparam s vw_v_scale "$VW_VAR_V_SCALE"
	astparam s vw_delay_kick "$VW_VAR_DELAY_KICK"
	astparam s vw_rotate "$VW_VAR_ROTATE"
	astparam s vw_stretch_type "$VW_VAR_STRETCH_TYPE"
	astparam save
}

handle_e_video_enter_pwr_save()
{
	inform_gui_echo "Connected - Waiting for video source"
	if [ "$V_TURN_OFF_SCREEN_ON_PWR_SAVE" = 'n' ]; then
		# Turn off power save
		echo 0 > "$DISPLAY_SYS_PATH"/power_save
		# Switch to GUI screen for displaying information.
		_switch_to_GUI_screen
		# in case of switching screen racing, we poll the video state again
		if [ `cat "$VIDEO_SYS_PATH"/State` = 'OPERATING' ]; then
			echo 2 > "$DISPLAY_SYS_PATH"/screen
		fi
	fi
}

handle_e_sh()
{
	#_str=`expr "$*" : 'e_sh_\(.*\)'`
	_IFS="$IFS";IFS='_';set -- $*;shift 2;_str="$*";IFS="$_IFS"
	parse_n_exec "$_str"
}

handle_e_sh_jsonp()
{
	#_str=`expr "$*" : 'callback=.+&e_sh_\(.*\)'`
	_IFS="$IFS";IFS='&';set -- $*;shift;_str="$*";IFS="$_IFS"
	_IFS="$IFS";IFS='_';set -- $_str;shift 2;_str="$*";IFS="$_IFS"
	parse_n_exec "$_str"
}

handle_e_pwr_status_chg()
{
	# Parse e_pwr_status_chg_${_on}
	_IFS="$IFS";IFS='_';set -- $*;IFS="$_IFS"
	_on=$5
	
	#_on=`expr "$*" : 'e_pwr_status_chg_\(.\)'`
	echo "$_on" > "${GPIO_SYS_PATH}"/gpio_pwr_status_out/brightness
}

handle_e_button()
{
	case "$*" in
		e_button_link)
			handle_e_button_link
		;;
		e_button_link_1)
			handle_e_button_link_1
		;;
		e_button_pairing)
			handle_e_button_pairing
		;;
		e_button_pairing_1)
			handle_e_button_pairing_1
		;;
		e_button_chg_ch)
			handle_e_button_chg_ch
		;;
		e_button_remote_ctrl_?*)
			handle_e_button_remote_ctrl "$*"
		;;
		*)
		;;
	esac
}

handle_e_vw()
{
	case "$*" in
		e_vw_refresh_pos_idx_?*)
			handle_e_vw_refresh_pos_idx "$*"
		;;
		e_vw_pos_layout_?*)
			handle_e_vw_pos_layout "$*"
		;;
		e_vw_v_shift_u_?*)
			handle_e_vw_v_shift_u "$*"
		;;
		e_vw_v_shift_d_?*)
			handle_e_vw_v_shift_d "$*"
		;;
		e_vw_h_shift_r_?*)
			handle_e_vw_h_shift_r "$*"
		;;
		e_vw_h_shift_l_?*)
			handle_e_vw_h_shift_l "$*"
		;;
		e_vw_h_scale_?*)
			handle_e_vw_h_scale "$*"
		;;
		e_vw_v_scale_?*)
			handle_e_vw_v_scale "$*"
		;;
		e_vw_delay_kick_?*)
			handle_e_vw_delay_kick "$*"
		;;
		e_vw_reset_to_pos_s_?*)
			handle_e_vw_reset_to_pos_s "$*"
		;;
		e_vw_reset_to_pos_?*)
			handle_e_vw_reset_to_pos "$*"
		;;
		e_vw_moninfo_?*)
			handle_e_vw_moninfo "$*"
		;;
		e_vw_enable_?*)
			handle_e_vw_enable "$*"
		;;
		e_vw_stretch_type_?*)
			handle_e_vw_stretch_type "$*"
		;;
		e_vw_rotate_?*)
			handle_e_vw_rotate "$*"
		;;
		*)
			echo "Unknown Video Wall event?! ($*)"
		;;
	esac
}

handle_e_var_dump()
{
	_var_dump "$*"
}

handle_e_var_get()
{
	_var_get "$*"
}

handle_e_var_set()
{
	_var_set "$*"
}

handle_e_gui_show_picture_daemon()
{
	echo "handle_e_gui_show_picture_daemon"

	 _IFS="$IFS";IFS=':';set -- $*;IFS="$_IFS"

	if [ "$3" != '' ]; then
		chmod a+x $3
	fi

	if [ $CURRENT_SCREEN = '2' ]; then
		echo "Set GUI_PICTURE_DAEMON=$3"
		GUI_PICTURE_DAEMON="$3"
	else
		if [ "$GUI_PICTURE_DAEMON" != '' ]; then
			ps -A | grep $GUI_PICTURE_DAEMON | kill `awk '{print $1}'`
		fi

		GUI_PICTURE_DAEMON="$3"

		if [ "$3" != '' ]; then
			chmod 777 $GUI_PICTURE_DAEMON
			$GUI_PICTURE_DAEMON &
		fi
	fi
}

handle_e_gui_show_picture()
{
	_IFS="$IFS";IFS=':';set -- $*;IFS="$_IFS"

	if [ "$5" = '' ]; then
		GUI_SHOW_TEXT_RUNTIME="$GUI_SHOW_TEXT_INIT"
	else
		GUI_SHOW_TEXT_RUNTIME="$5"
	fi

	GUI_PICTURE_NAME="$3"

	if [ $CURRENT_SCREEN = '2' ]; then
		echo "Set GUI_PICTURE_NAME=$GUI_PICTURE_NAME"
	else
		echo "GUI_show_picture::$GUI_PICTURE_NAME::$GUI_SHOW_TEXT_RUNTIME"
		inform_gui_action "GUI_show_picture::$GUI_PICTURE_NAME::$GUI_SHOW_TEXT_RUNTIME"
	fi
}

handle_e_osd_off_str()
{
	#e_osd_off_str::OSD_STR_UUID
	osd_off_str "$*"
}

handle_e_osd_on_str()
{
	local _OSD_Y_START
	local _OSD_MAX_Y_SIZE
	local _OSD_TRANSPARENT
	local _OSD_BKGRND_MASK_EN
	local _OFF_TIMER
	local _OSD_STR_FILE
	local _OSD_FONT_SIZE
	local _OSD_FONT_COLOR

	#e_osd_on_str::OSD_Y_START::OSD_MAX_Y_SIZE::OSD_TRANSPARENT::OSD_BKGRND_MASK_EN::OFF_TIMER::OSD_STR_FILE::OSD_FONT_SIZE::OSD_FONT_COLOR
	_IFS="$IFS";IFS=':';set -- $*;IFS="$_IFS"

	shift 2
	_OSD_Y_START="$1"
	shift 2
	_OSD_MAX_Y_SIZE="$1"
	shift 2
	_OSD_TRANSPARENT="$1"
	shift 2
	_OSD_BKGRND_MASK_EN="$1"
	shift 2
	_OFF_TIMER="$1"
	shift 2
	_OSD_STR_FILE="$1"
	shift 2
	_OSD_FONT_SIZE="$1"
	shift 2
	_OSD_FONT_COLOR="$1"

	# TODO. Validate input parameters.
	#echo "OSD string!!! $_OSD_Y_START $_OSD_MAX_Y_SIZE $_OSD_TRANSPARENT $_OSD_BKGRND_MASK_EN $_OFF_TIMER $_OSD_STR_FILE $_OSD_FONT_SIZE $_OSD_FONT_COLOR"
	osd_on_str "$_OSD_Y_START" "$_OSD_MAX_Y_SIZE" "$_OSD_TRANSPARENT" "$_OSD_BKGRND_MASK_EN" "$_OFF_TIMER" "$_OSD_STR_FILE" "$_OSD_FONT_SIZE" "$_OSD_FONT_COLOR"
}

handle_e_osd_off_pic()
{
	if [ "$SOC_OP_MODE" -lt "3" ]; then
		return
	fi

	#e_osd_off_pic::OSD_PIC_UUID or e_osd_off_pic::now
	osd_off_pic "$*"
}

handle_e_osd_on_pic()
{
	local _OSD_Y_START
	local _OSD_MAX_Y_SIZE
	local _OSD_TRANSPARENT
	local _OSD_BKGRND_MASK_EN
	local _OFF_TIMER
	local _OSD_PIC_FILE
	local _OSD_PIC_OPTION

	if [ "$SOC_OP_MODE" -lt "3" ]; then
		return
	fi

	#e_osd_on_pic::OSD_Y_START::OSD_MAX_Y_SIZE::OSD_TRANSPARENT::OSD_BKGRND_MASK_EN::OFF_TIMER::OSD_PIC_FILE::OSD_PIC_OPTION
	_IFS="$IFS";IFS=':';set -- $*;IFS="$_IFS"

	shift 2
	_OSD_Y_START="$1"
	shift 2
	_OSD_MAX_Y_SIZE="$1"
	shift 2
	_OSD_TRANSPARENT="$1"
	shift 2
	_OSD_BKGRND_MASK_EN="$1"
	shift 2
	_OFF_TIMER="$1"
	shift 2
	_OSD_PIC_FILE="$1"
	shift 2
	_OSD_PIC_OPTION="$1"

	# TODO. Validate input parameters.
	#echo "OSD PIC!!! $_OSD_Y_START $_OSD_MAX_Y_SIZE $_OSD_TRANSPARENT $_OSD_BKGRND_MASK_EN $_OFF_TIMER $_OSD_PIC_FILE $_OSD_PIC_OPTION"
	osd_on_pic "$_OSD_Y_START" "$_OSD_MAX_Y_SIZE" "$_OSD_TRANSPARENT" "$_OSD_BKGRND_MASK_EN" "$_OFF_TIMER" "$_OSD_PIC_FILE" "$_OSD_PIC_OPTION"
}

handle_e_osd_position()
{
	if [ "$SOC_OP_MODE" -lt "3" ]; then
		return
	fi
	#e_osd_position::OSD_POSITION_ALIGN::OSD_POSITION_X_START_OFFSET::OSD_POSITION_Y_START_OFFSET
	_IFS="$IFS";IFS=':';set -- $*;IFS="$_IFS"
	
	shift 2
	_OSD_POSITION_ALIGN="$1"
	shift 2
	_OSD_POSITION_X_START_OFFSET="$1"
	shift 2
	_OSD_POSITION_Y_START_OFFSET="$1"
	
	osd_position "$_OSD_POSITION_ALIGN" "$_OSD_POSITION_X_START_OFFSET" "$_OSD_POSITION_Y_START_OFFSET" 
}

handle_e_osd()
{
	case "$*" in
		e_osd_position?*)
			handle_e_osd_position "$*"
		;;
		e_osd_on_str?*)
			handle_e_osd_on_str "$*"
		;;
		e_osd_off_str?*)
			handle_e_osd_off_str "$*"
		;;
		e_osd_on_pic?*)
			handle_e_osd_on_pic "$*"
		;;
		e_osd_off_pic?*)
			handle_e_osd_off_pic "$*"
		;;
		*)
			echo "Unknown OSD event?! ($*)"
		;;
	esac
}

handle_e_wrong_fw()
{
	osd_on.sh "Firmware Is Not Compatible"
}

# Worst case 0.05s message loop without handling any event.
state_machine()
{
	# Bruce160308. Try to ignore all TERM signals.
	trap signal_handler SIGTERM SIGPIPE SIGHUP SIGINT SIGALRM SIGUSR1 SIGUSR2 SIGPROF SIGVTALRM

	start_network 1
	do_s_init

	# Bruce160308. Why use complex 'cat $PIPE'?
	# Original simple `cat $PIPE` may exist the whole lm if the 'cat' get a exit signal.
	# I can't find a way to avoid/catch the signal (ex: SIGPIPE) in 'cat'.
	# The 'printf' method somehow resolves this problem and return an 'empty' string.
	# I guess it is because 'printf' is bash's built-in command?!
	#while events=`cat $PIPE`; do
	#while event=`printf "%s" "$(cat $PIPE)"`; do
	while event="$(< $PIPE)"; do
		# Bruce160308. This for loop is no longer used/needed due to the introduce of PIPE_ACK.
		#for event in "$events"; do
			#echo "Receive $event event on $STATE state "`cat /proc/uptime`
			case "$event" in
				e_button_?*)
					handle_e_button "$event"
				;;
				e_btn_?*)
					handle_"$event" "$event"
				;;
				msg_?*)
					echo "This event will be passed to msg_channel" > /dev/null
				;;
				act_?*)
					tickle_watchdog
					handle_action "$event"
				;;
				e_no_gw*)
					tickle_watchdog
					# Could be "e_no_gw" or "e_no_gw::?*"
					handle_e_no_gw "$event"
				;;
				e_heartbeat_init_ok*)
					handle_e_heartbeat_init_ok "$event"
				;;
				e_no_heartbeat*)
					tickle_watchdog
					handle_e_no_heartbeat "$event"
				;;
				e_found_gw*)
					tickle_watchdog
					handle_e_found_gw "$event"
				;;
				e_ip_remote_got_ex::?*)
					tickle_watchdog
					handle_e_ip_remote_got_ex "$event"
				;;
				e_start_srv_hp_time_up::*)
					handle_e_start_srv_hp_time_up "$event"
				;;
				e_start_srv_lp_time_up::*)
					handle_e_start_srv_lp_time_up "$event"
				;;
				e_vhub_heartbeat_init_ok)
					usb_handle_e_vhub_heartbeat_init_ok
				;;
				e_usb_all_init_ok)
					usb_handle_e_usb_all_init_ok
				;;
				e_usb_all_stopped)
					usb_handle_e_all_stopped
				;;
				e_vw_?*)
					handle_e_vw "$event"
				;;
				e_vwbtn_?*)
					handle_"$event"
				;;
				e_sh_?*)
					handle_e_sh "$event"
				;;
				callback=*)
					handle_e_sh_jsonp "$event"
				;;
				e_pwr_status_chg_?*)
					tickle_watchdog
					handle_e_pwr_status_chg "$event"
				;;
				e_video_stat_?*)
					handle_e_video_stat "$event"
				;;
				r?*c?*_?*)
					handle_rXcX "$event"
				;;
				e_ip_got::?*)
					#echo "Pass event ($event) to GUI"
					inform_gui "$event::$STATE"
					handle_e_ip_got "$event"
				;;
				e_var_dump::?*::?*)
					handle_e_var_dump "$event"
				;;
				e_var_get::?*)
					handle_e_var_get "$event"
				;;
				e_var_set::?*::?*)
					handle_e_var_set "$event"
				;;
				e_ip_del::?* | e_name_id::?*)
					#echo "Pass event ($event) to GUI"
					inform_gui "$event::$STATE"
				;;
				e_gui_show_picture_daemon?*)
					tickle_watchdog
					handle_e_gui_show_picture_daemon "$event"
				;;
				e_gui_show_picture?*)
					tickle_watchdog
					handle_e_gui_show_picture "$event"
				;;
				e_osd?*)
					tickle_watchdog
					handle_e_osd "$event"
				;;
				e_?*)
					tickle_watchdog
					handle_"$event"
				;;
				tick)
					tickle_watchdog
				;;
				*)
					echo "ERROR!!!! Invalid event ($event) received"
					# Bruce160308. If the $event is an empty string, is should be some kind of error when reading from event pipe.
					# Ignoring this event, not ack the pipe should be good to go.
					# If we don't ignore this event and ack it, there will have an extra ack to ast_event_monitor, then bad things will happen.
					# Test this problem with e_reconnect x N.
					# FIXME. What if there is an event sent from ast_event_monitor PIPE, but read fail in the middle.
					#        We should ack under this case eventhough the '$event' is empty.
					if [ -z "$event" ]; then
						continue;
					fi
				;;
			esac
			# ACK this event. Add a null end in case of error.
			#echo "End of $event event on $STATE state "`cat /proc/uptime`
			# Bruce160301. In order to avoid '\n' been translated, we use 'printf' instead of 'echo'.
			#echo -e "$event\x00" > "$PIPE_ACK"
			# Bruce160308. To avoid 'broken PIPE' kills LM, we ack pipe in the background.
			#              (The 'broken PIPE' issue is just a wild guess.)
			{ printf "%s\x00" "$event"; } > "$PIPE_ACK" &
		#done
	done
}

init_param_from_flash()
{
	init_share_param_from_flash

	# I2S_CLOCK_LOCK_MODE for SoC v2 client only.
	# 0x80: OFF
	# 0: Auto (default)
	# 1: Normal
	# 2: Low
	# 4: High
	I2S_CLOCK_LOCK_MODE=`astparam g i2s_clock_lock_mode`
	if echo "$I2S_CLOCK_LOCK_MODE" | grep -q "not defined" ; then
		I2S_CLOCK_LOCK_MODE=`astparam r i2s_clock_lock_mode`
		if echo "$I2S_CLOCK_LOCK_MODE" | grep -q "not defined" ; then
			I2S_CLOCK_LOCK_MODE='0'
		fi
	fi

	NO_COIP=`astparam g no_coip`
	if [ "$NO_COIP" = "\"no_coip\" not defined" ]; then
		NO_COIP='y'
	fi
	echo "no_coip=$NO_COIP"
	VIDEO_SHRINK=`astparam g ast_video_shrink`
	if [ "$VIDEO_SHRINK" = "\"ast_video_shrink\" not defined" ]; then
		VIDEO_SHRINK='y'
	fi
	echo "ast_video_shrink=$VIDEO_SHRINK  (abandon)"
	#Bruce130204. Overwrite SHARE_USB will break web UI code.
	# NO_USB should act as the main ON/OFF switch
	#if [ "$NO_USB" = 'y' ]; then
	#	echo "Client force SHARE_USB=n when NO_USB=y"
	#	SHARE_USB='n'
	#fi
	
	#Bruce130107. Overwrite NO_USB will break web UI code.
	#if [ "$SHARE_USB" = 'y' ]; then
	#	echo "Client force NO_USB=y under SHARE_USB mode"
	#	NO_USB='y'
	#fi

	HDCP2_RX_ID=`astparam g hdcp2_rx_id`
	if echo "$HDCP2_RX_ID" | grep -q "not defined" ; then
		HDCP2_RX_ID=`astparam r hdcp2_rx_id`
		if echo "$HDCP2_RX_ID" | grep -q "not defined" ; then
			HDCP2_RX_ID='unavailable'
		fi
	fi
#	HDCP2_RX_CERT=`astparam g hdcp2_rx_cert`
#	if echo "$HDCP2_RX_CERT" | grep -q "not defined" ; then
#		HDCP2_RX_CERT=`astparam r hdcp2_rx_cert`
#		if echo "$HDCP2_RX_CERT" | grep -q "not defined" ; then
#			HDCP2_RX_CERT='unavailable'
#		fi
#	fi
	HDCP2_RX_CERT_DATA=`astparam g hdcp2_rx_cert_data`
	if echo "$HDCP2_RX_CERT_DATA" | grep -q "not defined" ; then
		HDCP2_RX_CERT_DATA=`astparam r hdcp2_rx_cert_data`
		if echo "$HDCP2_RX_CERT_DATA" | grep -q "not defined" ; then
			HDCP2_RX_CERT_DATA='unavailable'
		fi
	fi
	HDCP2_RX_CERT_SIG=`astparam g hdcp2_rx_cert_sig`
	if echo "$HDCP2_RX_CERT_SIG" | grep -q "not defined" ; then
		HDCP2_RX_CERT_SIG=`astparam r hdcp2_rx_cert_sig`
		if echo "$HDCP2_RX_CERT_SIG" | grep -q "not defined" ; then
			HDCP2_RX_CERT_SIG='unavailable'
		fi
	fi
	HDCP2_RX_PRIVATE_KEY_CRT=`astparam g hdcp2_rx_private_key_crt`
	if echo "$HDCP2_RX_PRIVATE_KEY_CRT" | grep -q "not defined" ; then
		HDCP2_RX_PRIVATE_KEY_CRT=`astparam r hdcp2_rx_private_key_crt`
		if echo "$HDCP2_RX_PRIVATE_KEY_CRT" | grep -q "not defined" ; then
			HDCP2_RX_PRIVATE_KEY_CRT='unavailable'
		fi
	fi

	V_SRC_UNAVAILABLE_TIMEOUT=`astparam g v_src_unavailable_timeout`
	if echo "$V_SRC_UNAVAILABLE_TIMEOUT" | grep -q "not defined" ; then
		V_SRC_UNAVAILABLE_TIMEOUT=`astparam r v_src_unavailable_timeout`
		if echo "$V_SRC_UNAVAILABLE_TIMEOUT" | grep -q "not defined" ; then
			# Use 10s as default. (Driver is 5 sec by default, but VGA requires longer value.)
			# Set to '-1' to disable power save feature
			V_SRC_UNAVAILABLE_TIMEOUT='10000'
		fi
	fi

	V_TURN_OFF_SCREEN_ON_PWR_SAVE=`astparam g v_turn_off_screen_on_pwr_save`
	if echo "$V_TURN_OFF_SCREEN_ON_PWR_SAVE" | grep -q "not defined" ; then
		V_TURN_OFF_SCREEN_ON_PWR_SAVE=`astparam r v_turn_off_screen_on_pwr_save`
		if echo "$V_TURN_OFF_SCREEN_ON_PWR_SAVE" | grep -q "not defined" ; then
			# For easier field trouble shooting, we don't turn off screen on power save
			V_TURN_OFF_SCREEN_ON_PWR_SAVE='n'
		fi
	fi

	SHOW_CH_OSD=`astparam g show_ch_osd`
	if echo "$SHOW_CH_OSD" | grep -q "not defined" ; then
		SHOW_CH_OSD=`astparam r show_ch_osd`
		if echo "$SHOW_CH_OSD" | grep -q "not defined" ; then
			SHOW_CH_OSD='n'
		fi
	fi

    GUI_SHOW_TEXT_INIT=`astparam g ui_show_text`
    if echo "$GUI_SHOW_TEXT_INIT" | grep -q "not defined" ; then
        GUI_SHOW_TEXT_INIT=`astparam r ui_show_text`
        if echo "$GUI_SHOW_TEXT_INIT" | grep -q "not defined" ; then
            GUI_SHOW_TEXT_INIT='y'
        fi
    fi
	GUI_SHOW_TEXT_RUNTIME="$GUI_SHOW_TEXT_INIT"

	USB_DEFAULT_POLICY=`astparam g usb_default_policy`
	if echo "$USB_DEFAULT_POLICY" | grep -q "not defined" ; then
		USB_DEFAULT_POLICY=`astparam r usb_default_policy`
		if echo "$USB_DEFAULT_POLICY" | grep -q "not defined" ; then
			# auto_export or no_auto_export
			USB_DEFAULT_POLICY='auto_export'
		fi
	fi

	USB_CONFLICT_POLICY=`astparam g usb_conflict_policy`
	if echo "$USB_CONFLICT_POLICY" | grep -q "not defined" ; then
		USB_CONFLICT_POLICY=`astparam r usb_conflict_policy`
		if echo "$USB_CONFLICT_POLICY" | grep -q "not defined" ; then
			# auto_export or no_auto_export
			USB_CONFLICT_POLICY='no_auto_export'
		fi
	fi

	USB_ENABLE_CLASSES=`astparam g usb_enable_classes`
	if echo "$USB_ENABLE_CLASSES" | grep -q "not defined" ; then
		USB_ENABLE_CLASSES=`astparam r usb_enable_classes`
		if echo "$USB_ENABLE_CLASSES" | grep -q "not defined" ; then
			# To enable C-media USB audio, set to 'audio'
			# See /etc/usbip/usbip_export.conf for all valid options
			USB_ENABLE_CLASSES=''
		fi
	fi

	USB_DISABLE_CLASSES=`astparam g usb_disable_classes`
	if echo "$USB_DISABLE_CLASSES" | grep -q "not defined" ; then
		USB_DISABLE_CLASSES=`astparam r usb_disable_classes`
		if echo "$USB_DISABLE_CLASSES" | grep -q "not defined" ; then
			# To disable C-media USB audio, set to 'audio'
			# See /etc/usbip/usbip_export.conf for all valid options
			USB_DISABLE_CLASSES=''
		fi
	fi

	USB_ENABLE_DEVICES=`astparam g usb_enable_devices`
	if echo "$USB_ENABLE_DEVICES" | grep -q "not defined" ; then
		USB_ENABLE_DEVICES=`astparam r usb_enable_devices`
		if echo "$USB_ENABLE_DEVICES" | grep -q "not defined" ; then
			# To enable C-media USB audio, set to 'VID:PID'
			# See /etc/usbip/usbip_export.conf for all valid options
			USB_ENABLE_DEVICES=''
		fi
	fi

	USB_DISABLE_DEVICES=`astparam g usb_disable_devices`
	if echo "$USB_DISABLE_DEVICES" | grep -q "not defined" ; then
		USB_DISABLE_DEVICES=`astparam r usb_disable_devices`
		if echo "$USB_DISABLE_DEVICES" | grep -q "not defined" ; then
			# To disable C-media USB audio, set to 'VID:PID'
			# See /etc/usbip/usbip_export.conf for all valid options
			USB_DISABLE_DEVICES=''
		fi
	fi

	# Print the final parameters
	echo_parameters
}

signal_handler()
{
	echo ""
	echo ""
	echo ""
	echo "ERROR!!!! LM received signal!!!!!! Ignore it."
	echo ""
	echo ""
	echo ""
}

#set -x
#### main #####
export PATH="$PATH":/usr/local/bin
cd /usr/local/bin
. ./include.sh
. ./include_share_usb.sh

init_watchdog

mknod $PIPE_INFO_LOCAL p
mknod $PIPE_INFO_REMOTE p
mknod $PIPE_INFO_OSD p
mknod $PIPE_INFO_GUI_ACTION p
# make event_pipe node
rm -f "$PIPE" 2>/dev/null
rm -f "$PIPE_ACK" 2>/dev/null
mknod "$PIPE" p
mknod "$PIPE_ACK" p
# msgd need "lo"
ifconfig lo up
msgd -h &

# initialize parameters
init_param_from_flash

# overwrite parameters from pssed in parameters
while [ -n "$1" ]; do
	if [ "$1" = "no_video" ]; then
		#inform_gui_echo "NO_VIDEO"
		NO_VIDEO='y'
	elif [ "$1" = "no_usb" ]; then
		#inform_gui_echo "NO_USB"
		NO_USB='y'
	elif [ "$1" = "no_i2s" ]; then
		#inform_gui_echo "NO_I2S"
		NO_I2S='y'
	elif [ "$1" = "no_ir" ]; then
		#inform_gui_echo "NO_IR"
		NO_IR='y'
	elif [ "$1" = "no_coip" ]; then
		#inform_gui_echo "NO_COIP"
		NO_COIP='y'
	elif [ "$1" = "debug" ]; then
		#inform_gui_echo "DBG"
		DBG='1'
		set -x
	elif [ "$1" = "video_quality_mode_fix" ]; then
		#inform_gui_echo "fix video quality mode"
		V_QUALITY_MODE='1'
	fi
	shift 1
done

# $AST_PLATFORM = ast1500cv4 or ptv1500cv2 or pce1500cv3
echo ""
echo "#### platform info:$AST_PLATFORM ####"
if [ -z "$AST_PLATFORM" ]; then
	inform_gui_echo "ERROR! no AST_PLATFORM info."
	exit 1;
fi

handle_button_on_boot

if [ -f "$DISPLAY_SYS_PATH"/screen ]; then
	HAS_CRT='y'
else
	HAS_CRT='n'
fi

if [ -f /usr/local/bin/GUI ]; then
	if [ "$UI_FEATURE" = 'y' ]; then
		GUI -qws -keyboard -ui_feature -hostname_prefix "$HOSTNAME_PREFIX" -multicast_ip_prefix "$MULTICAST_IP_PREFIX" -option "$UI_OPTION" &
	else
		GUI -qws -nomouse -nokeyboard -option "$UI_OPTION" &
	fi
	HAS_GUI='y'
else
	HAS_GUI='n'
fi

# start event_monitor 
ast_event_monitor &
EM_PID=$!

STATE='s_init'
echo $STATE > $DEVICE_STATUS_FILE
VIDEO_STATE='V_STATE_REMOVING'
VIDEO_MODE='V_MODE_UNKNOWN'
# Start state machine in another process scope
state_machine &
# Bruce130123. Moved to state_machine. Avoid parameter scope problem.
#start_network 1
#do_s_init

