#!/bin/sh

sleep "$1"
ast_send_event -1 e_start_srv_hp_time_up::$2

