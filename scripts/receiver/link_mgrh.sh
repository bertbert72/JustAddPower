#!/bin/sh

##
## Copyright (c) 2004-2012
## ASPEED Technology Inc. All Rights Reserved
## Proprietary and Confidential
##
## By using this code you acknowledge that you have signed and accepted
## the terms of the ASPEED SDK license agreement.
##


stop_all_service()
{
	unload_soip_h 2>/dev/null

	pkill -9 ast_heartbeat 2>/dev/null
	pkill -9 name_service 2> /dev/null
	/sbin/avahi-daemon -k 2>/dev/null
	pkill -9 asthost 2>/dev/null
	rmvhubh.sh
	pkill -9 vhub_heartbeat 2>/dev/null
	stop_i2s_h 2>/dev/null
	stop_ir_h 2>/dev/null
	stop_cec  2>/dev/null  # GreatWall adds
	rmmod videoip 2>/dev/null

	#rmmod display.ko
	rmmod cat6023.ko 2>/dev/null
	
	#rmmod I2C.ko
}

# NOTICE: This function run on different process scope. (not in state_machine scope)
# Bruce130123. Now moved into state_machine scope.
do_s_init()
{
	echo "Memory Controller Setting:"
	echo "0x1e6e2040:"
	/usr/local/bin/io 0 0x1e6e2040
	echo "0x1e6e0068:"
	/usr/local/bin/io 0 0x1e6e0068
	if [ "$SOC_VER" = '1' ]; then
		# If CPU frequency down to 266MHz, the board's memory is bad.
		if { /usr/local/bin/io 0 0x1e6e2024 | grep -iq "44120"; }; then
			echo "ERROR!!!!!! Board Memory Test FAIL!"
			if [ "$STOP_ON_BOOT_TEST_FAIL" = 'y' ]; then
				ast_send_event -1 e_kill
				return 1
			fi
		fi
	else
		if ! boot_test_v2.sh; then
			if [ "$STOP_ON_BOOT_TEST_FAIL" = 'y' ]; then
				ast_send_event -1 e_kill
				return 1
			fi
		fi
	fi
	if [ "$EN_LOG" = 'n' ]; then
		/usr/local/bin/log.sh off
	fi
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
	if [ -f "/share/edid_multichannel.txt" ]; then
		cat /share/edid_multichannel.txt > $DISPLAY_SYS_PATH/default_edid_multichannel
	fi
	# Indicate that system is stable.
	if [ "$PWR_LED_TYPE" = 'share_usb' ]; then
		led_off $LED_PWR
	else
		led_on $LED_PWR
	fi

	#ast_send_event "$EM_PID" "e_sys_init_ok"
	post_ip_addr
}

warn()
{
	echo "!!!!! $1 !!!!!"
	#to_s_error
}

to_s_error()
{
	echo "Last state=$STATE event=$event"
	STATE='s_error'
	echo $STATE > $DEVICE_STATUS_FILE
	handle_e_kill
}

to_s_start_srv()
{
	if eth_link_is_off ; then
		echo "Network link is down"
		return 0
	fi

	STATE='s_start_srv'
	echo $STATE > $DEVICE_STATUS_FILE
	#stop watchdog daemon
	stop_watchdog_daemon
	#tickle watchdog
	tickle_watchdog
#	watchdog.sh &
	
	led_blink $LED_LINK
	# unset all required event to be checked.
	USBIP_RDY='n'
	USBIP_USER_RDY='n'
	VIDEOIP_RDY='n'
	HEARTBEAT_RDY='n'
	I2S_RDY='n'
	IR_RDY='n'
	CLIENT_NUM='0'
	USB_CLIENT_IP='00000000'

	if [ $NO_VIDEO = 'n' ]; then
		#change profile
#		cp -f ./profile/"$PROFILE"/* .
		start_videoip_remote &
	else
		#ast_send_event "$EM_PID" 'e_videoip_init_ok'
		VIDEOIP_RDY='y'
		ast_send_event "$EM_PID" 'e_video_start_working'
	fi

	if [ $NO_I2S = 'n' ]; then
		start_i2s_h &
	else
		#ast_send_event "$EM_PID" 'e_i2s_init_ok'
		I2S_RDY='y'
	fi

	if [ $NO_IR = 'n' ]; then
		start_ir_h &
	else
		#ast_send_event "$EM_PID" 'e_iroip_init_ok'
		IR_RDY='y'
	fi

	if [ $NO_USB = 'n' ]; then
		# If vhub.ko is already loaded, then we don't load it again.
		if lsmod | grep -q "vhub" ; then
			vhub_heartbeat -h &
			USBIP_RDY='y'
			USBIP_USER_RDY='y'
		else
			vhubh.sh
			echo $USB_SET_ADDR_HACK > $VHUB_SYS_PATH/set_addr_hack
			echo $USB_HID_URB_INTERVAL > $VHUB_SYS_PATH/hid_urb_interval
			vhub_heartbeat -h &
		fi
		if [ "$PWR_LED_TYPE" = 'share_usb' ]; then
			led_on $LED_PWR
		fi
	else
		#ast_send_event "$EM_PID" 'e_usbip_init_ok'
		#ast_send_event "$EM_PID" 'e_usbip_user_init_ok'
		USBIP_RDY='y'
		USBIP_USER_RDY='y'
	fi

	if [ $NO_KMOIP = 'n' ]; then
		if ! { lsmod | grep -q "vhub"; } ; then
			vhubh.sh
		fi
		start_kmoip_h
	fi

	if [ $NO_SOIP = 'n' ] && [ "$SOIP_GUEST_ON" = 'n' ]; then
		load_soip_h &
	fi

	if [ $NO_PWRBTN = 'n' ]; then
		poll_gpio.sh &
	fi

  # GreatWall adds
  if [ $CEC_GUEST_MODE = 'y' ]; then
		start_cec & 
	fi

	if is_all_started; then
		ast_send_event "$EM_PID" 'e_all_init_ok'
	fi
}

to_s_pre_srv_on()
{
	STATE='s_pre_srv_on'
	echo $STATE > $DEVICE_STATUS_FILE
	#tickle watchdog
	tickle_watchdog
#	stop_watchdog
	#start watchdog daemon
	start_watchdog_daemon

	if [ "$MULTICAST_ON" = 'n' ]; then
		ast_heartbeat -h &
	else
		pkill -9 igmp_daemon 2> /dev/null
		igmp_daemon.sh $MULTICAST_IP &

		if [ "$SEAMLESS_SWITCH" = 'y' ]; then
			#ast_send_event -1 "e_heartbeat_init_ok"
			ast_heartbeat_no_tcp -h -m -d "$MULTICAST_IP" &
		else
			#ast_heartbeat -h -m -d "$MULTICAST_IP" &
			ast_heartbeat -h -m &
		fi
	fi
}

to_s_srv_on()
{
	STATE='s_srv_on'
	echo $STATE > $DEVICE_STATUS_FILE
	led_on $LED_LINK
	
	if [ $NO_VIDEO = 'n' ]; then
		if ! { cat ${VIDEO_SYS_PATH}/State | grep -q "OPERATING"; }; then
			to_s_attaching
		fi
	fi
}

to_s_attaching()
{
	STATE='s_attaching'
	echo $STATE > $DEVICE_STATUS_FILE
	led_blink $LED_LINK

	if [ $NO_VIDEO = 'y' ]; then
		led_on $LED_LINK
	fi
}

to_s_stop_srv()
{
	STATE='s_stop_srv'
	echo $STATE > $DEVICE_STATUS_FILE
	
	if [ "$MULTICAST_ON" = 'y' ]; then
		pkill -9 igmp_daemon 2> /dev/null
		igmp_daemon.sh &
	fi

	#stop watchdog daemon
	stop_watchdog_daemon
	#tickle watchdog
	tickle_watchdog
#	watchdog.sh &

	led_blink $LED_LINK

	if is_all_stopped ; then
		to_s_idle
		return 0
	fi
	
	# stop heartbeat
	pkill -9 ast_heartbeat 2>/dev/null
	#ast_send_event "$EM_PID" 'e_heartbeat_stopped'
	HEARTBEAT_RDY='n'

	if [ $NO_USB = 'n' ]; then
		# We are not going to remove vhub.ko anymore. 
		#rmvhubh.sh &
		vhub_detach_all.sh
		pkill -9 vhub_heartbeat 2>/dev/null
		USBIP_RDY='n'
		USBIP_USER_RDY='n'
		if [ "$PWR_LED_TYPE" = 'share_usb' ]; then
			led_off $LED_PWR
		fi
	else
		#ast_send_event "$E_PID" 'e_usbip_stopped'
		#ast_send_event "$EM_PID" 'e_usbip_user_stopped'
		USBIP_RDY='n'
		USBIP_USER_RDY='n'
	fi

	#if [ $NO_KMOIP = 'n' ]; then
	#	stop_kmoip_h
	#fi

	if [ $NO_I2S = 'n' ]; then
		stop_i2s_h &
	else
		#ast_send_event "$EM_PID" 'e_i2s_stopped'
		I2S_RDY='n'
	fi

	if [ $NO_IR = 'n' ]; then
		stop_ir_h &
	else
		#ast_send_event "$EM_PID" 'e_iroip_stopped'
		IR_RDY='n'
	fi

	if [ $NO_VIDEO = 'n' ]; then
		stop_videoip_remote &
	else
		#ast_send_event "$EM_PID" 'e_videoip_stopped'
		VIDEOIP_RDY='n'
	fi

	if [ $NO_SOIP = 'n' ] && [ "$SOIP_GUEST_ON" = 'n' ]; then
		unload_soip_h
	fi

	if [ $NO_PWRBTN = 'n' ]; then
		pkill -9 poll_gpio
	fi

  #"GreatWall adds"
  if [ $CEC_GUEST_MODE = 'y' ]; then
		stop_cec &
	fi 

	if is_all_stopped; then
		ast_send_event "$EM_PID" 'e_all_stopped'
	fi
}

