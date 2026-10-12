#!/bin/sh
# Refresh desktop caches and apply the /dev/uinput access rule now, so typing
# into apps works without a reboot. Each step is optional on minimal systems.
if command -v udevadm >/dev/null 2>&1; then
    udevadm control --reload-rules 2>/dev/null && udevadm trigger --subsystem-match=misc --sysname-match=uinput 2>/dev/null
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor 2>/dev/null
fi
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q /usr/share/applications 2>/dev/null
fi
exit 0
