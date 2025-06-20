#!/bin/sh

# Installation script for PPPoE Watchdog on OpenWRT

INSTALL_DIR="/usr/bin"
INIT_DIR="/etc/init.d"
CONFIG_DIR="/etc"

echo "Installing PPPoE Watchdog..."

# Copy scripts
cp pppoe-monitor.sh "$INSTALL_DIR/"
cp mikrotik-control.sh "$INSTALL_DIR/"
cp pppoe-watchdog.sh "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/pppoe-monitor.sh"
chmod +x "$INSTALL_DIR/mikrotik-control.sh" 
chmod +x "$INSTALL_DIR/pppoe-watchdog.sh"

# Copy init script
cp pppoe-watchdog.init "$INIT_DIR/pppoe-watchdog"
chmod +x "$INIT_DIR/pppoe-watchdog"

# Copy config file if it doesn't exist
if [ ! -f "$CONFIG_DIR/watchdog.conf" ] && [ -f "watchdog.conf" ]; then
    cp watchdog.conf "$CONFIG_DIR/"
fi

# Enable service
/etc/init.d/pppoe-watchdog enable

echo "Installation complete!"
echo ""
echo "Next steps:"
echo "1. Edit /etc/watchdog.conf with your Mikrotik switch details"
echo "2. Test the setup:"
echo "   /usr/bin/pppoe-watchdog.sh test-modem"
echo "   /usr/bin/pppoe-watchdog.sh test-pppoe"
echo "3. Start the service:"
echo "   /etc/init.d/pppoe-watchdog start"