to_s_idle()
{
	STATE='s_idle'
	echo $STATE > $DEVICE_STATUS_FILE
	#tickle watchdog
	tickle_watchdog
#	stop_watchdog
	#start watchdog daemon
	start_watchdog_daemon

	led_off $LED_LINK

	# Bruce101103.Why we need to restart name_service here??
	#restart name service
	#pkill -9 name_service 2> /dev/null
	#name_service -thost

	if [ "$MULTICAST_ON" = 'y' ]; then
		igmp_leave_daemon.sh $MULTICAST_IP &
	fi

	if [ "$AST_PLATFORM" = 'pce1500hv3' ]; then
		if pc_is_off; then
			ACCESS_ON='n'
			monitor_pc_stat &
		fi
	fi

	if [ "$ACCESS_ON" = 'y' ]; then
		to_s_start_srv
	else
		if [ $NO_VIDEO = 'n' ] && ! [ "$AST_PLATFORM" = 'pce1500hv3' ]; then
			start_videoip_loopback
		fi

		if [ $NO_KMOIP = 'n' ]; then
			stop_kmoip_h
		fi
	fi
}

handle_e_sys_init_ok()
{
	if [ "$STATE" = 's_init' ]; then
		# I2S also depends on cat6023.ko
		if [ "$NO_VIDEO" = 'n' ] || [ "$NO_I2S" = 'n' ]; then
			insmod cat6023.ko drv_param=$V_RX_DRV_OPTION
      if [ "$V_REJECT_HDCP" = 'y' ]; then
				_drv_param='1'
			else
				_drv_param='0'
			fi
			if [ "$LOOPBACK_DEFAULT_ON" = 'y' ]; then
				echo 1 > $HDMIRX_SYS_PATH/LoopbackEnable
			else
				echo 0 > $HDMIRX_SYS_PATH/LoopbackEnable
			fi
		fi
		if [ "$NO_VIDEO" = 'n' ]; then
			if [ "$SOC_VER" != '1' ]; then
				echo "$V_DUAL_PORT" > $DISPLAY_SYS_PATH/dual_port
			fi
#			insmod cat6023.ko
			start_videoip_h
		fi
		#Bruce120618. Move to button_handler_h.sh
		#if [ "$EN_VIDEO_WALL" = 'y' ]; then
		#	# reduce the response time of long press to 0.5 sec (default is 2 sec)
		#	echo 50 > "$GPIO_SYS_PATH"/button_link/delay
		#	echo 50 > "$GPIO_SYS_PATH"/button_pairing/delay
		#	stty 115200 -F /dev/ttyS0
		#fi
		# Always load SoIP under SOIP_GUEST_ON mode.
		if [ $NO_SOIP = 'n' ] && [ "$SOIP_GUEST_ON" = 'y' ]; then
			load_soip_h &
		fi

		#"GreatWall adds"
	  if [ $CEC_GUEST_MODE = 'y' ]; then
			start_cec &
		fi

		igmp_daemon.sh &

		to_s_idle
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

_link_on_off()
{
	# Save the state into flash
	if [ "$ACCESS_ON" = 'y' ]; then
		ACCESS_ON='n'
		#astparam s astaccess n
	else
		ACCESS_ON='y'
		#astparam s astaccess y
	fi

	if [ "$STATE" = 's_idle' ]; then
		to_s_start_srv
	elif [ "$STATE" = 's_srv_on' ]; then
		echo "Stop link STATE=$STATE"
		to_s_stop_srv
	elif [ "$STATE" = 's_pre_srv_on' ]; then
		echo "Stop link STATE=$STATE"
		to_s_stop_srv
	elif [ "$STATE" = 's_attaching' ]; then
		echo "Stop link STATE=$STATE"
		to_s_stop_srv
	else
		warn "Wrong state?!"
	fi
}

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

_vw_config_osd_on()
{
	ast_send_event -1 r99_e_vw_install_state_on
	# This is a dirty hack to ensure we turn on install state and save pos_idx right away.
	handle_e_vw_install_state e_vw_install_state_on
	# Switch on next row
	ast_send_event -1 r${VW_VAR_POS_IDX}_e_btn_vw_select_client_same_row
}
_vw_config_osd_off()
{
	# Turn off all OSDs
	ast_send_event -1 r99_msg_toFFFFFFFF_e_vwbtn_menu_off
	ast_send_event -1 r99_e_vw_install_state_off
}

handle_e_vw_config_osd_on()
{
	if [ "$EN_VIDEO_WALL" = 'y' ]; then
		if [ "$VW_VAR_INSTALL_STATE" = 'off' ]; then
			_vw_config_osd_on
		fi
	fi
}
handle_e_vw_config_osd_off()
{
	if [ "$EN_VIDEO_WALL" = 'y' ]; then
		if [ "$VW_VAR_INSTALL_STATE" = 'on' ]; then
			_vw_config_osd_off
		fi
	fi
}

# Used to save the host's position layout for WebUI. Set once when performing basic setup.
handle_e_vw_pos_layout()
{
	# Parse e_vw_pos_layout_${_VW_VAR_POS_MAX_ROW}_${_VW_VAR_POS_MAX_COL}
	#_VW_VAR_POS_MAX_ROW=`expr "$1" : 'e_vw_pos_layout_\([[:alnum:]]\{1,\}\)_[[:alnum:]]\{1,\}'`
	#_VW_VAR_POS_MAX_COL=`expr "$1" : 'e_vw_pos_layout_[[:alnum:]]\{1,\}_\([[:alnum:]]\{1,\}\)'`
	_IFS="$IFS";IFS='_';set -- $*;shift 4;IFS="$_IFS"
	_VW_VAR_POS_MAX_ROW=$1
	_VW_VAR_POS_MAX_COL=$2

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

handle_e_button_pairing_1()
{
	if [ "$STATE" = 's_idle' ] && eth_link_is_off && [ "$BTN2_LONG_ON_ETH_OFF" != 'e_btn_ignore' ]; then
		handle_"$BTN2_LONG_ON_ETH_OFF"
		return
	fi

	handle_"$BTN2_LONG"
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

handle_e_chg_hostname()
{
	/sbin/avahi-daemon -k 2>/dev/null
	#start avahi-daemon
	# The $HOSTNAME_ID is now decided in refresh_hostname_params()
	refresh_4bits_ch
	refresh_hostname_params
	hostname="${HOSTNAME_PREFIX}-gateway${HOSTNAME_ID}"

	echo "hostname=$hostname"
	astsetname $hostname
	echo $hostname > /etc/hostname
	hostname -F /etc/hostname

	/sbin/avahi-daemon -D 2>/dev/null

}

handle_e_stop_link()
{
	ACCESS_ON='n'

	if [ "$STATE" = 's_idle' ]; then
		echo "Already stopped"
	elif [ "$STATE" = 's_start_srv' ]; then
		echo "Got e_stop_link under s_start_srv state. Re-send"
		{ sleep 1 && ast_send_event -1 e_stop_link; } &
	elif [ "$STATE" = 's_srv_on' ]; then
		echo "Stop link STATE=$STATE"
		to_s_stop_srv
	elif [ "$STATE" = 's_pre_srv_on' ]; then
		echo "Stop link STATE=$STATE"
		to_s_stop_srv
	elif [ "$STATE" = 's_attaching' ]; then
		echo "Stop link STATE=$STATE"
		to_s_stop_srv
	else
		warn "Wrong state?!"
	fi

}

handle_e_reconnect()
{
	refresh_4bits_ch
	refresh_ch_params
	ACCESS_ON='y'
	
	if [ "$STATE" = 's_idle' ]; then
		to_s_start_srv
	elif [ "$STATE" = 's_start_srv' ]; then
		echo "Got e_reconnect under s_start_srv state. Re-send"
		{ sleep 1 && ast_send_event -1 e_reconnect; } &
	elif [ "$STATE" = 's_srv_on' ]; then
		echo "Stop link STATE=$STATE"
		to_s_stop_srv
	elif [ "$STATE" = 's_pre_srv_on' ]; then
		echo "Stop link STATE=$STATE"
		to_s_stop_srv
	elif [ "$STATE" = 's_attaching' ]; then
		echo "Stop link STATE=$STATE"
		to_s_stop_srv
	else
		warn "Wrong state?!"
	fi
}

handle_e_usbip_init_ok()
{
	USBIP_RDY='y'
	if [ "$STATE" = 's_start_srv' ]; then
		echo "USB over IP initialized!"
		if is_all_started; then
			ast_send_event "$EM_PID" 'e_all_init_ok'
		fi
	else
		warn "Wrong state?!"
	fi
}

handle_e_usbip_user_init_ok()
{
	USBIP_USER_RDY='y'
	if [ "$STATE" = 's_start_srv' ]; then
		echo "USBIP_USER init OK!"
		if is_all_started; then
			ast_send_event "$EM_PID" 'e_all_init_ok'
		fi
	else
		warn "Wrong state?!"
	fi
}

handle_e_videoip_init_ok()
{
	VIDEOIP_RDY='y'
	if [ "$STATE" = 's_start_srv' ]; then
		echo "VIDEOIP init OK!"
		if is_all_started; then
			ast_send_event "$EM_PID" 'e_all_init_ok'
		fi
	elif [ "$STATE" = 's_init' ] && [ "$AST_PLATFORM" = "ptv1500hv2" ]; then
		# In v2 plaform, we load videoip.ko on do_s_init(). So, it is OK to get a event here.
		echo "video driver loaded"
	elif [ "$STATE" = 's_idle' ] && [ "$AST_PLATFORM" = "ptv1500hv2" ]; then
		# In v2 plaform, we load videoip.ko on do_s_init(). So, it is OK to get a event here.
		echo "video driver loaded"
	else
		warn "Wrong state?!"
	fi
}

handle_e_i2s_init_ok()
{
	I2S_RDY='y'
	if [ "$STATE" = 's_start_srv' ]; then
		echo "I2SoIP initialized!"
		if is_all_started; then
			ast_send_event "$EM_PID" 'e_all_init_ok'
		fi
	else
		warn "Wrong state?!"
	fi
}

handle_e_iroip_init_ok()
{
	IR_RDY='y'
	if [ "$STATE" = 's_start_srv' ]; then
		echo "IR initialized."
		if is_all_started; then
			ast_send_event "$EM_PID" 'e_all_init_ok'
		fi
	else
		warn "Wrong state?!"
	fi
}

handle_e_heartbeat_init_ok()
{
	HEARTBEAT_RDY='y'
	if [ "$STATE" = 's_pre_srv_on' ]; then
		echo "HEARTBEAT init OK!"
		to_s_srv_on
	else
		warn "Wrong state?!"
	fi
}

handle_e_all_init_ok()
{
	if [ "$STATE" = 's_start_srv' ]; then
		echo "ALL init OK!"
		to_s_pre_srv_on
	else
		warn "Wrong state?!"
	fi
}

post_config()
{
	if [ $NO_VIDEO = 'n' ]; then
		# Bruce100525. A1 change button behavior
		# Only apply under multicast mode.
		# if [ "$MULTICAST_ON" = 'n' ]; then
		# 	return
		# fi

		video_quality_set "$V_QUALITY_MODE"

		_t=`cat $VIDEO_SYS_PATH/rx`
		if [ "$_t" != "analog" ]; then
			# Set bcd_threshold
			echo "$V_BCD_THRESHOLD" > $VIDEO_SYS_PATH/bcd_threshold
		fi
	fi
}


handle_e_video_start_working()
{
	if [ "$STATE" = 's_srv_on' ]; then
		echo "Video start capture"
		# We stay in s_srv_on state, but stop blinking the LED_LINK
		#led_on $LED_LINK
	elif [ "$STATE" = 's_attaching' ]; then
		echo "Video start capture"
		# We change state to s_srv_on state, but stop blinking the LED_LINK
		to_s_srv_on
	else
		warn "Wrong state?!"
	fi
	post_config
}

handle_e_video_stop_working()
{
	if [ "$STATE" = 's_srv_on' ]; then
		echo "Video stop capture"
		# We change to s_attaching state, and start blinking the LED_LINK
		to_s_attaching
	else
		warn "Wrong state?!"
	fi
}


handle_e_attaching()
{
	if [ "$STATE" = 's_srv_on' ]; then
		echo "Video attaching"
		# We change to s_attaching state, and start blinking the LED_LINK
		to_s_attaching
	elif [ "$STATE" = 's_pre_srv_on' ]; then
		# It is a race condition where all services are initialized, but link_mgr got the e_attaching before e_heartbeat_init_ok.
		# To resolve this issue, resend the e_attaching event again. Any side effects?! ToDo. timeout could resolve loop forever issue.
		echo "Video attaching very fast"
		ast_send_event "$EM_PID" 'e_attaching'
	elif [ "$STATE" = 's_attaching' ]; then
		echo "Ignore this case" > /dev/null
	else
		warn "Wrong state?!"
	fi
}

handle_e_try_usb_to()
{
	# Get the IP address
	_IFS="$IFS";IFS='_';set -- $*;shift 4;IFS="$_IFS"
	_ip=$1

	if [ "$STATE" = 's_srv_on' ] || [ "$STATE" = 's_attaching' ] ; then
		if [ "$USB_CLIENT_IP" = '00000000' ]; then
			USB_CLIENT_IP="$_ip"
			if [ "$NO_USB" = 'n' ] && [ "$SHARE_USB" = 'y' ]; then
				ast_send_event -1 "msg_to${USB_CLIENT_IP}_e_start_usb"
			fi
		fi
	fi
}

handle_e_attaching_()
{
	# We only care e_attaching_ under multicast mode.
	if [ "$MULTICAST_ON" = 'n' ] && [ "$NO_PWRBTN" = "y" ]; then
		return
	fi

	# Get the IP address
	#_ip=`expr "$1" : 'e_attaching_\(........\)'`
	_IFS="$IFS";IFS='_';set -- $*;shift 2;IFS="$_IFS"
	_ip=$1
	
	if [ "$STATE" = 's_srv_on' ] || [ "$STATE" = 's_attaching' ] ; then
		echo "Client (${_ip}) attaching"
		if [ "$MULTICAST_ON" = 'y' ]; then
			# $CLIENT_NUM += 1
			#CLIENT_NUM=`expr $CLIENT_NUM + 1`
			CLIENT_NUM=$(( $CLIENT_NUM + 1 ))

			if [ "$CLIENT_NUM" -eq '1' ]; then
				# Try to start USB later. Extend from 1 to 4 sec to avoid race condition.
				{
					sleep 4
					ast_send_event -1 e_try_usb_to_"$_ip"
				} &
			fi
		fi
		if [ "$NO_PWRBTN" = "n" ]; then
			poll_gpio.sh report "$_ip"
		fi

	elif [ "$STATE" = 's_pre_srv_on' ]; then
		# It is a race condition where all services are initialized, but link_mgr got the e_attaching before e_heartbeat_init_ok.
		# To resolve this issue, resend the e_attaching event again. Any side effects?! ToDo. timeout could resolve loop forever issue.
		echo "Client (${_ip}) attaching very fast"
		ast_send_event "$EM_PID" "$1"
	else
		warn "Wrong state?!"
	fi
}


is_all_started()
{
	if [ "$VIDEOIP_RDY" = 'y' ] && [ "$USBIP_RDY" = 'y' ] && [ "$USBIP_USER_RDY" = 'y' ] && [ "$I2S_RDY" = 'y' ] && [ "$IR_RDY" = 'y' ]; then
		return 0
	fi
	return 1
}

is_all_stopped()
{
	if [ "$VIDEOIP_RDY" = 'n' ] && [ "$USBIP_RDY" = 'n' ] && [ "$HEARTBEAT_RDY" = 'n' ] && [ "$USBIP_USER_RDY" = 'n' ] && [ "$I2S_RDY" = 'n' ] && [ "$IR_RDY" = 'n' ]; then
		return 0
	fi
	return 1
}


handle_e_usbip_stopped()
{
	USBIP_RDY='n'
	if [ "$STATE" = 's_stop_srv' ]; then
		echo "USB over IP stopped."
		if is_all_stopped; then
			ast_send_event "$EM_PID" 'e_all_stopped'
		fi
	elif [ "$STATE" = 's_srv_on' ] || [ "$STATE" = 's_attaching' ] ; then
		echo "ERROR! USB over IP failed? Stop the link"
		to_s_stop_srv
	else
		warn "Wrong state?!"
	fi
}

handle_e_usbip_user_stopped()
{
	USBIP_USER_RDY='n'
	if [ "$STATE" = 's_stop_srv' ]; then
		echo "USBIP_USER stopped!"
		if is_all_stopped; then
			ast_send_event "$EM_PID" 'e_all_stopped'
		fi
	elif [ "$STATE" = 's_srv_on' ] || [ "$STATE" = 's_attaching' ]; then
		echo "ERROR! USBIP_USER failed? Stop the link"
		to_s_stop_srv
	else
		warn "Wrong state?!"
	fi
}

handle_e_videoip_stopped()
{
	VIDEOIP_RDY='n'
	if [ "$STATE" = 's_stop_srv' ]; then
		echo "HD_OVER_IP stopped!"
		if is_all_stopped; then
			ast_send_event "$EM_PID" 'e_all_stopped'
		fi
	elif [ "$STATE" = 's_srv_on' ] || [ "$STATE" = 's_attaching' ]; then
		echo "ERROR! HD_OVER_IP failed? Stop the link"
		to_s_stop_srv
	else
		warn "Wrong state?!"
	fi
}

handle_e_i2s_stopped()
{
	I2S_RDY='n'
	if [ "$STATE" = 's_stop_srv' ]; then
		echo "I2SoIP stopped!"
		if is_all_stopped; then
			ast_send_event "$EM_PID" 'e_all_stopped'
		fi
	elif [ "$STATE" = 's_srv_on' ] || [ "$STATE" = 's_attaching' ]; then
		echo "ERROR! I2SoIP failed? Stop the link"
		to_s_stop_srv
	else
		warn "Wrong state?!"
	fi
}

handle_e_iroip_stopped()
{
	IR_RDY='n'
	if [ "$STATE" = 's_stop_srv' ]; then
		echo "IR stopped!"
		if is_all_stopped; then
			ast_send_event "$EM_PID" 'e_all_stopped'
		fi
	elif [ "$STATE" = 's_srv_on' ] || [ "$STATE" = 's_attaching' ]; then
		echo "ERROR! IR failed? Stop the link"
		to_s_stop_srv
	else
		warn "Wrong state?!"
	fi
}

handle_e_heartbeat_stopped()
{
	HEARTBEAT_RDY='n'
	if [ "$STATE" = 's_stop_srv' ]; then
		echo "System stopped!"
		if is_all_stopped; then
			ast_send_event "$EM_PID" 'e_all_stopped'
		fi
	else
		warn "Wrong state?!"
	fi
}

handle_e_all_stopped()
{
	to_s_idle
}

handle_e_no_heartbeat()
{
	echo "NO Heartbeat!!"
	if [ "$STATE" = 's_srv_on' ] || [ "$STATE" = 's_attaching' ]; then
		to_s_stop_srv
	else
		warn "Wrong state?!"
	fi

}

handle_e_no_heartbeat_ip()
{
	# Only handle this event under multicast mode.
	if [ "$MULTICAST_ON" = 'n' ]; then
		return
	fi
	
	#_peer_ip=`expr "$1" : 'e_no_heartbeat_\(........\)'`
	_IFS="$IFS";IFS='_';set -- $*;shift 3;IFS="$_IFS"
	_peer_ip=$1
	
	if [ "$STATE" = 's_srv_on' ] || [ "$STATE" = 's_attaching' ]; then
		# Should not run in background because a client may disconnect and then connect quickly.
		unlink_client "$_peer_ip"
		#CLIENT_NUM=`expr $CLIENT_NUM - 1`
		CLIENT_NUM=$(( $CLIENT_NUM - 1 ))
	else
		warn "Wrong state?!"
	fi
}

handle_e_no_vhub_heartbeat()
{
	echo "NO VHUB Heartbeat!!"
	if [ "$STATE" = 's_srv_on' ] || [ "$STATE" = 's_attaching' ]; then
		# Under unicast mode,  e_no_vhub_heartbeat should be equal to e_no_heartbeat. So,
		# we leave the job to handle_e_no_heartbeat().
		if [ "$MULTICAST_ON" = 'y' ]; then
			vhub_detach_all.sh
			# re-load vhub_heartbeat
			vhub_heartbeat -h &
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
		echo "NO_USB=$NO_USB"
	else
		warn "Please go back to IDLE state first"
	fi
}

handle_e_no_video()
{
	if [ "$STATE" = 's_idle' ]; then
		if [ "$NO_VIDEO" = 'n' ]; then
			NO_VIDEO='y'
			rmmod videoip 2>/dev/null
		else
			NO_VIDEO='n'
		fi
		echo "NO_VIDEO=$NO_VIDEO"
	else
		warn "Please go back to IDLE state first"
	fi
}

handle_e_no_i2s()
{
	if [ "$STATE" = 's_idle' ]; then
		if [ "$NO_I2S" = 'n' ]; then
			NO_I2S='y'
		else
			NO_I2S='n'
		fi
		echo "NO_I2S=$NO_I2S"
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
		echo "NO_IR=$NO_IR"
	else
		warn "Please go back to IDLE state first"
	fi
}

handle_e_ip_got()
{
	# Parse 'e_ip_got::xxx.xxx.xxx.xx'
	#MY_IP=`expr "$*" : 'e_ip_got::\(.*\)'`
	_IFS="$IFS";IFS=':';set -- $*;shift 2;IFS="$_IFS"
	MY_IP=$1

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
	
	if [ "$STATE" = 's_init' ]; then
		tickle_watchdog
		if [ "$SOC_VER" != '1' ]; then
			tcp.sh
			set_mtu
		else
			tcp.sh
		fi
		# The $HOSTNAME_ID is now decided in init_share_param_from_flash()
		hostname="${HOSTNAME_PREFIX}-gateway${HOSTNAME_ID}"

		echo "hostname=$hostname"
		astsetname $hostname
		echo $hostname > /etc/hostname
		hostname -F /etc/hostname

		route add -net 224.0.0.0 netmask 240.0.0.0 dev eth0
		# Force IGMP version to Version 2
		echo 2 > /proc/sys/net/ipv4/conf/eth0/force_igmp_version

		avahi-daemon -D
		name_service -thost
		httpd -h /www &
		# Start telnetd
		start_telnetd

		ast_send_event -1 "e_sys_init_ok"
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

handle_action()
{
	# Action string format: "act_XXXXXXXX_ActionString" where XXXXXXXX is the IP of requester
	#_action_str=`expr "$1" : 'act_........_\(.*\)'`
	_IFS="$IFS";IFS='_';set -- $*;shift 1
	_ip=$1
	shift 1
	_action_str="$*"
	IFS="$_IFS"
	
	#echo "Handle action: $1"
	case "$_action_str" in
		pwr_ctrl_press)
			led_on 'pwr_ctrl'
		;;
		pwr_ctrl_release)
			led_off 'pwr_ctrl'
		;;
		e_button_pairing_1)
			ast_send_event -1 e_button_pairing_1
		;;
		e_button_pairing)
			ast_send_event -1 e_button_pairing
		;;
		e_request_usb)
			# Stop the last USBoIP session first
			ast_send_event -1 "msg_to${USB_CLIENT_IP}_e_stop_usb"
			# Update the requested USBoIP session's IP
			#_ip=`expr "$1" : 'act_\(........\)_e_request_usb'`
			USB_CLIENT_IP="$_ip"
			# Start the new USBoIP session
			ast_send_event -1 "msg_to${USB_CLIENT_IP}_e_start_usb"
		;;
		?*)
			# treat any ActionString as event
			ast_send_event -1 "$_action_str"
		;;
		*)
		;;
	esac
