#!/bin/sh
# Sync UCI config to .env file
# This ensures web UI changes are reflected in the Python script

UCI_CONFIG="autoedu"
ENV_FILE="/root/Auto-Edu/auto_edu.env"
ENV_DIR="/root/Auto-Edu"

# Create directory if not exists
mkdir -p "$ENV_DIR"

# Load UCI config
. /lib/functions.sh
config_load "$UCI_CONFIG"

# Get values from UCI
get_config() {
	local option=$1
	local default=$2
	local value
	
	config_get value config "$option" "$default"
	echo "$value"
}

# Read current values
ENABLED=$(get_config enabled 0)
MODE=$(get_config mode 'EFFICIENT')
BOT_TOKEN=$(get_config bot_token '')
CHAT_ID=$(get_config chat_id '')
KODE_UNREG=$(get_config kode_unreg '*808*5*2*1*1#')
KODE_BELI=$(get_config kode_beli '*808*4*1*1*1*1#')
THRESHOLD=$(get_config threshold '3')
JEDA_USSD=$(get_config jeda_ussd '10')
TIMEOUT_ADB=$(get_config timeout_adb '15')
NOTIF_STARTUP=$(get_config notif_startup '0')
NOTIF_SAFE=$(get_config notif_safe '0')
NOTIF_DETAIL=$(get_config notif_detail '1')
LOG_FILE=$(get_config log_file '/tmp/auto_edu.log')
MAX_LOG_SIZE=$(get_config max_log_size '102400')

# Convert 0/1 to false/true for Python
convert_bool() {
	if [ "$1" = "1" ]; then
		echo "true"
	else
		echo "false"
	fi
}

NOTIF_STARTUP_BOOL=$(convert_bool "$NOTIF_STARTUP")
NOTIF_SAFE_BOOL=$(convert_bool "$NOTIF_SAFE")
NOTIF_DETAIL_BOOL=$(convert_bool "$NOTIF_DETAIL")

# Write .env file
cat > "$ENV_FILE" << EOF
# Auto Edu Config - Synced from UCI
# Last sync: $(date)
# Edited Version by: Matsumiko

# ============================================================================
# TELEGRAM CONFIGURATION
# ============================================================================
BOT_TOKEN=$BOT_TOKEN
CHAT_ID=$CHAT_ID

# ============================================================================
# USSD CODES
# ============================================================================
KODE_UNREG=$KODE_UNREG
KODE_BELI=$KODE_BELI

# ============================================================================
# QUOTA SETTINGS
# ============================================================================
THRESHOLD_KUOTA_GB=$THRESHOLD

# ============================================================================
# MONITORING MODE CONFIGURATION
# ============================================================================
# Mode: EFFICIENT (default) atau AGGRESSIVE (extreme)
MONITORING_MODE=$MODE

# EFFICIENT Mode Settings (auto-applied when mode=EFFICIENT)
JUMLAH_SMS_CEK=3
SMS_MAX_AGE_MINUTES=15

# AGGRESSIVE Mode Settings (auto-applied when mode=AGGRESSIVE)
JUMLAH_SMS_CEK_AGGRESSIVE=5
SMS_MAX_AGE_AGGRESSIVE=5

# ============================================================================
# TIMING SETTINGS (seconds)
# ============================================================================
JEDA_USSD=$JEDA_USSD
TIMEOUT_ADB=$TIMEOUT_ADB

# ============================================================================
# NOTIFICATION SETTINGS
# ============================================================================
NOTIF_KUOTA_AMAN=$NOTIF_SAFE_BOOL
NOTIF_STARTUP=$NOTIF_STARTUP_BOOL
NOTIF_DETAIL=$NOTIF_DETAIL_BOOL

# ============================================================================
# LOGGING
# ============================================================================
LOG_FILE=$LOG_FILE
MAX_LOG_SIZE=$MAX_LOG_SIZE
EOF

# Set permissions
chmod 600 "$ENV_FILE"

logger -t autoedu "Config synced: UCI -> $ENV_FILE (Mode: $MODE)"

exit 0
