#!/bin/sh
# =============================================================================
# Auto-Edu LuCI Uninstaller (Remove Web Interface)
# =============================================================================
# bash <(curl -fsSL https://raw.githubusercontent.com/Matsumiko/auto-edu-app/main/uninstall-luci.sh)
# =============================================================================

set -e

print_success() { echo "✓ $1"; }
print_error() { echo "✗ $1"; }
print_warning() { echo "⚠ $1"; }
print_info() { echo "ℹ $1"; }

clear
cat << 'BANNER'
════════════════════════════════════════════
   AUTO-EDU LUCI UNINSTALLER
════════════════════════════════════════════
BANNER
echo ""

if [ ! -f "/usr/lib/lua/luci/controller/autoedu.lua" ]; then
    print_warning "LuCI App not installed"
    exit 0
fi

echo "⚠️  This will remove:"
echo "  • LuCI Web Interface"
echo "  • UCI Configuration"
echo "  • Service Scripts"
echo ""
read -p "Keep CLI script? (y/n) [y]: " keep_script
keep_script=${keep_script:-y}

if [ "$keep_script" = "n" ]; then
    echo ""
    echo "⚠️  This will also remove:"
    echo "  • /root/Auto-Edu/"
    echo "  • Python script"
    echo "  • All data"
fi

echo ""
read -p "Continue? (y/n) [n]: " confirm
if [ "$confirm" != "y" ]; then
    print_info "Cancelled"
    exit 0
fi

echo ""
print_info "Uninstalling LuCI App..."
echo ""

# Stop service
print_info "Stopping service..."
/etc/init.d/autoedu stop 2>/dev/null || true
/etc/init.d/autoedu disable 2>/dev/null || true
print_success "Service stopped"

# Remove cron
print_info "Removing cron..."
crontab -l 2>/dev/null | grep -v "auto_edu.py" | crontab - 2>/dev/null || true
print_success "Cron removed"

# Backup config
read -p "Backup config? (y/n) [y]: " backup
backup=${backup:-y}
if [ "$backup" = "y" ]; then
    BACKUP_FILE="/tmp/autoedu_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    tar czf "$BACKUP_FILE" /root/Auto-Edu /etc/config/autoedu 2>/dev/null
    print_success "Backup: $BACKUP_FILE"
fi

# Remove LuCI files
print_info "Removing LuCI files..."
rm -rf /usr/lib/lua/luci/controller/autoedu.lua
rm -rf /usr/lib/lua/luci/model/cbi/autoedu
rm -rf /usr/lib/lua/luci/view/autoedu
print_success "LuCI files removed"

# Remove system files
print_info "Removing system files..."
rm -f /etc/init.d/autoedu
rm -f /etc/config/autoedu
rm -rf /usr/share/autoedu
print_success "System files removed"

# Remove script if requested
if [ "$keep_script" = "n" ]; then
    print_info "Removing script..."
    rm -rf /root/Auto-Edu
    rm -f /tmp/auto_edu.log
    rm -f /tmp/auto_edu_last_renewal
    print_success "Script removed"
fi

# Clear cache
print_info "Clearing cache..."
rm -rf /tmp/luci-*
/etc/init.d/uhttpd restart > /dev/null 2>&1
print_success "Cache cleared"

echo ""
print_success "LuCI App uninstalled!"
echo ""

if [ "$keep_script" = "y" ]; then
    echo "✓ CLI script preserved at: /root/Auto-Edu/"
    echo ""
    echo "To use CLI mode:"
    echo "  Add cron manually:"
    echo "  */3 * * * * AUTO_EDU_ENV=/root/Auto-Edu/auto_edu.env python3 /root/Auto-Edu/auto_edu.py"
    echo ""
fi

[ "$backup" = "y" ] && echo "Backup: $BACKUP_FILE"
echo ""
