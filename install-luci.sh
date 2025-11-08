#!/bin/sh
# =============================================================================
# Auto-Edu LuCI Installer (Script + Web Interface)
# =============================================================================
# Quick Install:
# bash <(curl -fsSL https://raw.githubusercontent.com/Matsumiko/auto-edu-app/main/install-luci.sh)
# =============================================================================

set -e

REPO_RAW="https://raw.githubusercontent.com/Matsumiko/auto-edu-app/main"
TEMP_DIR="/tmp/autoedu-install"

print_success() { echo "✓ $1"; }
print_error() { echo "✗ $1"; }
print_info() { echo "ℹ $1"; }
print_warning() { echo "⚠ $1"; }

clear
cat << 'BANNER'
════════════════════════════════════════════
   AUTO-EDU LUCI INSTALLER
   Script + Web Interface
     Edited Version by: Matsumiko
════════════════════════════════════════════
BANNER
echo ""

[ "$(id -u)" != "0" ] && { print_error "Run as root!"; exit 1; }

# Check if already installed
if [ -f "/usr/lib/lua/luci/controller/autoedu.lua" ]; then
    print_warning "LuCI App already installed!"
    read -p "Reinstall? (y/n) [n]: " reinstall
    if [ "$reinstall" != "y" ]; then
        print_info "Installation cancelled"
        exit 0
    fi
    print_info "Reinstalling..."
fi

# Step 1: Dependencies
echo "▶ STEP 1/7: Installing Dependencies"
opkg update > /dev/null 2>&1
for pkg in python3 python3-urllib python3-json adb curl; do
    opkg list-installed 2>/dev/null | grep -q "^$pkg " && print_success "$pkg OK" || {
        print_info "Installing $pkg..."
        opkg install $pkg > /dev/null 2>&1 && print_success "$pkg installed"
    }
done
echo ""

# Step 2: Download files
echo "▶ STEP 2/7: Downloading LuCI Files"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

print_info "Downloading package structure..."

# Download LuCI files
mkdir -p "$TEMP_DIR/luci/controller"
mkdir -p "$TEMP_DIR/luci/model/cbi/autoedu"
mkdir -p "$TEMP_DIR/luci/view/autoedu"
mkdir -p "$TEMP_DIR/root/etc/config"
mkdir -p "$TEMP_DIR/root/etc/init.d"
mkdir -p "$TEMP_DIR/root/usr/share/autoedu"

curl -fsSL "$REPO_RAW/luci-app/controller/autoedu.lua" -o "$TEMP_DIR/luci/controller/autoedu.lua"
curl -fsSL "$REPO_RAW/luci-app/model/cbi/config.lua" -o "$TEMP_DIR/luci/model/cbi/autoedu/config.lua"
curl -fsSL "$REPO_RAW/luci-app/model/cbi/mode.lua" -o "$TEMP_DIR/luci/model/cbi/autoedu/mode.lua"
curl -fsSL "$REPO_RAW/luci-app/view/dashboard.htm" -o "$TEMP_DIR/luci/view/autoedu/dashboard.htm"
curl -fsSL "$REPO_RAW/luci-app/view/status.htm" -o "$TEMP_DIR/luci/view/autoedu/status.htm"
curl -fsSL "$REPO_RAW/luci-app/view/logs.htm" -o "$TEMP_DIR/luci/view/autoedu/logs.htm"
curl -fsSL "$REPO_RAW/luci-app/etc/config/autoedu" -o "$TEMP_DIR/root/etc/config/autoedu"
curl -fsSL "$REPO_RAW/luci-app/etc/init.d/autoedu" -o "$TEMP_DIR/root/etc/init.d/autoedu"
curl -fsSL "$REPO_RAW/luci-app/usr/share/autoedu/sync_config.sh" -o "$TEMP_DIR/root/usr/share/autoedu/sync_config.sh"
curl -fsSL "$REPO_RAW/auto_edu.py" -o "$TEMP_DIR/root/usr/share/autoedu/auto_edu.py"

print_success "Files downloaded"
echo ""

# Step 3: Install LuCI files
echo "▶ STEP 3/7: Installing LuCI Files"
cp -r "$TEMP_DIR/luci/"* /usr/lib/lua/luci/
print_success "LuCI files installed"
echo ""

# Step 4: Install system files
echo "▶ STEP 4/7: Installing System Files"
cp "$TEMP_DIR/root/etc/config/autoedu" /etc/config/
cp "$TEMP_DIR/root/etc/init.d/autoedu" /etc/init.d/
cp -r "$TEMP_DIR/root/usr/share/autoedu" /usr/share/

chmod +x /etc/init.d/autoedu
chmod +x /usr/share/autoedu/sync_config.sh
chmod +x /usr/share/autoedu/auto_edu.py

print_success "System files installed"
echo ""

# Step 5: Setup
echo "▶ STEP 5/7: Initial Setup"

# Create working directory
mkdir -p /root/Auto-Edu
cp /usr/share/autoedu/auto_edu.py /root/Auto-Edu/
chmod +x /root/Auto-Edu/auto_edu.py

# Initialize UCI
if ! uci -q get autoedu.config >/dev/null 2>&1; then
    uci set autoedu.config=autoedu
    uci set autoedu.config.enabled='0'
    uci set autoedu.config.mode='EFFICIENT'
    uci set autoedu.config.bot_token=''
    uci set autoedu.config.chat_id=''
    uci set autoedu.config.kode_unreg='*808*5*2*1*1#'
    uci set autoedu.config.kode_beli='*808*4*1*1*1*1#'
    uci set autoedu.config.threshold='3'
    uci commit autoedu
fi

# Sync config
/usr/share/autoedu/sync_config.sh

# Enable service
/etc/init.d/autoedu enable

print_success "Setup complete"
echo ""

# Step 6: Restart web server
echo "▶ STEP 6/7: Restarting Web Server"
rm -rf /tmp/luci-*
/etc/init.d/uhttpd restart > /dev/null 2>&1
print_success "Web server restarted"
echo ""

# Step 7: Done
echo "▶ STEP 7/7: Installation Complete!"
echo ""
echo "✓ INSTALLED (LuCI Mode)"
echo ""
echo "🌐 Access Web Interface:"
echo "  http://192.168.1.1"
echo "  Services → Auto-Edu"
echo ""
echo "📋 Next Steps:"
echo "  1. Open LuCI web interface"
echo "  2. Go to Services → Auto-Edu"
echo "  3. Configure Telegram credentials"
echo "  4. Select monitoring mode"
echo "  5. Enable service"
echo ""
echo "📖 Documentation:"
echo "  https://github.com/Matsumiko/auto-edu-app"
echo ""
print_success "Installation successful! 🚀"
echo ""
echo "Edited Version by: Matsumiko"

# Cleanup
rm -rf "$TEMP_DIR"
