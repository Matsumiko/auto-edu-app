#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Auto Edu - Automatic Quota Management System (DUAL MODE)
Sistem otomatis untuk monitoring dan perpanjangan kuota Edu
Optimized for OpenWrt environment

Edited Version by: Matsumiko

DUAL MODE VERSION - Support untuk:
- EFFICIENT Mode: Normal to heavy usage (30GB/30+ min) - Low CPU
- AGGRESSIVE Mode: Extreme heavy usage (30GB/5-10 min) - Medium CPU

Features:
- Time-based SMS filtering (hanya cek SMS < X menit)
- Deteksi konfirmasi aktivasi paket
- Skip renewal jika paket baru saja aktif
- Renewal timestamp tracking (proteksi pemakaian berat)
- Adaptive logic based on monitoring mode

Setup:
1. opkg update && opkg install python3 curl
2. Run setup.sh untuk konfigurasi otomatis
   ATAU edit .env file manual
3. chmod +x /root/Auto-Edu/auto_edu.py
4. Test manual: python3 /root/Auto-Edu/auto_edu.py
5. Setup crontab berdasarkan mode pilihan
"""

import re
import time
import subprocess
import urllib.parse
import sys
from datetime import datetime
from pathlib import Path

# ============================================================================
# KONFIGURASI - JANGAN EDIT LANGSUNG DI SINI!
# Edit file .env atau jalankan setup.sh untuk konfigurasi
# ============================================================================

import os
from pathlib import Path

# Path untuk .env file
ENV_FILE = os.getenv('AUTO_EDU_ENV')
if not ENV_FILE or not Path(ENV_FILE).exists():
    possible_paths = [
        '/root/Auto-Edu/auto_edu.env',
        '/root/.auto_edu.env',
        str(Path(__file__).parent / 'auto_edu.env'),
    ]
    for path in possible_paths:
        if Path(path).exists():
            ENV_FILE = path
            break
    else:
        ENV_FILE = '/root/Auto-Edu/auto_edu.env'

def load_env():
    """Load configuration from .env file"""
    config = {}
    env_path = Path(ENV_FILE)
    
    if env_path.exists():
        with open(env_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    value = value.strip().strip('"').strip("'")
                    config[key.strip()] = value
    
    return config

# Load dari .env
env_config = load_env()

# Konfigurasi dari .env atau default values
BOT_TOKEN = env_config.get('BOT_TOKEN', 'BOT_TOKEN')
CHAT_ID = env_config.get('CHAT_ID', 'CHAT_ID')

# Kode USSD
KODE_UNREG = env_config.get('KODE_UNREG', '*808*5*2*1*1#')
KODE_BELI = env_config.get('KODE_BELI', '*808*4*1*1*1*1#')

# Pengaturan timing (dalam detik)
JEDA_USSD = int(env_config.get('JEDA_USSD', '10'))
TIMEOUT_ADB = int(env_config.get('TIMEOUT_ADB', '15'))

# Pengaturan threshold kuota
THRESHOLD_KUOTA_GB = int(env_config.get('THRESHOLD_KUOTA_GB', '3'))

# NEW: Monitoring Mode Configuration
MONITORING_MODE = env_config.get('MONITORING_MODE', 'EFFICIENT').upper()

# Adaptive parameters based on mode
if MONITORING_MODE == 'AGGRESSIVE':
    # AGGRESSIVE Mode: Extreme heavy usage
    JUMLAH_SMS_CEK = int(env_config.get('JUMLAH_SMS_CEK_AGGRESSIVE', '5'))
    SMS_MAX_AGE_MINUTES = int(env_config.get('SMS_MAX_AGE_AGGRESSIVE', '5'))
    USE_IMPROVED_LOGIC = True  # Priority kuota check
else:
    # EFFICIENT Mode: Normal to heavy usage (default)
    JUMLAH_SMS_CEK = int(env_config.get('JUMLAH_SMS_CEK', '3'))
    SMS_MAX_AGE_MINUTES = int(env_config.get('SMS_MAX_AGE_MINUTES', '15'))
    USE_IMPROVED_LOGIC = False  # Standard logic

# Pengaturan notifikasi
NOTIF_KUOTA_AMAN = env_config.get('NOTIF_KUOTA_AMAN', 'false').lower() == 'true'
NOTIF_STARTUP = env_config.get('NOTIF_STARTUP', 'true').lower() == 'true'
NOTIF_DETAIL = env_config.get('NOTIF_DETAIL', 'true').lower() == 'true'

# File log
LOG_FILE = env_config.get('LOG_FILE', '/tmp/auto_edu.log')
if LOG_FILE and LOG_FILE.lower() == 'none':
    LOG_FILE = None
MAX_LOG_SIZE = int(env_config.get('MAX_LOG_SIZE', '102400'))

# ============================================================================
# KELAS HELPER
# ============================================================================

class Logger:
    """Simple logger untuk debugging dan monitoring"""
    
    def __init__(self, log_file=None):
        self.log_file = log_file
        self._check_log_size()
    
    def _check_log_size(self):
        """Rotasi log jika terlalu besar"""
        if self.log_file and Path(self.log_file).exists():
            if Path(self.log_file).stat().st_size > MAX_LOG_SIZE:
                Path(self.log_file).unlink()
    
    def log(self, level, message):
        """Write log dengan timestamp"""
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        log_msg = f"[{timestamp}] [{level}] {message}"
        
        print(log_msg)
        
        if self.log_file:
            try:
                with open(self.log_file, 'a', encoding='utf-8') as f:
                    f.write(log_msg + '\n')
            except Exception as e:
                print(f"Warning: Gagal write log: {e}")
    
    def info(self, message):
        self.log('INFO', message)
    
    def warning(self, message):
        self.log('WARN', message)
    
    def error(self, message):
        self.log('ERROR', message)
    
    def success(self, message):
        self.log('SUCCESS', message)


class TelegramBot:
    """Handler untuk Telegram Bot API"""
    
    def __init__(self, token, chat_id, logger):
        self.token = token
        self.chat_id = chat_id
        self.logger = logger
        self.base_url = f"https://api.telegram.org/bot{token}"
    
    def kirim_pesan(self, pesan, parse_mode='HTML', silent=False):
        """Kirim pesan ke Telegram dengan retry mechanism"""
        if not self.chat_id or self.chat_id == 'CHAT_ID':
            self.logger.error("CHAT_ID belum dikonfigurasi!")
            return False
        
        url = f"{self.base_url}/sendMessage"
        params = {
            'chat_id': self.chat_id,
            'text': pesan,
            'parse_mode': parse_mode,
            'disable_notification': silent
        }
        
        data = urllib.parse.urlencode(params)
        
        for attempt in range(3):
            try:
                result = subprocess.run(
                    f'curl -s -X POST "{url}" -d "{data}"',
                    shell=True,
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if result.returncode == 0:
                    self.logger.info("Pesan Telegram terkirim")
                    return True
                else:
                    self.logger.warning(f"Attempt {attempt + 1}: Gagal kirim ({result.returncode})")
                    
            except subprocess.TimeoutExpired:
                self.logger.warning(f"Attempt {attempt + 1}: Timeout")
            except Exception as e:
                self.logger.error(f"Attempt {attempt + 1}: {str(e)}")
            
            if attempt < 2:
                time.sleep(2)
        
        return False
    
    def kirim_pesan_format(self, emoji, judul, konten, tingkat='info'):
        """Kirim pesan dengan format HTML yang rapi"""
        template = f"""
{emoji} <b>{judul}</b>

