# Vibe coding warning

This stuff is vibe-coded using Claude Code.
It doesn't work.

---

# PPPoE Watchdog for OpenWRT

Automatic PPPoE connection monitoring and DSL modem reboot system for OpenWRT routers.

## Features

- Monitors PPPoE connection status and internet connectivity
- Automatically reboots DSL modem via Mikrotik CSS610-8P-2S PoE switch
- Intelligent backoff and rate limiting to prevent excessive reboots
- Configurable thresholds and timeouts
- Comprehensive logging
- OpenWRT service integration

## Components

- `pppoe-monitor.sh` - PPPoE connection monitoring
- `mikrotik-control.sh` - SwOS Lite PoE control via HTTP
- `pppoe-watchdog.sh` - Main orchestration script
- `watchdog.conf` - Configuration file
- `files/etc/config/pppoe-watchdog` - UCI configuration file
- `files/etc/init.d/pppoe-watchdog` - OpenWRT init script

## Installation

### Option 1: Install Package (Recommended)
```bash
opkg install pppoe-watchdog_*.ipk
```

### Option 2: Manual Installation
1. Upload script files to your OpenWrt router
2. Copy to system locations:
   ```bash
   cp *.sh /usr/bin/
   cp files/etc/init.d/pppoe-watchdog /etc/init.d/
   cp files/etc/config/pppoe-watchdog /etc/config/
   chmod +x /usr/bin/*.sh /etc/init.d/pppoe-watchdog
   ```

## Configuration

### UCI Configuration (Recommended)
```bash
# Enable the service
uci set pppoe-watchdog.pppoe_watchdog.enabled='1'

# Configure Mikrotik switch
uci set pppoe-watchdog.pppoe_watchdog.mikrotik_ip='192.168.1.x'
uci set pppoe-watchdog.pppoe_watchdog.mikrotik_pass='your_password'
uci set pppoe-watchdog.pppoe_watchdog.dsl_modem_port='1'

# Optional: Adjust monitoring settings
uci set pppoe-watchdog.pppoe_watchdog.check_interval='60'
uci set pppoe-watchdog.pppoe_watchdog.max_failures='3'

# Save configuration
uci commit pppoe-watchdog
```

### View Current Configuration
```bash
uci show pppoe-watchdog
```

## Testing

Test individual components:

```bash
# Test Mikrotik connection
/usr/bin/pppoe-watchdog.sh test-modem

# Test PPPoE monitoring  
/usr/bin/pppoe-watchdog.sh test-pppoe

# Check status
/usr/bin/pppoe-watchdog.sh status
```

## Usage

```bash
# Start service
/etc/init.d/pppoe-watchdog start

# Stop service
/etc/init.d/pppoe-watchdog stop

# Check status
/etc/init.d/pppoe-watchdog status

# View logs
tail -f /var/log/pppoe-watchdog.log
```

## How it Works

1. Monitors PPPoE interface every 60 seconds
2. After 2 failures, attempts PPPoE restart
3. After 3 failures, reboots DSL modem via PoE power cycle
4. Implements exponential backoff and rate limiting
5. Waits 5 minutes for modem boot before resuming monitoring

## Rate Limiting

- Maximum 2 reboots per hour
- Maximum 10 reboots per day
- Exponential backoff between reboots
- Prevents excessive power cycling

## Requirements

- OpenWRT with curl package
- Mikrotik CSS610-8P-2S switch with SwOS Lite
- DSL modem powered via PoE
