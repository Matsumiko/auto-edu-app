#!/bin/sh
# =============================================================================
# Auto-Edu Script Installer (CLI Only)
# =============================================================================
# Quick Install:
# bash <(curl -fsSL https://raw.githubusercontent.com/Matsumiko/auto-edu-app/main/install-script.sh)
# =============================================================================

set -e

REPO_RAW="https://raw.githubusercontent.com/Matsumiko/auto-edu-app/main"
INSTALL_DIR="/root/Auto-Edu"
SCRIPT_FILE="$INSTALL_DIR/auto_edu.py"
ENV_FILE="$INSTALL_DIR/auto_edu.env"
LOG_FILE="/tmp/auto_edu.log"

print_success() { echo "✓ $1"; }
print_error() { echo "✗ $1"; }
print_warning() { echo "⚠ $1"; }
print_info() { echo "ℹ $1"; }

clear
cat << 'BANNER'
════════════════════════════════════════════
   AUTO-EDU SCRIPT INSTALLER (CLI)
     Edited Version by: Matsumiko
════════════════════════════════════════════
BANNER
echo ""

[ "$(id -u)" != "0" ] && { print_error "Run as root!"; exit 1; }

# Check if LuCI app already installed
if [ -f "/etc/init.d/autoedu" ] && [ -f "/usr/lib/lua/luci/controller/autoedu.lua" ]; then
    print_warning "LuCI App Auto-Edu is already installed!"
    echo ""
    echo "You have 2 options:"
    echo "1. Keep LuCI app (manage via web)"
    echo "2. Remove LuCI app and install CLI only"
    echo ""
    read -p "Your choice (1/2) [1]: " choice
    choice=${choice:-1}
    
    if [ "$choice" = "2" ]; then
        print_info "Removing LuCI app..."
        bash <(curl -fsSL "$REPO_RAW/uninstall-luci.sh")
        echo ""
    else
        print_info "Keeping LuCI app. You can manage via web interface."
        exit 0
    fi
fi

# Step 1: Dependencies
echo "▶ STEP 1/8: Installing Dependencies"
opkg update > /dev/null 2>&1 && print_success "Updated" || print_warning "Skip update"
for pkg in python3 curl; do
    opkg list-installed 2>/dev/null | grep -q "^$pkg " && print_success "$pkg OK" || {
        print_info "Installing $pkg..."
        opkg install $pkg > /dev/null 2>&1 && print_success "$pkg installed" || { print_error "Failed $pkg"; exit 1; }
    }
done
command -v adb > /dev/null 2>&1 && print_success "ADB: $(command -v adb)" || print_warning "ADB not found"
echo ""

# Step 2: Create directory
echo "▶ STEP 2/8: Creating Directory"
if [ -d "$INSTALL_DIR" ]; then
    print_warning "$INSTALL_DIR exists"
    read -p "Backup and recreate? (y/n) [n]: " recreate
    if [ "$recreate" = "y" ]; then
        mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$INSTALL_DIR"
        print_success "Recreated with backup"
    fi
else
    mkdir -p "$INSTALL_DIR"
    print_success "Created: $INSTALL_DIR"
fi
echo ""

# Step 3: Download script
echo "▶ STEP 3/8: Downloading Script"
if curl -fsSL "$REPO_RAW/auto_edu.py" -o "$SCRIPT_FILE" 2>/dev/null; then
    chmod +x "$SCRIPT_FILE"
    print_success "Downloaded: $SCRIPT_FILE"
else
    print_error "Download failed! Check connection"
    exit 1
fi
echo ""

# Step 4: Configure
echo "▶ STEP 4/8: Configuration"
if [ -f "$ENV_FILE" ]; then
    read -p "Config exists. Use old? (y/n) [y]: " use_old
    use_old=${use_old:-y}
    [ "$use_old" = "y" ] && { print_success "Using existing config"; echo ""; } && SKIP_CONFIG=1
fi

