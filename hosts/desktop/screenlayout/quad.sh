#!/bin/sh
# 4-monitor layout, left to right: HDMI-0 (primary), DP-0, DP-2, DP-4
# Output names are assigned by the nvidia proprietary driver; they were
# HDMI-1/DP-1/DP-2/DP-3 under nouveau and changed after switching drivers.
xrandr \
  --output HDMI-0 --auto --primary \
  --output DP-0 --auto --right-of HDMI-0 \
  --output DP-2 --auto --right-of DP-0 \
  --output DP-4 --auto --right-of DP-2
