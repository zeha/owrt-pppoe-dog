# OpenWrt package Makefile for PPPoE Watchdog

include $(TOPDIR)/rules.mk

PKG_NAME:=pppoe-watchdog
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Your Name <your.email@example.com>
PKG_LICENSE:=GPL-2.0
PKG_LICENSE_FILES:=

include $(INCLUDE_DIR)/package.mk

define Package/pppoe-watchdog
	SECTION:=net
	CATEGORY:=Network
	TITLE:=PPPoE connection watchdog with automatic modem reboot
	DEPENDS:=+curl
	PKGARCH:=all
endef

define Package/pppoe-watchdog/description
	Monitors PPPoE connection and automatically reboots DSL modem
	via Mikrotik PoE switch when connection fails. Includes
	intelligent backoff and rate limiting.
endef

define Package/pppoe-watchdog/conffiles
/etc/watchdog.conf
endef

define Build/Compile
	# Nothing to compile - shell scripts only
endef

define Package/pppoe-watchdog/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./pppoe-monitor.sh $(1)/usr/bin/
	$(INSTALL_BIN) ./mikrotik-control.sh $(1)/usr/bin/
	$(INSTALL_BIN) ./pppoe-watchdog.sh $(1)/usr/bin/
	
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./pppoe-watchdog.init $(1)/etc/init.d/pppoe-watchdog
	
	$(INSTALL_DIR) $(1)/etc
	$(INSTALL_CONF) ./watchdog.conf $(1)/etc/
endef

define Package/pppoe-watchdog/postinst
#!/bin/sh
# Enable service on installation
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/pppoe-watchdog enable
	echo "PPPoE Watchdog installed. Configure /etc/watchdog.conf and start with:"
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