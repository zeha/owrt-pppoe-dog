# OpenWrt package Makefile for PPPoE Watchdog

include $(TOPDIR)/rules.mk

PKG_NAME:=pppoe-watchdog
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Your Name <your.email@example.com>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/pppoe-watchdog
	SECTION:=net
	CATEGORY:=Network
	TITLE:=PPPoE connection watchdog with automatic modem reboot
	EXTRA_DEPENDS:=+curl
	PKGARCH:=all
endef

define Package/pppoe-watchdog/description
	Monitors PPPoE connection and automatically reboots DSL modem
	via Mikrotik PoE switch when connection fails. Includes
	intelligent backoff and rate limiting.
endef

define Package/pppoe-watchdog/conffiles
/etc/config/pppoe-watchdog
endef

define Build/Prepare
	$(Build/Prepare/Default)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/pppoe-watchdog/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./pppoe-monitor.sh $(1)/usr/bin/
	$(INSTALL_BIN) ./mikrotik-control.sh $(1)/usr/bin/
	$(INSTALL_BIN) ./pppoe-watchdog.sh $(1)/usr/bin/
	
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/pppoe-watchdog $(1)/etc/init.d/pppoe-watchdog
	
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/pppoe-watchdog $(1)/etc/config/pppoe-watchdog
endef

define Package/pppoe-watchdog/postinst
#!/bin/sh
# Enable service on installation
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/pppoe-watchdog enable
	echo "PPPoE Watchdog installed. Configure with:"
	echo "uci set pppoe-watchdog.pppoe_watchdog.enabled='1'"
	echo "uci set pppoe-watchdog.pppoe_watchdog.mikrotik_ip='192.168.1.x'"
	echo "uci commit pppoe-watchdog"
	echo "/etc/init.d/pppoe-watchdog start"
}
endef

define Package/pppoe-watchdog/prerm
#!/bin/sh
# Stop and disable service before removal
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/pppoe-watchdog stop
	/etc/init.d/pppoe-watchdog disable
}
endef

$(eval $(call BuildPackage,pppoe-watchdog))
