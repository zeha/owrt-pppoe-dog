#!/bin/sh

# Mikrotik Switch PoE Control Script
# Controls PoE power via SwOS Lite JSON API

# Default configuration
MIKROTIK_IP=""
MIKROTIK_PASS=""
DSL_MODEM_PORT="1"

# Try to load from config file
SCRIPT_DIR="$(dirname "$0")"
CONFIG_FILE="$SCRIPT_DIR/watchdog.conf"

# Load configuration if exists
# shellcheck source=/dev/null
if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
fi

# Also check system config location
if [ -f "/etc/watchdog.conf" ]; then
    # shellcheck source=/dev/null
    . "/etc/watchdog.conf"
fi

# Get authentication token (if needed)
get_auth_token() {
    local response
    response=$(curl -s "http://$MIKROTIK_IP/")
    
    # Try to extract token, but it might not exist for passwordless switches
    echo "$response" | grep -o 'var token="[^"]*"' | cut -d'"' -f2
}

# SwOS JSON API request
swos_api_request() {
    local json_data="$1"
    
    # Use HTTP Digest Auth with admin username and configured password
    local auth_user="admin"
    local auth_pass="${MIKROTIK_PASS}"
    
    curl -s --digest -u "$auth_user:$auth_pass" -X POST \
        -H "Content-Type: application/json" \
        -H "X-Requested-With: XMLHttpRequest" \
        --data-raw "$json_data" \
        "http://$MIKROTIK_IP/api.b"
}

# Test authentication with SwOS
swos_login() {
    local auth_user="admin"
    local auth_pass="${MIKROTIK_PASS}"
    local response
    
    # Test digest auth access
    response=$(curl -s --digest -u "$auth_user:$auth_pass" "http://$MIKROTIK_IP/sys.b" 2>/dev/null)
    
    if echo "$response" | grep -q "401\|Unauthorized"; then
        echo "Login failed - check switch credentials"
        return 1
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
    local auth_user="admin"
    local auth_pass="${MIKROTIK_PASS}"
    
    # Try different endpoints with HTTP Digest Auth
    response=$(curl -s --digest -u "$auth_user:$auth_pass" "http://$MIKROTIK_IP/sys.b" 2>/dev/null)
    if [ -z "$response" ] || echo "$response" | grep -q "401\|Unauthorized"; then
        response=$(curl -s --digest -u "$auth_user:$auth_pass" "http://$MIKROTIK_IP/poe.b" 2>/dev/null)
    fi
    
    if [ -z "$response" ] || echo "$response" | grep -q "401\|Unauthorized"; then
        echo "Failed to get PoE status - authentication failed"
        return 1
    fi
    
    # Parse response for current PoE settings
    # Response format: {i01:0x000f140b,...} where i01 contains PoE status
    local poe_status
    poe_status=$(echo "$response" | sed -n 's/.*i01:\(0x[0-9a-fA-F]*\).*/\1/p')
    
    if [ -n "$poe_status" ]; then
        echo "PoE status register: $poe_status"
        # Convert hex to binary to show individual port status
        # This is a hex value representing PoE port states
        return 0
    else
        echo "Could not parse PoE status from response"
        return 1
    fi
}

# Control PoE on specific port via SwOS API
control_poe() {
    local port="$1"
    local action="$2"  # "on" or "off"
    local auth_user="admin"
    local auth_pass="${MIKROTIK_PASS}"
    
    # SwOS uses form-based PoE control, not JSON
    # Format: poe{port}={value} where value is 0=off, 1=auto, 2=on
    local poe_value
    if [ "$action" = "on" ]; then
        poe_value="2"  # Force on
    else
        poe_value="0"  # Off
    fi
    
    # Submit PoE control via POST form
    local response
    response=$(curl -s --digest -u "$auth_user:$auth_pass" \
        -X POST \
        -d "poe$port=$poe_value" \
        -d "apply=Apply" \
        "http://$MIKROTIK_IP/poe.b")
    
    # Check if successful (no error in response)
    if echo "$response" | grep -q -i "error\|fail"; then
        echo "Failed to control PoE on port $port"
        return 1
    fi
    
    return 0
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

# Command line interface
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