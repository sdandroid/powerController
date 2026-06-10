#!/system/bin/sh

case "$0" in
    */*) MODDIR=${0%/*} ;;
    *) MODDIR=. ;;
esac
. "$MODDIR/power-data.sh"

load_power_data

printf '%s\n' \
    "UPPER_LIMIT=$UPPER_LIMIT" \
    "LOWER_LIMIT=$LOWER_LIMIT" \
    "CAPACITY=$CAPACITY" \
    "BATTERY_STATUS=$BATTERY_STATUS" \
    "USB_ONLINE=$USB_ONLINE" \
    "USB_TYPE=$USB_TYPE" \
    "VOLTAGE_NOW=$VOLTAGE_NOW" \
    "CURRENT_NOW=$CURRENT_NOW" \
    "TEMPERATURE=$TEMPERATURE" \
    "BYPASS_ENABLED=$BYPASS_ENABLED" \
    "CONTROLLER_STATE=$CONTROLLER_STATE"
