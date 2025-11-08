# 🤖 Auto-Edu App

<div align="center">

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/Matsumiko/auto-edu-app/releases)
[![Dual Mode](https://img.shields.io/badge/mode-dual-success.svg)](#-dual-mode-system)
[![Installation](https://img.shields.io/badge/install-one--liner-brightgreen.svg)](#-installation)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

**Automatic Quota Monitoring & Renewal with Dual Mode Support**

*Never worry about running out of quota again!*

[Installation](#-installation) • [Features](#-features) • [Documentation](#-documentation) • [Support](#-support)

</div>

---

## 📖 About

Auto-Edu App is an intelligent system that monitors your Edu quota via SMS and automatically renews when running low. **Version 2.0** introduces **Dual Mode System** and **optional Web Interface** for complete flexibility.

---

## 🚀 Installation

Choose your preferred method:

### Method 1: CLI Only (Quick & Light) ⚡

**One-liner install:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Matsumiko/auto-edu-app/main/install-script.sh)
```

**Best for:**
- CLI users  
- Minimal installation  
- SSH management  

### Method 2: Web Interface (Full Control) 🌐

**One-liner install:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Matsumiko/auto-edu-app/main/install-luci.sh)
```

**Best for:**
- GUI users  
- Visual monitoring  
- Browser management  

**Features:**
- 📊 Real-time dashboard
- ⚙️ Web-based configuration
- 📜 Live log viewer
- 🎚️ Mode switching via UI

---

## ✨ Features

### Core Features
✅ **Dual Mode System** - EFFICIENT (normal) & AGGRESSIVE (extreme)  
✅ **Auto Monitoring** - Check quota via SMS  
✅ **Auto Renewal** - Buy new package when low  
✅ **Telegram Alerts** - Real-time notifications  
✅ **Anti Double Renewal** - Smart SMS filtering  
✅ **Heavy Usage Support** - Handle 30GB/5-30 minutes  
✅ **Configurable** - 15+ parameters to customize  

### Web Interface (LuCI) Features
✅ **Dashboard** - Service status & statistics  
✅ **Configuration** - Form-based settings  
✅ **Mode Selection** - Visual mode switching  
✅ **System Status** - Connection diagnostics  
✅ **Live Logs** - Real-time log viewer  
✅ **Auto-refresh** - Updates every 30 seconds  

---

## 🎚️ Dual Mode System

### 🟢 EFFICIENT Mode (Default)
```
• Cron: Every 3 minutes
• SMS: 3 messages checked
• Max Age: 15 minutes
• CPU: ~1% usage
• Handle: 30GB/30+ minutes
• Best for: 95% users
```

### 🔴 AGGRESSIVE Mode (Extreme)
```
• Cron: Every 1 minute
• SMS: 5 messages checked
• Max Age: 5 minutes
• CPU: ~3% usage
• Handle: 30GB/5-10 minutes
• Best for: Extreme heavy usage
```

---

## 📋 Requirements

### Hardware
- Router OpenWrt with USB port
- Android device with USB debugging
- USB cable (OTG/standard)

### Software
```bash
opkg install python3 adb curl
```

### Telegram
- Bot Token from [@BotFather](https://t.me/BotFather)
- Chat ID from [@userinfobot](https://t.me/userinfobot)

---

## 🗑️ Uninstallation

### Remove CLI Script
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Matsumiko/auto-edu-app/main/uninstall-script.sh)
```

### Remove Web Interface
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Matsumiko/auto-edu-app/main/uninstall-luci.sh)
```

---

## 📊 Comparison

| Feature | CLI Mode | LuCI Mode |
|---------|----------|-----------|
| **Installation** | Quick (~1 min) | Medium (~3 min) |
| **Management** | SSH/Files | Web Browser |
| **Monitoring** | Logs only | Dashboard + Logs |
| **Configuration** | Edit .env | Web forms |
| **Mode Switch** | Edit file + restart | One-click |
| **Diagnostics** | Manual | Built-in tests |
| **Size** | ~30KB | ~100KB |
| **Best For** | Advanced users | All users |

---

## 📂 Repository Structure

```
auto-edu-app/
├── install-script.sh           # CLI installer
├── install-luci.sh             # LuCI installer  
├── uninstall-script.sh         # CLI uninstaller
├── uninstall-luci.sh           # LuCI uninstaller
├── auto_edu.py                 # Main Python script (26KB)
├── README.md                   # This file
│
└── luci-app/                   # LuCI package files
    ├── controller/             # Routing & API
    ├── model/cbi/              # Configuration forms
    ├── view/                   # HTML templates
    ├── etc/                    # System configs
    └── usr/share/autoedu/      # Scripts
```

---

## 🎮 Quick Start

### After Installation (CLI):
```bash
# Test script
python3 /root/Auto-Edu/auto_edu.py

# View logs
tail -f /tmp/auto_edu.log

# Edit config
vi /root/Auto-Edu/auto_edu.env
```

### After Installation (LuCI):
```
1. Open browser: http://192.168.1.1
2. Login to LuCI
3. Go to: Services → Auto-Edu
4. Configure settings
5. Enable service
```

---

## 🔄 Switching Methods

### CLI → LuCI Upgrade:
```bash
# Install LuCI on top of CLI
bash <(curl -fsSL https://raw.githubusercontent.com/Matsumiko/auto-edu-app/main/install-luci.sh)

# Existing config will be imported automatically!
```

### LuCI → CLI Downgrade:
```bash
# Uninstall LuCI (keep script)
bash <(curl -fsSL https://raw.githubusercontent.com/Matsumiko/auto-edu-app/main/uninstall-luci.sh)

# When prompted, choose "Keep CLI script"
```

---

## 📝 Configuration

### CLI Mode:
Edit `/root/Auto-Edu/auto_edu.env`:
```bash
BOT_TOKEN=your_token
CHAT_ID=your_chat_id
MONITORING_MODE=EFFICIENT  # or AGGRESSIVE
THRESHOLD_KUOTA_GB=3
```

### LuCI Mode:
1. Go to **Services → Auto-Edu → Configuration**
2. Fill in the form
3. Click **Save & Apply**
4. Config syncs automatically to `.env` file!

---

## 🔍 Troubleshooting

### Script not running?
```bash
# Check cron
crontab -l | grep auto_edu

# Check service (LuCI)
/etc/init.d/autoedu status

# View logs
tail -f /tmp/auto_edu.log
```

### Web interface not showing?
```bash
# Clear cache
rm -rf /tmp/luci-*

# Restart web server
/etc/init.d/uhttpd restart

# Refresh browser (Ctrl+F5)
```

### Mode not changing?
```bash
# CLI: Edit config manually
vi /root/Auto-Edu/auto_edu.env
# Change: MONITORING_MODE=AGGRESSIVE

# Update cron
crontab -e
# Change: */1 * * * * (for AGGRESSIVE)

# LuCI: Use Mode Selection tab
# Click and apply - automatic!
```

---

## 📖 Documentation

- **Installation Guides**: [install-script.sh](install-script.sh) | [install-luci.sh](install-luci.sh)
- **LuCI Manual Install**: [luci-app/MANUAL_INSTALL.md](luci-app/MANUAL_INSTALL.md)
- **File Structure**: [luci-app/STRUCTURE.md](luci-app/STRUCTURE.md)
- **Fix Documentation**: Original dual-mode implementation details

---

## 🆚 Comparison with Original

| Feature | Original | Auto-Edu App |
|---------|----------|--------------|
| **Modes** | Single | **Dual (Efficient/Aggressive)** |
| **Interface** | CLI only | **CLI + Web UI** |
| **Installation** | Manual | **One-liner** |
| **Config Sync** | Manual | **Automatic (LuCI)** |
| **Monitoring** | Logs | **Dashboard + Logs** |
| **Management** | SSH | **Web Browser** |

---

## 🤝 Contributing

Contributions welcome!

1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

---

## 📞 Support

- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/Matsumiko/auto-edu-app/issues)
- 💡 **Feature Requests**: [GitHub Discussions](https://github.com/Matsumiko/auto-edu-app/discussions)
- ⭐ **Like this project?** Give it a star!

---

## 📜 License

Apache License 2.0

---

## 🙏 Credits

- **Original Script**: Community-driven development
- **Dual Mode System**: Matsumiko
- **LuCI Integration**: Matsumiko
- **OpenWrt Community**: For the amazing platform

---

<div align="center">

**Created with ❤️ for the community**

**Edited Version by Matsumiko**

*If this helps you, please give it a ⭐!*

[⬆ Back to top](#-auto-edu-app)

</div>