#	if echo "$_action_str" | grep -q "^pwr_ctrl_press" ;then
#		led_on 'pwr_ctrl'
#	elif echo "$_action_str" | grep -q "^pwr_ctrl_release" ;then
#		led_off 'pwr_ctrl'
#	elif echo "$_action_str" | grep -q "^e_button_pairing_1" ;then
#		ast_send_event -1 e_button_pairing_1
#	elif echo "$_action_str" | grep -q "^e_button_pairing" ;then
#		ast_send_event -1 e_button_pairing
#	elif echo "$_action_str" | grep -q "^e_request_usb" ;then
#		# Stop the last USBoIP session first
#		ast_send_event -1 "msg_to${USB_CLIENT_IP}_e_stop_usb"
#		# Update the requested USBoIP session's IP
#		_ip=`expr "$1" : 'act_\(........\)_e_request_usb'`
#		USB_CLIENT_IP="$_ip"
#		# Start the new USBoIP session
#		ast_send_event -1 "msg_to${USB_CLIENT_IP}_e_start_usb"
#	elif [ -n "$_action_str" ]; then
#		# treat any ActionString as event
#		ast_send_event -1 "$_action_str"
#	fi
}

handle_e_eth_link_off()
{
	set_mtu
	#  Actually, eth_link_off event can be ignored under s_init state. 
	if [ "$STATE" = 's_init' ]; then
		return
	fi
	# Link off triggers reconnect (stop and start link).
	if [ "$ACCESS_ON" = 'y' ]; then
		handle_e_reconnect
	fi
}

