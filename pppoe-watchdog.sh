#!/bin/sh

# PPPoE Watchdog - Main orchestration script
# Monitors PPPoE connection and reboots DSL modem when needed

SCRIPT_DIR="$(dirname "$0")"
CONFIG_FILE="$SCRIPT_DIR/watchdog.conf"
STATE_FILE="/tmp/pppoe-watchdog.state"
LOG_FILE="/var/log/pppoe-watchdog.log"

# Default configuration
CHECK_INTERVAL=60
MAX_FAILURES=3
MAX_REBOOTS_PER_HOUR=2
MAX_REBOOTS_PER_DAY=10
MODEM_BOOT_TIME=300
BACKOFF_MULTIPLIER=2
INITIAL_BACKOFF=60

# Load configuration if exists
# shellcheck source=/dev/null
if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
fi

# State variables
failure_count=0
reboot_count_hour=0
reboot_count_day=0
last_reboot_time=0
last_hour_reset=0
last_day_reset=0
current_backoff=$INITIAL_BACKOFF

log_message() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

load_state() {
    if [ -f "$STATE_FILE" ]; then
        # shellcheck source=/dev/null
        . "$STATE_FILE"
    fi
}

save_state() {
    cat > "$STATE_FILE" << EOF
failure_count=$failure_count
reboot_count_hour=$reboot_count_hour
reboot_count_day=$reboot_count_day
last_reboot_time=$last_reboot_time
last_hour_reset=$last_hour_reset
last_day_reset=$last_day_reset
current_backoff=$current_backoff
EOF
}

reset_hourly_counters() {
    local current_hour
    local current_time
    current_hour=$(date +%H)
    current_time=$(date +%s)
    
    if [ $((current_time - last_hour_reset)) -ge 3600 ]; then
        reboot_count_hour=0
        last_hour_reset=$current_time
        log_message "Hourly reboot counter reset"
    fi
}

reset_daily_counters() {
    local current_day
    local current_time
    current_day=$(date +%j)
    current_time=$(date +%s)
    
    if [ $((current_time - last_day_reset)) -ge 86400 ]; then
        reboot_count_day=0
        last_day_reset=$current_time
        log_message "Daily reboot counter reset"
    fi
}

check_reboot_limits() {
    reset_hourly_counters
    reset_daily_counters
    
    if [ $reboot_count_hour -ge $MAX_REBOOTS_PER_HOUR ]; then
        log_message "Hourly reboot limit reached ($reboot_count_hour/$MAX_REBOOTS_PER_HOUR)"
        return 1
    fi
    
    if [ $reboot_count_day -ge $MAX_REBOOTS_PER_DAY ]; then
        log_message "Daily reboot limit reached ($reboot_count_day/$MAX_REBOOTS_PER_DAY)"
        return 1
    fi
    
    return 0
}

wait_for_modem_boot() {
    log_message "Waiting ${MODEM_BOOT_TIME}s for modem to boot..."
    sleep $MODEM_BOOT_TIME
}

try_pppoe_restart() {
    log_message "Attempting PPPoE interface restart..."
    ifdown pppoe-wan 2>/dev/null
    sleep 5
    ifup pppoe-wan 2>/dev/null
    sleep 30
}

reboot_modem() {
    local current_time
    current_time=$(date +%s)
    
    # Check if enough time has passed since last reboot
    if [ $((current_time - last_reboot_time)) -lt $current_backoff ]; then
        local wait_time=$((current_backoff - (current_time - last_reboot_time)))
        log_message "Backoff period active, waiting ${wait_time}s before next reboot attempt"
        return 1
    fi
    
    if ! check_reboot_limits; then
        return 1
    fi
    
    log_message "Rebooting DSL modem (attempt $((reboot_count_day + 1)))"
    
    if "$SCRIPT_DIR/mikrotik-control.sh" reboot 10; then
        last_reboot_time=$current_time
        reboot_count_hour=$((reboot_count_hour + 1))
        reboot_count_day=$((reboot_count_day + 1))
        
        # Increase backoff time
        current_backoff=$((current_backoff * BACKOFF_MULTIPLIER))
        if [ $current_backoff -gt 3600 ]; then
            current_backoff=3600
        fi
        
        log_message "Modem reboot initiated, new backoff time: ${current_backoff}s"
        wait_for_modem_boot
        return 0
    else
        log_message "Failed to reboot modem"
        return 1
    fi
}

reset_failure_count() {
    if [ $failure_count -gt 0 ]; then
        log_message "PPPoE connection restored, resetting failure count"
        failure_count=0
        current_backoff=$INITIAL_BACKOFF
    fi
}

main_loop() {
    log_message "PPPoE Watchdog started (PID: $$)"
    
    while true; do
        load_state
        
        if "$SCRIPT_DIR/pppoe-monitor.sh"; then
            reset_failure_count
        else
            failure_count=$((failure_count + 1))
            log_message "PPPoE check failed ($failure_count/$MAX_FAILURES)"
            
            if [ $failure_count -eq 2 ]; then
                try_pppoe_restart
            elif [ $failure_count -ge $MAX_FAILURES ]; then
                if reboot_modem; then
                    failure_count=0
                fi
            fi
        fi
        
        save_state
        sleep $CHECK_INTERVAL
    done
}

# Signal handlers
cleanup() {
    log_message "PPPoE Watchdog stopping (PID: $$)"
    rm -f "$STATE_FILE"
    exit 0
}

trap cleanup TERM INT

# Command line interface
case "$1" in
    "start")
        main_loop
        ;;
    "status")
        load_state
        echo "Failure count: $failure_count/$MAX_FAILURES"
        echo "Reboots today: $reboot_count_day/$MAX_REBOOTS_PER_DAY"
        echo "Reboots this hour: $reboot_count_hour/$MAX_REBOOTS_PER_HOUR"
        echo "Current backoff: ${current_backoff}s"
        ;;
    "test-modem")
        "$SCRIPT_DIR/mikrotik-control.sh" check
        ;;
    "test-pppoe")
        "$SCRIPT_DIR/pppoe-monitor.sh"
        ;;
    "reset")
        rm -f "$STATE_FILE"
        echo "State reset"
        ;;
    *)
        echo "Usage: $0 {start|status|test-modem|test-pppoe|reset}"
        exit 1
        ;;
esac