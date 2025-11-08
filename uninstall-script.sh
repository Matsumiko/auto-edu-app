#!/bin/sh
# =============================================================================
# Auto-Edu Script Uninstaller (CLI Only)
# =============================================================================
# bash <(curl -fsSL https://raw.githubusercontent.com/Matsumiko/auto-edu-app/main/uninstall-script.sh)
# =============================================================================

set -e

print_success() { echo "✓ $1"; }
print_error() { echo "✗ $1"; }
print_warning() { echo "⚠ $1"; }
print_info() { echo "ℹ $1"; }

clear
cat << 'BANNER'
════════════════════════════════════════════
   AUTO-EDU SCRIPT UNINSTALLER
════════════════════════════════════════════
BANNER
echo ""

# Check if LuCI installed
if [ -f "/usr/lib/lua/luci/controller/autoedu.lua" ]; then
    print_error "LuCI App is installed!"
    echo ""
    echo "Please use: uninstall-luci.sh"
    echo "Or run: bash <(curl -fsSL https://raw.githubusercontent.com/Matsumiko/auto-edu-app/main/uninstall-luci.sh)"
    echo ""
    exit 1
fi

if [ ! -d "/root/Auto-Edu" ]; then
    print_warning "Auto-Edu not installed"
    exit 0
fi

read -p "Uninstall Auto-Edu Script? (y/n) [n]: " confirm
if [ "$confirm" != "y" ]; then
    print_info "Cancelled"
    exit 0
fi

echo ""
print_info "Uninstalling..."
echo ""

# Remove cron
print_info "Removing cron job..."
crontab -l 2>/dev/null | grep -v "auto_edu.py" | crontab - 2>/dev/null || true
print_success "Cron removed"

# Stop processes
print_info "Stopping processes..."
pkill -f "auto_edu.py" 2>/dev/null || true
print_success "Processes stopped"

# Backup option
read -p "Backup config before delete? (y/n) [y]: " backup
backup=${backup:-y}
if [ "$backup" = "y" ]; then
    BACKUP_FILE="/tmp/auto_edu_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    tar czf "$BACKUP_FILE" /root/Auto-Edu 2>/dev/null
    print_success "Backup: $BACKUP_FILE"
fi

# Remove files
print_info "Removing files..."
rm -rf /root/Auto-Edu
rm -f /tmp/auto_edu.log
rm -f /tmp/auto_edu_last_renewal
print_success "Files removed"

echo ""
print_success "Auto-Edu Script uninstalled!"
echo ""
[ "$backup" = "y" ] && echo "Backup: $BACKUP_FILE"
echo ""