handle_e_eth_link_on()
{
	# Double check
	if eth_link_is_off ; then
		inform_gui_echo "Network link is down again"
		return
	fi
	set_mtu
	# Bug. avahi-daemon is loaded when to_s_init(). We should not kill avahi-daemon under this state.
	#  Actually, eth_link_off event can be ignored under s_init state. 
	if [ "$STATE" = 's_init' ]; then
		#ast_send_event -1 e_eth_link_on
		return
	fi

	# Bug. avahi-daemon may not respond to astresname if eth link on/off frequently.
	# To resolve this issue, we try to reload avahi-daemon on each eth link on.
	# avahi-daemon -k
	# From my test, wait for 1 second after link on and load avahi-daemon can
	# resolve the problem that "can't find the host after link down for 10 minutes (SMC switch)".
	# sleep 1
	# avahi-daemon -D
	{ avahi-daemon -k 2>/dev/null; sleep 1; avahi-daemon -D; } &

	if [ "$STATE" = 's_idle' ]; then
		if [ "$ACCESS_ON" = 'y' ]; then
			handle_e_reconnect
		fi
	fi
}

handle_RIDX()
{
	_cmd=$*
	#_id=`expr "$*" : 'r\([[:digit:]]\{1,\}\)_.*'`
	#_event=`expr "$*" : 'r[[:digit:]]\{1,\}_\(.*\)'`
	_IFS="$IFS";IFS='_';set -- $_cmd
	_id=$1
	shift 1
	_event="$*"
	IFS="$_IFS"
	#Parse rXX to XX
	_IFS="$IFS";IFS='r';set -- $_id;_id=$2;IFS="$_IFS"
	
	if [ -z "$_id" ]; then
		return
	fi
	if [ -z "$_event" ]; then
		return
	fi

	if [ "$_id" = "$VW_VAR_POS_IDX" ]; then
		ast_send_event -1 "$_event"
	elif [ "$_id" = '99' ]; then
		if [ "$VW_VAR_POS_IDX" != "$VW_VAR_TAIL_IDX" ]; then
			send_to_next_host "$_cmd"
		fi
		ast_send_event -1 "$_event"
	else
		send_to_next_host "$_cmd"
	fi
}

handle_rXcX()
{
	ast_send_event -1 msg_toFFFFFFFF_$*
}