{konten}

<i>⏱ {datetime.now().strftime('%d/%m/%Y %H:%M:%S')}</i>
"""
        return self.kirim_pesan(template.strip())


class ADBManager:
    """Manager untuk komunikasi dengan Android via ADB"""
    
    def __init__(self, logger):
        self.logger = logger
    
    def cek_koneksi(self):
        """Cek apakah ADB terhubung dengan device"""
        try:
            result = subprocess.run(
                "adb devices",
                shell=True,
                capture_output=True,
                text=True,
                timeout=5
            )
            
            lines = result.stdout.strip().split('\n')
            if len(lines) > 1 and 'device' in lines[1]:
                self.logger.success("ADB terhubung dengan device")
                return True
            else:
                self.logger.error("Tidak ada device ADB yang terhubung")
                return False
                
        except Exception as e:
            self.logger.error(f"Gagal cek koneksi ADB: {str(e)}")
            return False
    
    def kirim_ussd(self, kode_ussd):
        """Kirim kode USSD ke device"""
        try:
            self.logger.info(f"Mengirim USSD: {kode_ussd}")
            
            kode_encoded = kode_ussd.replace('#', '%23')
            
            result = subprocess.run(
                f"adb shell am start -a android.intent.action.CALL -d tel:{kode_encoded}",
                shell=True,
                capture_output=True,
                timeout=TIMEOUT_ADB
            )
            
            if result.returncode != 0:
                raise Exception(f"ADB error: {result.stderr.decode()}")
            
            time.sleep(JEDA_USSD)
            
            subprocess.run(
                "adb shell input keyevent KEYCODE_BACK",
                shell=True,
                capture_output=True,
                timeout=5
            )
            time.sleep(1)
            
            self.logger.success(f"USSD '{kode_ussd}' berhasil dikirim")
            return True, f"✅ USSD '{kode_ussd}' terkirim"
            
        except subprocess.TimeoutExpired:
            msg = f"❌ Timeout saat kirim USSD '{kode_ussd}'"
            self.logger.error(msg)
            return False, msg
        except Exception as e:
            msg = f"❌ Gagal kirim USSD: {str(e)}"
            self.logger.error(msg)
            return False, msg
    
    def baca_sms(self, limit=5, keyword=None):
        """Baca SMS dari inbox dengan filter opsional"""
        try:
            self.logger.info(f"Membaca {limit} SMS terbaru...")
            
            cmd = 'content query --uri content://sms/inbox --projection address:date:body --sort "date DESC"'
            result = subprocess.run(
                f"adb shell {cmd}",
                shell=True,
                capture_output=True,
                text=True,
                timeout=TIMEOUT_ADB
            )
            
            if result.returncode != 0:
                raise Exception("Gagal query SMS database")
            
            pesan_list = []
            found_keyword = False
            
            for baris in result.stdout.splitlines():
                if not baris.strip().startswith('Row:'):
                    continue
                
                alamat = re.search(r'address=([^,]+),', baris)
                tanggal = re.search(r'date=(\d+),', baris)
                isi = re.search(r'body=(.+)$', baris)
                
                if not (alamat and tanggal and isi):
                    continue
                
                pengirim = alamat.group(1).strip()
                timestamp = int(tanggal.group(1)) / 1000
                tanggal_str = datetime.fromtimestamp(timestamp).strftime('%d/%m/%Y %H:%M')
                isi_pesan = isi.group(1).strip()
                
                if keyword and keyword.lower() in isi_pesan.lower():
                    found_keyword = True
                
                pesan_list.append({
                    'pengirim': pengirim,
                    'tanggal': tanggal_str,
                    'isi': isi_pesan,
                    'timestamp': timestamp
                })
                
                if len(pesan_list) >= limit:
                    break
            
            self.logger.success(f"Berhasil baca {len(pesan_list)} SMS")
            return pesan_list, found_keyword
            
        except subprocess.TimeoutExpired:
            self.logger.error("Timeout saat baca SMS")
            return [], False
        except Exception as e:
            self.logger.error(f"Gagal baca SMS: {str(e)}")
            return [], False


# ============================================================================
# FUNGSI UTAMA
# ============================================================================

def format_sms_untuk_telegram(sms_list, max_tampil=3):
    """Format list SMS menjadi text untuk Telegram"""
    if not sms_list:
        return "❌ Tidak ada SMS ditemukan"
    
    result = []
    for i, sms in enumerate(sms_list[:max_tampil], 1):
        result.append(
            f"<b>SMS #{i}</b>\n"
            f"📤 <code>{sms['pengirim']}</code>\n"
            f"🕐 {sms['tanggal']}\n"
            f"💬 {sms['isi'][:200]}{'...' if len(sms['isi']) > 200 else ''}"
        )
    
    return "\n\n".join(result)


def proses_renewal(adb, telegram, logger):
    """Proses unreg dan beli paket baru"""
    logger.info("=" * 50)
    logger.info("MEMULAI PROSES RENEWAL")
    logger.info("=" * 50)
    
    hasil = []
    
    telegram.kirim_pesan_format(
        "🔄", "Memulai Proses Renewal",
        "Sedang melakukan unregister paket lama..."
    )
    
    success_unreg, msg_unreg = adb.kirim_ussd(KODE_UNREG)
    hasil.append(msg_unreg)
    
    if not success_unreg:
        telegram.kirim_pesan_format(
            "⚠️", "Peringatan",
            f"Unreg gagal, tapi akan lanjut beli paket baru.\n\n{msg_unreg}"
        )
    
    time.sleep(2)
    
    success_beli, msg_beli = adb.kirim_ussd(KODE_BELI)
    hasil.append(msg_beli)
    
    if success_beli:
        try:
            renewal_timestamp_file = '/tmp/auto_edu_last_renewal'
            with open(renewal_timestamp_file, 'w') as f:
                f.write(str(int(time.time())))
            logger.success(f"Renewal timestamp disimpan: {datetime.now()}")
        except Exception as e:
            logger.warning(f"Gagal simpan timestamp: {e}")
    
    time.sleep(3)
    sms_list, _ = adb.baca_sms(limit=2)
    
    status = "✅ Berhasil" if (success_unreg or success_beli) else "❌ Gagal"
    
    konten = "\n".join(hasil)
    if sms_list:
        konten += f"\n\n<b>📱 SMS Terbaru:</b>\n\n{format_sms_untuk_telegram(sms_list, 2)}"
    
    telegram.kirim_pesan_format(
        "🎉" if success_beli else "❌",
        f"Renewal {status}",
        konten
    )
    
    logger.info("=" * 50)
    logger.success("PROSES RENEWAL SELESAI")
    logger.info("=" * 50)
    
    return success_beli


def cek_kuota_dan_proses(adb, telegram, logger):
    """Fungsi utama untuk cek kuota dan proses renewal jika perlu"""
    
    keyword = f"kurang dari {THRESHOLD_KUOTA_GB}GB"
    sms_list, kuota_rendah = adb.baca_sms(limit=JUMLAH_SMS_CEK, keyword=keyword)
    
    if not sms_list:
        logger.warning("Tidak ada SMS ditemukan")
        telegram.kirim_pesan_format(
            "⚠️", "Peringatan",
            "Tidak dapat membaca SMS. Pastikan device terhubung dengan baik."
        )
        return False
    
    logger.info(f"SMS terbaru dari: {sms_list[0]['pengirim']}")
    logger.info(f"Isi: {sms_list[0]['isi'][:100]}...")
    
    # Load timestamp renewal terakhir
    last_renewal_time = 0
    renewal_timestamp_file = '/tmp/auto_edu_last_renewal'
    
    if Path(renewal_timestamp_file).exists():
        try:
            with open(renewal_timestamp_file, 'r') as f:
                last_renewal_time = int(f.read().strip())
            last_renewal_str = datetime.fromtimestamp(last_renewal_time).strftime('%d/%m/%Y %H:%M:%S')
            logger.info(f"Last renewal: {last_renewal_str}")
        except Exception as e:
            logger.warning(f"Cannot read last renewal timestamp: {e}")
    else:
        logger.info("No previous renewal timestamp found (first run?)")
    
    # ========================================================================
    # DUAL MODE LOGIC
    # ========================================================================
    
    if USE_IMPROVED_LOGIC:
        # AGGRESSIVE Mode: Priority kuota check first
        logger.info(f"Mode: AGGRESSIVE - Priority kuota check")
        return cek_kuota_aggressive_mode(sms_list, keyword, last_renewal_time, adb, telegram, logger)
    else:
        # EFFICIENT Mode: Standard check
        logger.info(f"Mode: EFFICIENT - Standard check")
        return cek_kuota_efficient_mode(sms_list, keyword, last_renewal_time, adb, telegram, logger)


def cek_kuota_efficient_mode(sms_list, keyword, last_renewal_time, adb, telegram, logger):
    """EFFICIENT Mode: Check konfirmasi aktivasi dulu, lalu kuota"""
    
    # FIX #1: Cek apakah SMS terbaru adalah konfirmasi aktivasi
    sms_terbaru = sms_list[0]['isi'].lower()
    konfirmasi_keywords = [
        'sdh aktif', 
        'sudah aktif', 
        'berhasil diaktifkan', 
        'telah diaktifkan',
        'anda sdh aktif',
        'paket aktif'
    ]
    
    if any(kw in sms_terbaru for kw in konfirmasi_keywords):
        logger.success("✅ SMS terbaru adalah konfirmasi aktivasi paket - Skip renewal")
        
        if NOTIF_KUOTA_AMAN:
            telegram.kirim_pesan_format(
                "✅", "Paket Baru Aktif",
                f"Paket baru sudah aktif!\n\n"
                f"<b>SMS Terakhir:</b>\n{format_sms_untuk_telegram([sms_list[0]], 1)}",
                tingkat='info'
            )
        
        return True
    
    # FIX #2 & #3: Filter SMS dengan multi-criteria
    current_time = time.time()
    max_age_seconds = SMS_MAX_AGE_MINUTES * 60
    
    fresh_kuota_rendah = False
    for sms in sms_list:
        sms_age = current_time - sms['timestamp']
        sms_age_minutes = int(sms_age / 60)
        
        if sms_age > max_age_seconds:
            logger.info(f"Skip SMS: terlalu lama (usia: {sms_age_minutes} menit, max: {SMS_MAX_AGE_MINUTES} menit)")
            continue
        
        if last_renewal_time > 0 and sms['timestamp'] < last_renewal_time:
            sms_time_str = datetime.fromtimestamp(sms['timestamp']).strftime('%d/%m/%Y %H:%M:%S')
            logger.info(f"Skip SMS: dari sebelum renewal terakhir (SMS: {sms_time_str})")
            continue
        
        if keyword.lower() in sms['isi'].lower():
            fresh_kuota_rendah = True
            is_after_renewal = sms['timestamp'] > last_renewal_time if last_renewal_time > 0 else True
            logger.warning(
                f"⚠️ KUOTA RENDAH TERDETEKSI! "
                f"SMS usia: {sms_age_minutes} menit, "
                f"Setelah renewal: {'Ya' if is_after_renewal else 'N/A'}"
            )
            break
    
    if fresh_kuota_rendah:
        logger.warning(f"⚠️ KUOTA RENDAH VALID! (< {THRESHOLD_KUOTA_GB}GB)")
        
        telegram.kirim_pesan_format(
            "⚠️", "Kuota Hampir Habis!",
            f"Kuota Edu Anda kurang dari {THRESHOLD_KUOTA_GB}GB.\n"
            f"Memulai proses renewal otomatis...\n\n"
            f"<b>SMS Terakhir:</b>\n{sms_list[0]['isi'][:200]}"
        )
        
        return proses_renewal(adb, telegram, logger)
    
    else:
        logger.success(f"✅ Kuota masih aman (≥ {THRESHOLD_KUOTA_GB}GB atau SMS sudah di-proses)")
        
        if NOTIF_KUOTA_AMAN:
            telegram.kirim_pesan_format(
                "✅", "Status Kuota",
                f"Kuota masih aman (≥ {THRESHOLD_KUOTA_GB}GB)\n\n"
                f"<b>SMS Terakhir:</b>\n{format_sms_untuk_telegram([sms_list[0]], 1)}",
                tingkat='info'
            )
        
        return True


def cek_kuota_aggressive_mode(sms_list, keyword, last_renewal_time, adb, telegram, logger):
    """AGGRESSIVE Mode: Priority kuota check, lalu konfirmasi"""
    
    # Priority #1: Check ALL SMS for kuota rendah FIRST
    current_time = time.time()
    max_age_seconds = SMS_MAX_AGE_MINUTES * 60
    
    fresh_kuota_rendah = False
    latest_kuota_sms = None
    
    for sms in sms_list:
        sms_age = current_time - sms['timestamp']
        sms_age_minutes = int(sms_age / 60)
        
        # Kriteria 1: SMS terlalu lama
        if sms_age > max_age_seconds:
            logger.info(f"Skip SMS: terlalu lama (usia: {sms_age_minutes} menit, max: {SMS_MAX_AGE_MINUTES} menit)")
            continue
        
        # Kriteria 2: SMS sebelum renewal terakhir
        if last_renewal_time > 0 and sms['timestamp'] < last_renewal_time:
            sms_time_str = datetime.fromtimestamp(sms['timestamp']).strftime('%d/%m/%Y %H:%M:%S')
            logger.info(f"Skip SMS: dari sebelum renewal terakhir (SMS: {sms_time_str})")
            continue
        
        # Kriteria 3: SMS mengandung keyword kuota rendah
        if keyword.lower() in sms['isi'].lower():
            fresh_kuota_rendah = True
            latest_kuota_sms = sms
            is_after_renewal = sms['timestamp'] > last_renewal_time if last_renewal_time > 0 else True
            logger.warning(
                f"⚠️ KUOTA RENDAH TERDETEKSI! "
                f"SMS usia: {sms_age_minutes} menit, "
                f"Setelah renewal: {'Ya' if is_after_renewal else 'N/A'}"
            )
            break
    
    # Priority #2: Only check konfirmasi if NO kuota rendah found
    if not fresh_kuota_rendah:
        sms_terbaru = sms_list[0]['isi'].lower()
        konfirmasi_keywords = [
            'sdh aktif', 
            'sudah aktif', 
            'berhasil diaktifkan', 
            'telah diaktifkan',
            'anda sdh aktif',
            'paket aktif'
        ]
        
        if any(kw in sms_terbaru for kw in konfirmasi_keywords):
            logger.success("✅ SMS terbaru adalah konfirmasi aktivasi paket - Skip renewal")
            
            if NOTIF_KUOTA_AMAN:
                telegram.kirim_pesan_format(
                    "✅", "Paket Baru Aktif",
                    f"Paket baru sudah aktif!\n\n"
                    f"<b>SMS Terakhir:</b>\n{format_sms_untuk_telegram([sms_list[0]], 1)}",
                    tingkat='info'
                )
            
            return True
    
    # Process renewal if kuota rendah found
    if fresh_kuota_rendah:
        logger.warning(f"⚠️ KUOTA RENDAH VALID! (< {THRESHOLD_KUOTA_GB}GB)")
        
        telegram.kirim_pesan_format(
            "⚠️", "Kuota Hampir Habis!",
            f"Kuota Edu Anda kurang dari {THRESHOLD_KUOTA_GB}GB.\n"
            f"Memulai proses renewal otomatis...\n\n"
            f"<b>SMS Terakhir:</b>\n{latest_kuota_sms['isi'][:200]}"
        )
        
        return proses_renewal(adb, telegram, logger)
    
    else:
        logger.success(f"✅ Kuota masih aman (≥ {THRESHOLD_KUOTA_GB}GB atau SMS sudah di-proses)")
        
        if NOTIF_KUOTA_AMAN:
            telegram.kirim_pesan_format(
                "✅", "Status Kuota",
                f"Kuota masih aman (≥ {THRESHOLD_KUOTA_GB}GB)\n\n"
                f"<b>SMS Terakhir:</b>\n{format_sms_untuk_telegram([sms_list[0]], 1)}",
                tingkat='info'
            )
        
        return True


def validasi_konfigurasi(logger):
    """Validasi konfigurasi sebelum menjalankan script"""
    errors = []
    
    if BOT_TOKEN == 'BOT_TOKEN' or not BOT_TOKEN:
        errors.append("❌ BOT_TOKEN belum dikonfigurasi")
    
    if CHAT_ID == 'CHAT_ID' or not CHAT_ID:
        errors.append("❌ CHAT_ID belum dikonfigurasi")
    
    if not KODE_UNREG or not KODE_BELI:
        errors.append("❌ Kode USSD belum dikonfigurasi")
    
    if errors:
        for error in errors:
            logger.error(error)
        return False
    
    return True


def main():
    """Fungsi utama"""
    logger = Logger(LOG_FILE)
    telegram = TelegramBot(BOT_TOKEN, CHAT_ID, logger)
    adb = ADBManager(logger)
    
    logger.info("=" * 60)
    logger.info(f"AUTO EDU - DUAL MODE SYSTEM ({MONITORING_MODE})")
    logger.info("=" * 60)
    
    try:
        if not validasi_konfigurasi(logger):
            telegram.kirim_pesan_format(
                "❌", "Konfigurasi Error",
                "Script belum dikonfigurasi dengan benar!\n\n"
                "Silakan edit file dan isi:\n"
                "• BOT_TOKEN (dari @BotFather)\n"
                "• CHAT_ID (dari @MissRose_bot atau @userinfobot)\n"
                "• KODE_UNREG dan KODE_BELI"
            )
            return 1
        
        if NOTIF_STARTUP:
            mode_info = "🟢 EFFICIENT" if MONITORING_MODE == 'EFFICIENT' else "🔴 AGGRESSIVE"
            telegram.kirim_pesan_format(
                "🚀", "Script Started",
                f"Auto Edu monitoring dimulai\n"
                f"Mode: {mode_info}\n"
                f"Threshold: {THRESHOLD_KUOTA_GB}GB\n"
                f"SMS Check: {JUMLAH_SMS_CEK} messages\n"
                f"Max Age: {SMS_MAX_AGE_MINUTES} menit",
                tingkat='info'
            )
        
        if not adb.cek_koneksi():
            telegram.kirim_pesan_format(
                "❌", "ADB Error",
                "Tidak dapat terhubung ke device!\n\n"
                "Pastikan:\n"
                "• USB debugging aktif\n"
                "• Device terhubung ke router\n"
                "• ADB sudah terinstall"
            )
            return 1
        
        success = cek_kuota_dan_proses(adb, telegram, logger)
        
        logger.info("=" * 60)
        logger.success("SCRIPT SELESAI - Status: " + ("OK" if success else "WARNING"))
        logger.info("=" * 60)
        
        return 0 if success else 1
        
    except KeyboardInterrupt:
        logger.warning("Script dihentikan oleh user")
        return 130
        
    except Exception as e:
        logger.error(f"FATAL ERROR: {str(e)}")
        telegram.kirim_pesan_format(
            "💥", "Fatal Error",
            f"Script error:\n<code>{str(e)}</code>\n\n"
            f"Periksa log untuk detail lebih lanjut."
        )
        return 1


if __name__ == '__main__':
    sys.exit(main())
