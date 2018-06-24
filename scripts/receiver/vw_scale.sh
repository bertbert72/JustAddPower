#!/bin/sh
## vw_scale.sh - automatically calculate the vertical and horizontal scale values needed when in video wall mode
## Determine the number of rows and columns in the video wall, and also this Receivers row/col position
export num_rows=$(($(astparam g vw_max_row)+1))
export num_cols=$(($(astparam g vw_max_column)+1))
export my_row=$(($(astparam g vw_row)+1))
export my_col=$(($(astparam g vw_column)+1))
## Determine the number of vertical and horizontal lines based on the current resolution being sent to the Receiver
export v_res=$(cat /sys/devices/platform/display/timing_info | grep timing | cut -d'x' -f2 | cut -d'p' -f1)
export h_res=$(cat /sys/devices/platform/display/timing_info | grep timing | cut -d'x' -f1 | cut -d']' -f2)
## Calculate the off_by_v and off_by_h values
export off_by_v=$(($v_res/$num_rows%8))
export off_by_h=$(($h_res/$num_cols%8))
## Determine and apply scaling
## v_scale
if [ $off_by_v = 0 ] ; then
e e_vw_v_scale_0
else
if [ $(($my_row%2)) = 1 ] ; then
export odd_row_v_scale=$(($off_by_v*$num_rows))
e e_vw_v_scale_$odd_row_v_scale
elif [ $(($my_row%2)) = 0 ] ; then
export even_row_v_scale=$((($off_by_v-8)*$num_rows))
e e_vw_v_scale_$even_row_v_scale
fi
fi
## h_scale
if [ $off_by_h = 0 ] ; then
e e_vw_h_scale_0
else
if [ $(($my_col%2)) = 1 ] ; then
export odd_col_h_scale=$(($off_by_h*$num_cols))
e e_vw_h_scale_$odd_col_h_scale
elif [ $(($my_col%2)) = 0 ] ; then
export even_col_h_scale=$((($off_by_h-8)*$num_cols))
e e_vw_h_scale_$even_col_h_scale
fi
fi