handle_e_vw_enable()
{
	#_VW_VAR_MAX_ROW=`expr "$1" : 'e_vw_enable_\([[:alnum:]]\{1,\}\)_[[:alnum:]]\{1,\}_[[:alnum:]]\{1,\}_[[:alnum:]]\{1,\}'`
	#_VW_VAR_MAX_COLUMN=`expr "$1" : 'e_vw_enable_[[:alnum:]]\{1,\}_\([[:alnum:]]\{1,\}\)_[[:alnum:]]\{1,\}_[[:alnum:]]\{1,\}'`
	#_VW_VAR_ROW=`expr "$1" : 'e_vw_enable_[[:alnum:]]\{1,\}_[[:alnum:]]\{1,\}_\([[:alnum:]]\{1,\}\)_[[:alnum:]]\{1,\}'`
	#_VW_VAR_COLUMN=`expr "$1" : 'e_vw_enable_[[:alnum:]]\{1,\}_[[:alnum:]]\{1,\}_[[:alnum:]]\{1,\}_\([[:alnum:]]\{1,\}\)'`
	_IFS="$IFS";IFS='_';set -- $*;shift 3;IFS="$_IFS"
	_VW_VAR_MAX_ROW=$1
	_VW_VAR_MAX_COLUMN=$2
	_VW_VAR_ROW=$3
	_VW_VAR_COLUMN=$4
	
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
		VW_VAR_MAX_ROW="$VW_VAR_POS_IDX"
	elif [ "$_VW_VAR_MAX_ROW" != 'x' ]; then
		VW_VAR_MAX_ROW="$_VW_VAR_MAX_ROW"
	fi
	if [ "$_VW_VAR_MAX_COLUMN" = 'd' ]; then
		VW_VAR_MAX_COLUMN="$VW_VAR_POS_IDX"
	elif [ "$_VW_VAR_MAX_COLUMN" != 'x' ]; then
		VW_VAR_MAX_COLUMN="$_VW_VAR_MAX_COLUMN"
	fi

	if [ "$_VW_VAR_ROW" = 'd' ]; then
		VW_VAR_ROW="$VW_VAR_POS_IDX"
	elif [ "$_VW_VAR_ROW" != 'x' ]; then
		VW_VAR_ROW="$_VW_VAR_ROW"
		#VW_VAR_ROW=`expr $VW_VAR_ROW % \( $VW_VAR_MAX_ROW + 1 \)`
		VW_VAR_ROW=$(( $VW_VAR_ROW % ( $VW_VAR_MAX_ROW + 1 ) ))
		if [ -z "$VW_VAR_ROW" ]; then
			VW_VAR_ROW='0'
		fi
	fi
	if [ "$_VW_VAR_COLUMN" = 'd' ]; then
		VW_VAR_COLUMN='0'
	elif [ "$_VW_VAR_COLUMN" != 'x' ]; then
		VW_VAR_COLUMN="$_VW_VAR_COLUMN"
		#VW_VAR_COLUMN=`expr $VW_VAR_COLUMN % \( $VW_VAR_MAX_COLUMN + 1 \)`
		VW_VAR_COLUMN=$(( $VW_VAR_COLUMN % ( $VW_VAR_MAX_COLUMN + 1 ) ))
		if [ -z "$VW_VAR_COLUMN" ]; then
			VW_VAR_COLUMN='0'
		fi
	fi
	#VW_VAR_LAYOUT=`expr $VW_VAR_MAX_ROW + 1`x`expr $VW_VAR_MAX_COLUMN + 1`
	VW_VAR_LAYOUT=$(( $VW_VAR_MAX_ROW + 1 ))x$(( $VW_VAR_MAX_COLUMN + 1 ))

	vw_enable
	./astparam s vw_max_row ${VW_VAR_MAX_ROW}
	./astparam s vw_max_column ${VW_VAR_MAX_COLUMN}
	./astparam s vw_row ${VW_VAR_ROW}
	./astparam s vw_column ${VW_VAR_COLUMN}
	./astparam save
}

handle_e_vw_moninfo()
{
	ast_send_event -1 msg_toFFFFFFFF_"$*"

	#VW_VAR_MONINFO_HA=`expr "$1" : 'e_vw_moninfo_\([[:digit:]]\{1,\}\)_[[:digit:]]\{1,\}_[[:digit:]]\{1,\}_[[:digit:]]\{1,\}'`
	#VW_VAR_MONINFO_HT=`expr "$1" : 'e_vw_moninfo_[[:digit:]]\{1,\}_\([[:digit:]]\{1,\}\)_[[:digit:]]\{1,\}_[[:digit:]]\{1,\}'`
	#VW_VAR_MONINFO_VA=`expr "$1" : 'e_vw_moninfo_[[:digit:]]\{1,\}_[[:digit:]]\{1,\}_\([[:digit:]]\{1,\}\)_[[:digit:]]\{1,\}'`
	#VW_VAR_MONINFO_VT=`expr "$1" : 'e_vw_moninfo_[[:digit:]]\{1,\}_[[:digit:]]\{1,\}_[[:digit:]]\{1,\}_\([[:digit:]]\{1,\}\)'`
	_IFS="$IFS";IFS='_';set -- $*;shift 3;IFS="$_IFS"
	VW_VAR_MONINFO_HA=$1
	VW_VAR_MONINFO_HT=$2
	VW_VAR_MONINFO_VA=$3
	VW_VAR_MONINFO_VT=$4
	
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
	echo "$VW_VAR_MONINFO_HA $VW_VAR_MONINFO_HT $VW_VAR_MONINFO_VA $VW_VAR_MONINFO_VT" > "$VIDEO_SYS_PATH"/vw_frame_comp

	astparam s vw_moninfo_ha "$VW_VAR_MONINFO_HA"
	astparam s vw_moninfo_ht "$VW_VAR_MONINFO_HT"
	astparam s vw_moninfo_va "$VW_VAR_MONINFO_VA"
	astparam s vw_moninfo_vt "$VW_VAR_MONINFO_VT"
	astparam save
}

#
# e_vw_refresh_pos_idx_start_$RowCnt_$ColCnt
# e_vw_refresh_pos_idx_head_$TheMac_$PosIdx
# e_vw_refresh_pos_idx_tail_$TheMac_$TailIdx
#
# e_vw_refresh_pos_idx_force_$PosIdx_$TailIdx
#
handle_e_vw_refresh_pos_idx()
{
	_cmd=$*
	
	case "$_cmd" in
		e_vw_refresh_pos_idx_start_?*)
			#VW_VAR_TMP_ROW_CNT=`expr $* : 'e_vw_refresh_pos_idx_start_\([[:alnum:]]\{1,\}\)_[[:alnum:]]\{1,\}'`
			#VW_VAR_TMP_COL_CNT=`expr $* : 'e_vw_refresh_pos_idx_start_[[:alnum:]]\{1,\}_\([[:alnum:]]\{1,\}\)'`
			_IFS="$IFS";IFS='_';set -- $_cmd;shift 6;IFS="$_IFS"
			VW_VAR_TMP_ROW_CNT=$1
			VW_VAR_TMP_COL_CNT=$2
			if [ -z "$VW_VAR_TMP_ROW_CNT" ]; then
				VW_VAR_TMP_ROW_CNT='d'
			fi
			if [ -z "$VW_VAR_TMP_COL_CNT" ]; then
				VW_VAR_TMP_COL_CNT='d'
			fi
			_t='head'
			_mac="$MY_MAC"
			_idx='0'
			send_to_next_host "e_vw_refresh_pos_idx_${_t}_${_mac}_${_idx}"
			VW_VAR_POS_IDX='0'
			VW_VAR_THE_MAX_ROW='0'
			VW_VAR_POS_R="$VW_VAR_POS_IDX"
			VW_VAR_POS_C='0'
			THE_ROW_ID="$VW_VAR_POS_IDX"
			astparam s vw_pos_idx "$VW_VAR_POS_IDX"
			astparam save
			return
		;;
		e_vw_refresh_pos_idx_force_?*)
			#VW_VAR_POS_IDX=`expr $* : 'e_vw_refresh_pos_idx_force_\([[:alnum:]]\{1,\}\)_[[:alnum:]]\{1,\}'`
			#VW_VAR_TAIL_IDX=`expr $* : 'e_vw_refresh_pos_idx_force_[[:alnum:]]\{1,\}_\([[:alnum:]]\{1,\}\)'`
			_IFS="$IFS";IFS='_';set -- $_cmd;shift 6;IFS="$_IFS"
			VW_VAR_POS_IDX=$1
			VW_VAR_TAIL_IDX=$2
			VW_VAR_THE_MAX_ROW="$VW_VAR_TAIL_IDX"
			VW_VAR_POS_R="$VW_VAR_POS_IDX"
			VW_VAR_POS_C='0'
			THE_ROW_ID="$VW_VAR_POS_IDX"
			astparam s vw_pos_idx "$VW_VAR_POS_IDX"
			astparam s vw_tail_idx "$VW_VAR_TAIL_IDX"
			astparam save
			return
		;;
		e_vw_refresh_pos_idx_head_?* | e_vw_refresh_pos_idx_tail_?*)
			#_t=`expr $* : 'e_vw_refresh_pos_idx_\(....\)_............_[[:alnum:]]\{1,\}'`
			#_mac=`expr $* : 'e_vw_refresh_pos_idx_...._\(............\)_[[:alnum:]]\{1,\}'`
			#_idx=`expr $* : 'e_vw_refresh_pos_idx_...._............_\([[:alnum:]]\{1,\}\)'`
			_IFS="$IFS";IFS='_';set -- $_cmd;shift 5;IFS="$_IFS"
			_t=$1
			_mac=$2
			_idx=$3
		;;
		*)
			return
		;;
	esac
