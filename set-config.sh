#!/system/bin/sh

case "$0" in
    */*) MODDIR=${0%/*} ;;
    *) MODDIR=. ;;
esac
. "$MODDIR/power-data.sh"

UPPER_LIMIT="$1"
LOWER_LIMIT="$2"

if ! is_percentage "$UPPER_LIMIT" || ! is_percentage "$LOWER_LIMIT"; then
    echo "上下限必须是 0 到 100 的整数" >&2
    exit 2
fi

if [ "$UPPER_LIMIT" -le "$LOWER_LIMIT" ]; then
    echo "充电上限必须大于恢复下限" >&2
    exit 2
fi

TMP_FILE="$CONFIG_FILE.tmp.$$"
umask 022
if ! {
    printf 'UPPER_LIMIT=%s\n' "$UPPER_LIMIT"
    printf 'LOWER_LIMIT=%s\n' "$LOWER_LIMIT"
} > "$TMP_FILE"; then
    echo "无法写入临时配置文件" >&2
    rm -f "$TMP_FILE"
    exit 1
fi

if ! mv -f "$TMP_FILE" "$CONFIG_FILE"; then
    echo "无法更新配置文件" >&2
    rm -f "$TMP_FILE"
    exit 1
fi

echo "配置已保存，守护进程将在 10 秒内应用"