if [ "$SKIP_CONFIG" != "1" ]; then
    echo "PANDUAN:"
    echo "📱 Bot Token: @BotFather → /newbot"
    echo "🆔 Chat ID: @userinfobot → Copy ID"
    echo ""
    
    while true; do
        printf "Bot Token: "; read BOT_TOKEN
        [ -n "$BOT_TOKEN" ] && break || print_error "Required!"
    done
    
    while true; do
        printf "Chat ID: "; read CHAT_ID
        [ -n "$CHAT_ID" ] && break || print_error "Required!"
    done
    
    printf "USSD Unreg [*808*5*2*1*1#]: "; read KODE_UNREG
    KODE_UNREG=${KODE_UNREG:-"*808*5*2*1*1#"}
    
    printf "USSD Beli [*808*4*1*1*1*1#]: "; read KODE_BELI
    KODE_BELI=${KODE_BELI:-"*808*4*1*1*1*1#"}
    
    printf "Threshold GB [3]: "; read THRESHOLD
    THRESHOLD=${THRESHOLD:-3}
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "MONITORING MODE SELECTION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1) 🟢 EFFICIENT Mode (Recommended)"
    echo "   • Cron: Every 3 minutes"
    echo "   • SMS Check: 3 messages"
    echo "   • Best for: Normal to heavy usage"
    echo ""
    echo "2) 🔴 AGGRESSIVE Mode (Extreme)"
    echo "   • Cron: Every 1 minute"
    echo "   • SMS Check: 5 messages"
    echo "   • Best for: Extreme heavy usage"
    echo ""
    printf "Pilih mode [1]: "; read mode_choice
    mode_choice=${mode_choice:-1}
    
    if [ "$mode_choice" = "2" ]; then
        MONITORING_MODE="AGGRESSIVE"
        CRON_INTERVAL="*/1 * * * *"
        print_warning "AGGRESSIVE mode selected"
    else
        MONITORING_MODE="EFFICIENT"
        CRON_INTERVAL="*/3 * * * *"
        print_success "EFFICIENT mode selected"
    fi
    
    echo ""
    printf "Send notif on startup? (y/n) [n]: "; read NOTIF_STARTUP_INPUT
    NOTIF_STARTUP_INPUT=${NOTIF_STARTUP_INPUT:-n}
    [ "$NOTIF_STARTUP_INPUT" = "y" ] && NOTIF_STARTUP="true" || NOTIF_STARTUP="false"
    
    printf "Send notif when quota safe? (y/n) [n]: "; read NOTIF_AMAN_INPUT
    NOTIF_AMAN_INPUT=${NOTIF_AMAN_INPUT:-n}
    [ "$NOTIF_AMAN_INPUT" = "y" ] && NOTIF_KUOTA_AMAN="true" || NOTIF_KUOTA_AMAN="false"
    echo ""
    
    cat > "$ENV_FILE" << ENVEOF
# Auto Edu Config - $(date)
BOT_TOKEN=$BOT_TOKEN
CHAT_ID=$CHAT_ID
KODE_UNREG=$KODE_UNREG
KODE_BELI=$KODE_BELI
THRESHOLD_KUOTA_GB=$THRESHOLD
MONITORING_MODE=$MONITORING_MODE
JUMLAH_SMS_CEK=3
SMS_MAX_AGE_MINUTES=15
JUMLAH_SMS_CEK_AGGRESSIVE=5
SMS_MAX_AGE_AGGRESSIVE=5
JEDA_USSD=10
TIMEOUT_ADB=15
NOTIF_KUOTA_AMAN=$NOTIF_KUOTA_AMAN
NOTIF_STARTUP=$NOTIF_STARTUP
NOTIF_DETAIL=true
LOG_FILE=$LOG_FILE
MAX_LOG_SIZE=102400
ENVEOF
    chmod 600 "$ENV_FILE"
    print_success "Config saved"
fi
echo ""

# Step 5: Test
echo "▶ STEP 5/8: Testing"
read -p "Run test? (y/n) [y]: " test
test=${test:-y}
if [ "$test" = "y" ]; then
    print_info "Testing..."
    echo "══════════════════════"
    AUTO_EDU_ENV="$ENV_FILE" python3 "$SCRIPT_FILE" && print_success "Test OK!" || print_warning "Check errors"
    echo "══════════════════════"
fi
echo ""

# Step 6: Cron
echo "▶ STEP 6/8: Setup Cron"
if [ -n "$CRON_INTERVAL" ]; then
    crontab -l 2>/dev/null | grep -v "auto_edu.py" | crontab - 2>/dev/null || true
    (crontab -l 2>/dev/null; echo "$CRON_INTERVAL AUTO_EDU_ENV=$ENV_FILE python3 $SCRIPT_FILE") | crontab -
    /etc/init.d/cron restart > /dev/null 2>&1 || true
    print_success "Cron: $CRON_INTERVAL"
fi
echo ""

# Step 7: Done
echo "▶ STEP 7/8: Installation Complete!"
echo ""
echo "✓ INSTALLED (CLI Mode)"
echo ""
echo "📂 Directory: $INSTALL_DIR"
echo "📝 Log: $LOG_FILE"
echo "⏰ Cron: $CRON_INTERVAL"
echo ""
echo "Commands:"
echo "  Test: python3 $SCRIPT_FILE"
echo "  Logs: tail -f $LOG_FILE"
echo "  Edit: vi $ENV_FILE"
echo ""
echo "Want Web Interface?"
echo "  bash <(curl -fsSL $REPO_RAW/install-luci.sh)"
echo ""
print_success "Auto-Edu running! 🚀"
echo ""
echo "Edited Version by: Matsumiko"