#	if echo "$*" | grep -q '^e_vw_refresh_pos_idx_start_' ; then
#		VW_VAR_TMP_ROW_CNT=`expr $* : 'e_vw_refresh_pos_idx_start_\([[:alnum:]]\{1,\}\)_[[:alnum:]]\{1,\}'`
#		VW_VAR_TMP_COL_CNT=`expr $* : 'e_vw_refresh_pos_idx_start_[[:alnum:]]\{1,\}_\([[:alnum:]]\{1,\}\)'`
#		if [ -z "$VW_VAR_TMP_ROW_CNT" ]; then
#			VW_VAR_TMP_ROW_CNT='d'
#		fi
#		if [ -z "$VW_VAR_TMP_COL_CNT" ]; then
#			VW_VAR_TMP_COL_CNT='d'
#		fi
#		_t='head'
#		_mac="$MY_MAC"
#		_idx='0'
#		send_to_next_host "e_vw_refresh_pos_idx_${_t}_${_mac}_${_idx}"
#		VW_VAR_POS_IDX='0'
#		VW_VAR_THE_MAX_ROW='0'
#		VW_VAR_POS_R="$VW_VAR_POS_IDX"
#		VW_VAR_POS_C='0'
#		THE_ROW_ID="$VW_VAR_POS_IDX"
#		astparam s vw_pos_idx "$VW_VAR_POS_IDX"
#		astparam save
#		return
#	elif echo "$*" | grep -q '^e_vw_refresh_pos_idx_force_' ; then
#		VW_VAR_POS_IDX=`expr $* : 'e_vw_refresh_pos_idx_force_\([[:alnum:]]\{1,\}\)_[[:alnum:]]\{1,\}'`
#		VW_VAR_TAIL_IDX=`expr $* : 'e_vw_refresh_pos_idx_force_[[:alnum:]]\{1,\}_\([[:alnum:]]\{1,\}\)'`
#		VW_VAR_THE_MAX_ROW="$VW_VAR_TAIL_IDX"
#		VW_VAR_POS_R="$VW_VAR_POS_IDX"
#		VW_VAR_POS_C='0'
#		THE_ROW_ID="$VW_VAR_POS_IDX"
#		astparam s vw_pos_idx "$VW_VAR_POS_IDX"
#		astparam s vw_tail_idx "$VW_VAR_TAIL_IDX"
#		astparam save
#		return
#	else
#		_t=`expr $* : 'e_vw_refresh_pos_idx_\(....\)_............_[[:alnum:]]\{1,\}'`
#		_mac=`expr $* : 'e_vw_refresh_pos_idx_...._\(............\)_[[:alnum:]]\{1,\}'`
#		_idx=`expr $* : 'e_vw_refresh_pos_idx_...._............_\([[:alnum:]]\{1,\}\)'`
#	fi

	if [ "$_t" = 'head' ]; then
		if [ "$_mac" = "$MY_MAC" ]; then
			# chain traveling completed
			VW_VAR_THE_MAX_ROW="$_idx"
			VW_VAR_TAIL_IDX="$VW_VAR_THE_MAX_ROW"
			# save tail value
			send_to_next_host "e_vw_refresh_pos_idx_tail_${_mac}_${VW_VAR_THE_MAX_ROW}"

			if [ "$VW_VAR_TMP_ROW_CNT" = 'd' ]; then
				VW_VAR_TMP_ROW_CNT="$VW_VAR_THE_MAX_ROW"
			fi
			if [ "$VW_VAR_TMP_COL_CNT" = 'd' ]; then
				VW_VAR_TMP_COL_CNT="$VW_VAR_THE_MAX_ROW"
			fi
			ast_send_event -1 r99_e_vw_enable_${VW_VAR_TMP_ROW_CNT}_${VW_VAR_TMP_COL_CNT}_d_x
			ast_send_event -1 r99_msg_toFFFFFFFF_e_vw_enable_${VW_VAR_TMP_ROW_CNT}_${VW_VAR_TMP_COL_CNT}_d_x
			ast_send_event -1 e_vw_pos_layout_${VW_VAR_TMP_ROW_CNT}_${VW_VAR_TMP_COL_CNT}
			_vw_config_osd_on

			astparam s vw_tail_idx "$VW_VAR_TAIL_IDX"
			astparam save
		else
			#_idx=`expr $_idx + 1`
			_idx=$(( $_idx + 1 ))
			send_to_next_host "e_vw_refresh_pos_idx_head_${_mac}_${_idx}"
			VW_VAR_POS_IDX="$_idx"
			VW_VAR_POS_R="$VW_VAR_POS_IDX"
			VW_VAR_POS_C='0'
			THE_ROW_ID="$VW_VAR_POS_IDX"
			astparam s vw_pos_idx "$VW_VAR_POS_IDX"
			astparam save
		fi
	elif [ "$_t" = 'tail' ]; then
		VW_VAR_TAIL_IDX="$_idx"
		if [ "$VW_VAR_TAIL_IDX" != "$VW_VAR_POS_IDX" ]; then
			send_to_next_host "e_vw_refresh_pos_idx_tail_${_mac}_${_idx}"
		fi
		astparam s vw_tail_idx "$VW_VAR_TAIL_IDX"
		astparam save
	fi
}

handle_e_vw_install_state()
{
	#_t=`expr $* : 'e_vw_install_state_\(.*\)'`
	_IFS="$IFS";IFS='_';set -- $*;shift 4;IFS="$_IFS"
	_t=$1
	
	if [ "$_t" = 'on' ] && [ "$VW_VAR_INSTALL_STATE" = 'off' ]; then
		#VW_VAR_POS_IDX="${MY_ROW_ID}"
		VW_VAR_INSTALL_STATE='on'
		ast_send_event -1 msg_toFFFFFFFF_e_vw_refresh_pos_idx_"${VW_VAR_POS_IDX}"_x
		#astparam s vw_pos_idx "$VW_VAR_POS_IDX"
		#VW_VAR_POS_R="$VW_VAR_POS_IDX"
		#VW_VAR_POS_C='0'
		#astparam save
	elif [ "$_t" = 'off' ] && [ "$VW_VAR_INSTALL_STATE" = 'on' ]; then
		VW_VAR_INSTALL_STATE='off'
	fi
}

handle_e_vw_v_shift_d()
{
	#VW_VAR_V_SHIFT=`expr "$*" : 'e_vw_v_shift_d_\([[:digit:]]\{1,\}\)'`
	_IFS="$IFS";IFS='_';set -- $*;shift 5;IFS="$_IFS"
	VW_VAR_V_SHIFT=$1
	
	if [ -z "$VW_VAR_V_SHIFT" ]; then
		VW_VAR_V_SHIFT='0'
	fi
	echo "$VW_VAR_V_SHIFT" > "$VIDEO_SYS_PATH"/vw_v_shift
	astparam s vw_v_shift "$VW_VAR_V_SHIFT"
	astparam save
}
handle_e_vw_v_shift_u()
{
	#VW_VAR_V_SHIFT=`expr "$*" : 'e_vw_v_shift_u_\([[:digit:]]\{1,\}\)'`
	_IFS="$IFS";IFS='_';set -- $*;shift 5;IFS="$_IFS"
	VW_VAR_V_SHIFT=$1

	if [ -z "$VW_VAR_V_SHIFT" ]; then
		VW_VAR_V_SHIFT='0'
	fi
	if [ "$VW_VAR_V_SHIFT" != '0' ]; then
		VW_VAR_V_SHIFT="-$VW_VAR_V_SHIFT"
	fi
	echo "$VW_VAR_V_SHIFT" > "$VIDEO_SYS_PATH"/vw_v_shift
	astparam s vw_v_shift "$VW_VAR_V_SHIFT"
	astparam save
}

handle_e_vw_reset_to_pos()
{
	#_VW_VAR_MAX_ROW=`expr "$*" : 'e_vw_reset_to_pos_\([[:alnum:]]\{1,\}\)_[[:alnum:]]\{1,\}'`
	#_VW_VAR_MAX_COLUMN=`expr "$*" : 'e_vw_reset_to_pos_[[:alnum:]]\{1,\}_\([[:alnum:]]\{1,\}\)'`
	_IFS="$IFS";IFS='_';set -- $*;shift 5;IFS="$_IFS"
	_VW_VAR_MAX_ROW=$1
	_VW_VAR_MAX_COLUMN=$2
	
	if [ -z "$_VW_VAR_MAX_ROW" ]; then
		_VW_VAR_MAX_ROW='x'
	fi
	if [ -z "$_VW_VAR_MAX_COLUMN" ]; then
		_VW_VAR_MAX_COLUMN='x'
	fi

	if [ "$_VW_VAR_MAX_ROW" = 'd' ]; then
		VW_VAR_MAX_ROW="$VW_VAR_POS_IDX"
	elif [ "$_VW_VAR_MAX_ROW" != 'x' ]; then
		VW_VAR_MAX_ROW="$_VW_VAR_MAX_ROW"
	fi
	if [ "$_VW_VAR_MAX_COLUMN" = 'd' ]; then
		VW_VAR_MAX_COLUMN="$VW_VAR_POS_IDX"
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
	echo "$VW_VAR_V_SHIFT" > "$VIDEO_SYS_PATH"/vw_v_shift
	vw_enable
	astparam s vw_max_row "$VW_VAR_MAX_ROW"
	astparam s vw_max_column "$VW_VAR_MAX_COLUMN"
	astparam s vw_row "$VW_VAR_ROW"
	astparam s vw_column "$VW_VAR_COLUMN"
	#astparam s vw_h_shift "$VW_VAR_H_SHIFT"
	astparam s vw_v_shift "$VW_VAR_V_SHIFT"
	#astparam s vw_h_scale "$VW_VAR_H_SCALE"
	#astparam s vw_v_scale "$VW_VAR_V_SCALE"
	#astparam s vw_delay_kick "$VW_VAR_DELAY_KICK"
	astparam save
}

