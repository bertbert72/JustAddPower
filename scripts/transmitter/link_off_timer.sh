#!/bin/sh

sleep "$1"
ast_send_event -1 e_link_off_time_up

