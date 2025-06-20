#!/bin/sh

# PPPoE Connection Monitor
# Checks if PPPoE interface is up and has connectivity

PPP_INTERFACE="pppoe-wan"
TEST_HOST="8.8.8.8"
TIMEOUT=5

check_pppoe_interface() {
    local interface="$1"
    
    # Check if interface exists and is up
    if ! ip link show "$interface" >/dev/null 2>&1; then
        return 1
    fi
    
    # Check if interface has an IP address
    if ! ip addr show "$interface" | grep -q "inet "; then
        return 1
    fi
    
    return 0
}

check_internet_connectivity() {
    local host="$1"
    local timeout="$2"
    
    # Try to ping through the PPPoE interface
    if ping -I "$PPP_INTERFACE" -c 1 -W "$timeout" "$host" >/dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

# Main check function
check_pppoe_connection() {
    # First check if PPPoE interface is up
    if ! check_pppoe_interface "$PPP_INTERFACE"; then
        echo "PPPoE interface $PPP_INTERFACE is down"
        return 1
    fi
    
    # Then check internet connectivity
    if ! check_internet_connectivity "$TEST_HOST" "$TIMEOUT"; then
        echo "PPPoE interface $PPP_INTERFACE is up but no internet connectivity"
        return 1
    fi
    
    echo "PPPoE connection is working"
    return 0
}

# If script is called directly, run the check
if [ "${0##*/}" = "pppoe-monitor.sh" ]; then
    check_pppoe_connection
    exit $?
fi