handle_e_vw_reset_to_pos_s()
{
	#_VW_VAR_MAX_ROW=`expr "$*" : 'e_vw_reset_to_pos_s_\([[:alnum:]]\{1,\}\)_[[:alnum:]]\{1,\}'`
	#_VW_VAR_MAX_COLUMN=`expr "$*" : 'e_vw_reset_to_pos_s_[[:alnum:]]\{1,\}_\([[:alnum:]]\{1,\}\)'`
	#if [ -z "$_VW_VAR_MAX_ROW" ]; then
	#	_VW_VAR_MAX_ROW='x'
	#fi
	#if [ -z "$_VW_VAR_MAX_COLUMN" ]; then
	#	_VW_VAR_MAX_COLUMN='x'
	#fi

	#if [ "$_VW_VAR_MAX_ROW" = 'd' ]; then
	#	VW_VAR_MAX_ROW="$VW_VAR_POS_IDX"
	#elif [ "$_VW_VAR_MAX_ROW" != 'x' ]; then
	#	VW_VAR_MAX_ROW="$_VW_VAR_MAX_ROW"
	#fi
	#if [ "$_VW_VAR_MAX_COLUMN" = 'd' ]; then
	#	VW_VAR_MAX_COLUMN="$VW_VAR_POS_IDX"
	#elif [ "$_VW_VAR_MAX_COLUMN" != 'x' ]; then
	#	VW_VAR_MAX_COLUMN="$_VW_VAR_MAX_COLUMN"
	#fi

	VW_VAR_MAX_ROW='0'
	VW_VAR_MAX_COLUMN='0'
	VW_VAR_ROW='0'
	VW_VAR_COLUMN='0'
	#VW_VAR_MONINFO_HA='0'
	#VW_VAR_MONINFO_HT='0'
	#VW_VAR_MONINFO_VA='0'
	#VW_VAR_MONINFO_VT='0'
	VW_VAR_H_SHIFT='0'
	VW_VAR_V_SHIFT='0'
	VW_VAR_H_SCALE='0'
	VW_VAR_V_SCALE='0'
	VW_VAR_DELAY_KICK='0'
	echo "$VW_VAR_V_SHIFT" > "$VIDEO_SYS_PATH"/vw_v_shift
	vw_enable
	astparam s vw_max_row "$VW_VAR_MAX_ROW"
	astparam s vw_max_column "$VW_VAR_MAX_COLUMN"
	astparam s vw_row "$VW_VAR_ROW"
	astparam s vw_column "$VW_VAR_COLUMN"
	#astparam s vw_h_shift "$VW_VAR_H_SHIFT"
	astparam s vw_v_shift "$VW_VAR_V_SHIFT"
	#astparam s vw_h_scale "$VW_VAR_H_SCALE"
	#astparam s vw_v_scale "$VW_VAR_V_SCALE"
	#astparam s vw_delay_kick "$VW_VAR_DELAY_KICK"
	astparam save
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
		*)
		;;
	esac
}

handle_e_vw()
{
	case "$*" in
		e_vw_config_osd_on)
			handle_e_vw_config_osd_on
		;;
		e_vw_config_osd_off)
			handle_e_vw_config_osd_off
		;;
		e_vw_pos_layout_?*)
			handle_e_vw_pos_layout "$event"
		;;
		e_vw_enable_?*)
			handle_e_vw_enable "$event"
		;;
		e_vw_moninfo_?*)
			handle_e_vw_moninfo "$event"
		;;
		e_vw_install_state_?*)
			handle_e_vw_install_state "$event"
		;;
		e_vw_v_shift_u_?*)
			handle_e_vw_v_shift_u "$event"
		;;
		e_vw_v_shift_d_?*)
			handle_e_vw_v_shift_d "$event"
		;;
		e_vw_reset_to_pos_s_?*)
			handle_e_vw_reset_to_pos_s "$event"
		;;
		e_vw_reset_to_pos_?*)
			handle_e_vw_reset_to_pos "$event"
		;;
		e_vw_refresh_pos_idx_?*)
			handle_e_vw_refresh_pos_idx "$event"
		;;
		*)
			echo "Unknown Video Wall event?! ($*)"
		;;
	esac
}

handle_e_var_get()
{
	_var_get "$*"
}

handle_e_var_set()
{
	_var_set "$*"
}

state_machine()
{
	start_network 2
	do_s_init

	while events=`cat $PIPE`; do
		for event in "$events"; do
			#echo "Receive $event event on $STATE state "`cat /proc/uptime`
			case "$event" in
				e_button_?*)
					handle_e_button "$event"
				;;
				e_no_heartbeat_?*)
					handle_e_no_heartbeat_ip "$event"
				;;
				e_ip_got::?*)
					handle_e_ip_got "$event"
				;;
				e_vw_?*)
					handle_e_vw "$event"
				;;
				# Bruce130110. shell 'case' will see 'r1_r1c2_' as rXcX case. Which is wrong.
				#r?*c?*_?*)
				#	handle_rXcX "$event"
				#;;
				r[0-9x]*_?*)
					if echo "$event" | grep -q -e "^r[[:digit:]x]\{1,\}c[[:digit:]x]\{1,\}_.*" ; then
						handle_rXcX "$event"
					else
						handle_RIDX "$event"
					fi
				;;
				e_sh_?*)
					handle_e_sh "$event"
				;;
				callback=*)
					handle_e_sh_jsonp "$event"
				;;
				e_attaching_?*)
					handle_e_attaching_ "$event"
				;;
				e_try_usb_to_?*)
					handle_e_try_usb_to "$event"
				;;
				act_?*)
					handle_action "$event"
				;;
				msg_?*)
					echo "This event will be passed to msg_channel" > /dev/null
				;;
				e_btn_?*)
					handle_"$event" "$event"
				;;
				e_var_get::?*)
					handle_e_var_get "$event"
				;;
				e_var_set::?*::?*)
					handle_e_var_set "$event"
				;;
				e_?*)
					handle_"$event"
				;;
				*)
					echo "ERROR!!!! Invalid event ($event) received"
				;;
			esac
			# ACK this event. Add a null end in case of error.
			#echo "End of $event event on $STATE state "`cat /proc/uptime`
			echo -e "$event\0000" > "$PIPE_ACK"
		done
	done
}


