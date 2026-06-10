#!/system/bin/sh

# ==============================
# 路径与变量定义
# ==============================
case "$0" in
    */*) MODDIR=${0%/*} ;;
    *) MODDIR=. ;;
esac
. "$MODDIR/power-data.sh"

MAX_SIZE=1048576
LOG_FILE="$MODDIR/bypass.log"

LAST_STATE=""

# ==============================
# 辅助函数定义
# ==============================
log() {
    CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$CURRENT_TIME] $1" >> "$LOG_FILE"
}

# ==============================
# 初始化与开机等待
# ==============================
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 2
done

echo "=== OPPO/OnePlus 旁路充电控制模块已启动 ===" >> "$LOG_FILE"
log "系统启动完成，检查节点..."

if ! required_power_nodes_available; then
    log "error错误：设备缺少必需的电源节点！模块将停止运行。"
    exit 1
fi


echo 1 > "$BYPASS_NODE"
log "已执行安全兜底：默认恢复充电能力"

# ==============================
# 核心守护进程
# ==============================
while true; do

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "UPPER_LIMIT=$DEFAULT_UPPER_LIMIT" > "$CONFIG_FILE"
        echo "LOWER_LIMIT=$DEFAULT_LOWER_LIMIT" >> "$CONFIG_FILE"
        log "未找到配置文件，已自动生成 config.txt 并写入默认值 91/78。"
    fi

    load_power_data

    if [ -f "$MODDIR/disable" ] || [ -f "$MODDIR/remove" ]; then
        if [ "$LAST_STATE" != "DISABLED" ]; then
            echo 1 > "$BYPASS_NODE"
            log "模块被停用或处于卸载状态，已恢复正常满充能力。"
            LAST_STATE="DISABLED"
        fi
    else
        if [ "$USB_ONLINE" -eq 0 ]; then
            if [ "$LAST_STATE" != "UNPLUGGED" ]; then
                echo 1 > "$BYPASS_NODE"
                log "充电器已拔出 (电量 $CAPACITY%)，重置节点为可充电状态。"
                LAST_STATE="UNPLUGGED"
            fi
        else
            if [ "$CAPACITY" -ge "$UPPER_LIMIT" ]; then
                if [ "$LAST_STATE" != "BYPASS_ON" ]; then
                    echo 0 > "$BYPASS_NODE"
                    log "电量达到 $CAPACITY% (>= 设定上限 $UPPER_LIMIT%)，触发旁路供电"
                    LAST_STATE="BYPASS_ON"
                fi
            elif [ "$CAPACITY" -le "$LOWER_LIMIT" ]; then
                if [ "$LAST_STATE" != "CHARGING" ]; then
                    echo 1 > "$BYPASS_NODE"
                    log "电量降至 $CAPACITY% (<= 设定下限 $LOWER_LIMIT%)，恢复快速充电。"
                    LAST_STATE="CHARGING"
                fi
            else
                if [ "$LAST_STATE" = "BYPASS_ON" ] || [ "$LAST_STATE" = "WAITING_DOWN" ]; then
                    if [ "$LAST_STATE" != "WAITING_DOWN" ]; then
                        log "电量为 $CAPACITY%，位于区间内，维持旁路状态，等待降至 $LOWER_LIMIT%。"
                        LAST_STATE="WAITING_DOWN"
                    fi
                else
                    if [ "$LAST_STATE" != "WAITING_UP" ]; then
                        log "电量为 $CAPACITY%，位于区间内，维持充电状态，等待充至 $UPPER_LIMIT%。"
                        LAST_STATE="WAITING_UP"
                    fi
                fi
            fi
        fi
    fi
    
    if [ -f "$LOG_FILE" ]; then
        FILE_SIZE=$(stat -c%s "$LOG_FILE")
        if [ "$FILE_SIZE" -gt "$MAX_SIZE" ]; then
            : > "$LOG_FILE"
            log "日志超过1MB，已执行自动清空。" > "$LOG_FILE"
        fi
    fi
    
    sleep 10
done
