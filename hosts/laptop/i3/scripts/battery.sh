#!/usr/bin/env bash

BAT="BAT0"
BASE="/sys/class/power_supply/$BAT"

status=$(cat "$BASE/status")

energy_now=$(cat "$BASE/energy_now")
energy_full=$(cat "$BASE/energy_full")

percent=$(( 100 * energy_now / energy_full ))

case "$status" in
  "Charging") icon="CHR" ;;
  "Discharging") icon="BAT" ;;
  "Full") icon="FULL" ;;
  *) icon="$status" ;;
esac

echo "$icon ${percent}%"
