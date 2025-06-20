#!/bin/sh

# Mikrotik Switch PoE Control Script
# Controls PoE power via SwOS Lite JSON API

MIKROTIK_IP=""
MIKROTIK_PASS=""
DSL_MODEM_PORT="1"

# shellcheck source=watchdog.conf
. watchdog.conf

# Get authentication token
get_auth_token() {
    curl -s "http://$MIKROTIK_IP/" | grep -o 'var token="[^"]*"' | cut -d'"' -f2
}

# SwOS JSON API request
swos_api_request() {
    local json_data="$1"
    local token
    token=$(get_auth_token)
    
    if [ -z "$token" ]; then
        echo "Failed to get auth token"
        return 1
    fi
    
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "X-Requested-With: XMLHttpRequest" \
        --data-raw "$json_data" \
        "http://$MIKROTIK_IP/api.b" \
        -H "Authorization: Bearer $token"
}

# Login via password (if required)
swos_login() {
    if [ -n "$MIKROTIK_PASS" ]; then
        local response
        response=$(curl -s -X POST \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "password=$MIKROTIK_PASS" \
            "http://$MIKROTIK_IP/index.html")
        
        if echo "$response" | grep -q "Invalid password"; then
            echo "Login failed - invalid password"
            return 1
        fi
    fi
    
    return 0
}

# Check if we can connect to SwOS switch
check_mikrotik_connection() {
    if [ -z "$MIKROTIK_IP" ]; then
        echo "Mikrotik IP or password not configured"
        return 1
    fi

    if curl -s --connect-timeout 5 "http://$MIKROTIK_IP" >/dev/null; then
        if swos_login; then
            return 0
        else
            echo "Cannot login to SwOS at $MIKROTIK_IP"
            return 1
        fi
    else
        echo "Cannot connect to Mikrotik switch at $MIKROTIK_IP"
        return 1
    fi
}

# Get current PoE status
get_current_poe_status() {
    local response
    response=$(swos_api_request '{}')
    
    if [ $? -ne 0 ]; then
        echo "Failed to get PoE status"
        return 1
    fi
    
    # Parse response for current PoE settings
    echo "$response" | grep -o '"i01":\[[^]]*\]' | sed 's/"i01":\[//;s/\]//'
}

# Control PoE on specific port via SwOS JSON API
control_poe() {
    local port="$1"
    local action="$2"  # "on" or "off"
    
    if ! swos_login; then
        echo "Failed to login to SwOS"
        return 1
    fi
    
    # Get current PoE status to preserve other ports
    local current_status
    current_status=$(get_current_poe_status)
    
    if [ -z "$current_status" ]; then
        # Fallback: assume all ports should be on except the target
        current_status="0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02"
    fi
    
    # Parse current status and modify target port
    local poe_array=""
    local i=1
    local IFS=','
    
    for current_value in $current_status; do
        if [ $i -eq "$port" ]; then
            if [ "$action" = "on" ]; then
                poe_array="${poe_array}0x02"
            else
                poe_array="${poe_array}0x00"
            fi
        else
            # Keep current value, clean up any extra whitespace
            current_value=$(echo "$current_value" | tr -d ' ')
            poe_array="${poe_array}${current_value}"
        fi
        
        if [ $i -lt 8 ]; then
            poe_array="${poe_array},"
        fi
        i=$((i + 1))
    done
    
    # SwOS JSON API format for PoE control  
    local json_data="{i01:[$poe_array]}"
    
    swos_api_request "$json_data" >/dev/null
    return $?
}

# Enable PoE on a specific port
enable_poe() {
    local port="$1"
    echo "Enabling PoE on port $port"
    control_poe "$port" "on"
}

# Disable PoE on a specific port
disable_poe() {
    local port="$1"
    echo "Disabling PoE on port $port"
    control_poe "$port" "off"
}

# Power cycle (reboot) a device connected to specific port
reboot_device() {
    local port="$1"
    local off_time="${2:-10}"

    echo "Power cycling device on port $port (off for ${off_time}s)"

    # Turn off PoE
    if ! disable_poe "$port"; then
        echo "Failed to disable PoE on port $port"
        return 1
    fi

    # Wait for specified time
    sleep "$off_time"

    # Turn on PoE
    if ! enable_poe "$port"; then
        echo "Failed to enable PoE on port $port"
        return 1
    fi

    echo "Power cycle completed for port $port"
    return 0
}

# Reboot DSL modem (uses configured port)
reboot_dsl_modem() {
    local off_time="${1:-10}"
    echo "Rebooting DSL modem on port $DSL_MODEM_PORT"
    reboot_device "$DSL_MODEM_PORT" "$off_time"
}

# If script is called directly
if [ "${0##*/}" = "mikrotik-control.sh" ]; then
    case "$1" in
        "check")
            check_mikrotik_connection
            ;;
        "status")
            get_current_poe_status
            ;;
        "reboot")
            reboot_dsl_modem "$2"
            ;;
        "enable")
            enable_poe "$DSL_MODEM_PORT"
            ;;
        "disable")
            disable_poe "$DSL_MODEM_PORT"
            ;;
        *)
            echo "Usage: $0 {check|status|reboot [off_time]|enable|disable}"
            exit 1
            ;;
    esac
fi