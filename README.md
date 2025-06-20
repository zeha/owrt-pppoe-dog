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
- `pppoe-watchdog.init` - OpenWRT init script
- `install.sh` - Installation script

## Installation

1. Upload all files to your OpenWRT router
2. Run the installation script:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

## Configuration

Edit `/etc/watchdog.conf`:

```bash
# Mikrotik Switch Settings
MIKROTIK_IP="192.168.1.x"          # Your switch IP
MIKROTIK_PASS="your_password"       # SwOS password  
DSL_MODEM_PORT="1"                 # PoE port for modem

# Adjust other settings as needed
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