state_machine_old()
{
	while events=`cat $PIPE`; do
		for event in "$events"; do
			echo "Receive $event event on $STATE state"
			if [ "$event" = 'e_sys_init_ok' ]; then
				handle_e_sys_init_ok
			elif [ "$event" = 'e_button_link' ]; then
				handle_e_button_link
			elif [ "$event" = 'e_button_link_1' ]; then
				handle_e_button_link_1
			elif [ "$event" = 'e_button_pairing' ]; then
				handle_e_button_pairing
			elif [ "$event" = 'e_button_pairing_1' ]; then
				handle_e_button_pairing_1
			elif [ "$event" = 'e_kill' ]; then
				handle_e_kill
			elif [ "$event" = 'e_chg_hostname' ]; then
				handle_e_chg_hostname
			elif [ "$event" = 'e_stop_link' ]; then
				handle_e_stop_link
			elif [ "$event" = 'e_reconnect' ]; then
				handle_e_reconnect
			elif [ "$event" = 'e_usbip_init_ok' ]; then
				handle_e_usbip_init_ok
			elif [ "$event" = 'e_usbip_user_init_ok' ]; then
				handle_e_usbip_user_init_ok
			elif [ "$event" = 'e_videoip_init_ok' ]; then
				handle_e_videoip_init_ok
			elif [ "$event" = 'e_i2s_init_ok' ]; then
				handle_e_i2s_init_ok
			elif [ "$event" = 'e_iroip_init_ok' ]; then
				handle_e_iroip_init_ok
			elif [ "$event" = 'e_heartbeat_init_ok' ]; then
				# in host, e_heartbeat_init_ok is fired when the heartbeat listen socket is ready. (client is not attached yet).
				handle_e_heartbeat_init_ok
			elif [ "$event" = 'e_all_init_ok' ]; then
				handle_e_all_init_ok
			elif [ "$event" = 'e_video_start_working' ]; then
				handle_e_video_start_working
			elif [ "$event" = 'e_video_stop_working' ]; then
				handle_e_video_stop_working
			elif [ "$event" = 'e_usbip_stopped' ]; then
				handle_e_usbip_stopped
			elif [ "$event" = 'e_usbip_user_stopped' ]; then
				handle_e_usbip_user_stopped
			elif [ "$event" = 'e_videoip_stopped' ]; then
				handle_e_videoip_stopped
			elif [ "$event" = 'e_i2s_stopped' ]; then
				handle_e_i2s_stopped
			elif [ "$event" = 'e_iroip_stopped' ]; then
				handle_e_iroip_stopped
			elif [ "$event" = 'e_heartbeat_stopped' ]; then
				handle_e_heartbeat_stopped
			elif [ "$event" = 'e_all_stopped' ]; then
				handle_e_all_stopped
			elif [ "$event" = 'e_attaching' ]; then
				handle_e_attaching
			elif [ "$event" = 'e_no_heartbeat' ]; then
				handle_e_no_heartbeat
			elif echo "$event" | grep -q '^e_no_heartbeat_' ; then
				handle_e_no_heartbeat_ip "$event"
			elif [ "$event" = 'e_no_vhub_heartbeat' ]; then
				handle_e_no_vhub_heartbeat
			elif [ "$event" = 'e_debug' ]; then
				handle_e_debug
			elif [ "$event" = 'e_debug_json' ]; then
				handle_e_debug_json
			elif [ "$event" = 'e_no_usb' ]; then
				handle_e_no_usb
			elif [ "$event" = 'e_no_video' ]; then
				handle_e_no_video
#			elif [ "$event" = 'e_no_i2s' ]; then
#				handle_e_no_i2s
			elif [ "$event" = 'e_no_ir' ]; then
				handle_e_no_ir
			elif echo "$event" | grep -q "e_ip_got" ; then
				#MY_IP="$event"
				handle_e_ip_got "$event"
			elif [ "$event" = 'e_eth_link_on' ]; then
				handle_e_eth_link_on
			elif [ "$event" = 'e_eth_link_off' ]; then
				handle_e_eth_link_off
			elif [ "$event" = 'e_vw_config_osd_on' ] ; then
				handle_e_vw_config_osd_on
			elif [ "$event" = 'e_vw_config_osd_off' ] ; then
				handle_e_vw_config_osd_off
			elif echo "$event" | grep -q -e "^e_vw_pos_layout_.*" ; then
				handle_e_vw_pos_layout "$event"
			elif echo "$event" | grep -q -e "^e_vw_enable_.*" ; then
				handle_e_vw_enable "$event"
			elif echo "$event" | grep -q -e "^e_vw_moninfo_.*" ; then
				handle_e_vw_moninfo "$event"
			elif echo "$event" | grep -q -e "^e_vw_install_state_.*" ; then
				handle_e_vw_install_state "$event"
			elif echo "$event" | grep -q '^e_vw_v_shift_u_' ; then
				handle_e_vw_v_shift_u "$event"
			elif echo "$event" | grep -q '^e_vw_v_shift_d_' ; then
				handle_e_vw_v_shift_d "$event"
			elif echo "$event" | grep -q '^e_vw_reset_to_pos_s_' ; then
				handle_e_vw_reset_to_pos_s "$event"
			elif echo "$event" | grep -q '^e_vw_reset_to_pos_' ; then
				handle_e_vw_reset_to_pos "$event"
			elif echo "$event" | grep -q '^e_vw_refresh_pos_idx' ; then
				handle_e_vw_refresh_pos_idx "$event"
			elif echo "$event" | grep -q -e "^r[[:digit:]]\{1,\}_.*" ; then
				handle_RIDX "$event"
			elif echo "$event" | grep -q -e "^r[[:digit:]x]\{1,\}c[[:digit:]x]\{1,\}_.*" ; then
				handle_rXcX "$event"
			elif echo "$event" | grep -q "^e_sh_" ; then
				handle_e_sh "$event"
			elif echo "$event" | grep -q "^callback=" ; then
				handle_e_sh_jsonp "$event"
			elif echo "$event" | grep -q "^e_attaching_" ; then
				handle_e_attaching_ "$event"
			elif echo "$event" | grep -q "^act_" ; then
				handle_action "$event"
			elif echo "$event" | grep -q "^msg_" ; then
				echo "This event will be passed to msg_channel" > /dev/null
			elif echo "$event" | grep -iq '^e_button_link_'; then
				echo 'ignore' > /dev/null
			elif echo "$event" | grep -iq '^e_button_pairing_'; then
				echo 'ignore' > /dev/null
			elif echo "$event" | grep -q '^e_btn_' ; then
				handle_"$event" "$event"
			else
				echo "ERROR!!!! Invalid event ($event) received"
			fi
			# ACK this event. Add a null end in case of error.
			echo -e "$event\0000" > "$PIPE_ACK"
		done
	done
}

init_param_from_flash()
{
	init_share_param_from_flash

	LOOPBACK_DEFAULT_ON=`astparam g loopback_default_on`
	if echo "$LOOPBACK_DEFAULT_ON" | grep -q "not defined" ; then
		LOOPBACK_DEFAULT_ON=`astparam r loopback_default_on`
		if echo "$LOOPBACK_DEFAULT_ON" | grep -q "not defined" ; then
			LOOPBACK_DEFAULT_ON='y'
		fi
	fi
	echo "loopback_default_on: $LOOPBACK_DEFAULT_ON"

	LOOPBACK_EDID_PATCH=`astparam g loopback_edid_patch`
	if echo "$LOOPBACK_EDID_PATCH" | grep -q "not defined" ; then
		LOOPBACK_EDID_PATCH=`astparam r loopback_edid_patch`
		if echo "$LOOPBACK_EDID_PATCH" | grep -q "not defined" ; then
			if [ "$SOC_VER" = '1' ]; then
				LOOPBACK_EDID_PATCH='00000000'
			else
				LOOPBACK_EDID_PATCH='00000000'
			fi
		fi
	fi
	echo "LOOPBACK_EDID_PATCH=$LOOPBACK_EDID_PATCH"

	REMOTE_EDID_PATCH=`astparam g remote_edid_patch`
	if echo "$REMOTE_EDID_PATCH" | grep -q "not defined" ; then
		REMOTE_EDID_PATCH=`astparam r remote_edid_patch`
		if echo "$REMOTE_EDID_PATCH" | grep -q "not defined" ; then
			if [ "$SOC_VER" = '1' ]; then
				REMOTE_EDID_PATCH='00230017'
			else
				REMOTE_EDID_PATCH='00000005'
			fi
		fi
	fi
	echo "REMOTE_EDID_PATCH=$REMOTE_EDID_PATCH"
	
#	DEFAULT_KSV=`astparam g default_ksv`
#	if echo "$DEFAULT_KSV" | grep -q "not defined" ; then
#		DEFAULT_KSV=`astparam r default_ksv`
#		if echo "$DEFAULT_KSV" | grep -q "not defined" ; then
#			DEFAULT_KSV='unavailable'
#		fi
#	fi
	
	HDCP2_DCP_PUBLIC_KEY=`astparam g hdcp2_dcp_public_key`
	if echo "$HDCP2_DCP_PUBLIC_KEY" | grep -q "not defined" ; then
		HDCP2_DCP_PUBLIC_KEY=`astparam r hdcp2_dcp_public_key`
		if echo "$HDCP2_DCP_PUBLIC_KEY" | grep -q "not defined" ; then
			HDCP2_DCP_PUBLIC_KEY='unavailable'
		fi
	fi
	
	# Bruce120712. NO_USB should act as the main ON/OFF switch
	#if [ "$SHARE_USB" = 'y' ]; then
	#	echo "Host force NO_USB=n under SHARE_USB mode"
	#	NO_USB='n'
	#fi

	USB_SET_ADDR_HACK=`astparam g usb_set_addr_hack`
	if echo "$USB_SET_ADDR_HACK" | grep -q "not defined" ; then
		USB_SET_ADDR_HACK=`astparam r usb_set_addr_hack`
		if echo "$USB_SET_ADDR_HACK" | grep -q "not defined" ; then
			USB_SET_ADDR_HACK='0'
		fi
	fi

	USB_HID_URB_INTERVAL=`astparam g usb_hid_urb_interval`
	if echo "$USB_HID_URB_INTERVAL" | grep -q "not defined" ; then
		USB_HID_URB_INTERVAL=`astparam r usb_hid_urb_interval`
		if echo "$USB_HID_URB_INTERVAL" | grep -q "not defined" ; then
			#USB_HID_URB_INTERVAL='35' # Set to 35 to resolve some USB HID long latency issue
			USB_HID_URB_INTERVAL='0'
		fi
	fi
}

#set -x
#### main #####
export PATH="${PATH}":/usr/local/bin
cd /usr/local/bin
. ./include.sh

init_watchdog

#mknod $PIPE_INFO_LOCAL p    TBD
#mknod $PIPE_INFO_REMOTE p   TBD
# make event_pipe node
rm -f "$PIPE" 2>/dev/null
rm -f "$PIPE_ACK" 2>/dev/null
mknod "$PIPE" p
mknod "$PIPE_ACK" p

ifconfig lo up
# initialize parameters
init_param_from_flash

# overwrite parameters from pssed in parameters
while [ -n "$1" ]; do
	if [ "$1" = "no_video" ]; then
		echo "NO_VIDEO"
		NO_VIDEO='y'
	elif [ "$1" = "no_usb" ]; then
		echo "NO_USB"
		NO_USB='y'
	elif [ "$1" = "no_i2s" ]; then
		echo "NO_I2S"
		NO_I2S='y'
	elif [ "$1" = "no_ir" ]; then
		echo "NO_IR"
		NO_IR='y'
	elif [ "$1" = "debug" ]; then
		echo "DBG"
		DBG='1'
		set -x
	fi
	shift 1
done

# $AST_PLATFORM = ast1500hv4 or ptv1500hv2 or pce1500hv3
echo ""
echo "#### platform info:$AST_PLATFORM ####"
if [ -z "$AST_PLATFORM" ]; then
	echo "ERROR! no AST_PLATFORM info."
	return 1;
fi

handle_button_on_boot

# start event_monitor 
ast_event_monitor &
EM_PID=$!

STATE='s_init'
echo $STATE > $DEVICE_STATUS_FILE
# Start state machine in another process scope
state_machine &

# Bruce130123. Moved to state_machine. Avoid parameter scope problem.
#start_network 2
#do_s_init

