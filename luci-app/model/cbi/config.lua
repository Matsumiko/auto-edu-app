-- Copyright 2025 Matsumiko
-- Licensed under the Apache License, Version 2.0

local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()

m = Map("autoedu", translate("Auto-Edu Configuration"),
	translate("Configure Auto-Edu quota monitoring and renewal system."))

-- Service Settings Section
s = m:section(TypedSection, "autoedu", translate("Service Settings"))
s.anonymous = true
s.addremove = false

enabled = s:option(Flag, "enabled", translate("Enable Service"),
	translate("Enable Auto-Edu monitoring service"))
enabled.rmempty = false
enabled.default = "0"

-- Telegram Settings Section
telegram = m:section(TypedSection, "autoedu", translate("Telegram Settings"))
telegram.anonymous = true
telegram.addremove = false

bot_token = telegram:option(Value, "bot_token", translate("Bot Token"),
	translate("Telegram Bot Token from @BotFather. Leave empty to keep current token."))
bot_token.password = true
bot_token.rmempty = true
bot_token.placeholder = "123456789:ABCdefGHIjklMNOpqrsTUVwxyz"

function bot_token.cfgvalue(self, section)
	local value = self.map:get(section, self.option)
	if value and value ~= "" then
		return "••••••••••••••••" -- Mask existing token
	end
	return ""
end

function bot_token.write(self, section, value)
	if value and value ~= "" and value ~= "••••••••••••••••" then
		-- New token provided
		self.map:set(section, self.option, value)
	end
end

chat_id = telegram:option(Value, "chat_id", translate("Chat ID"),
	translate("Your Telegram Chat ID from @userinfobot"))
chat_id.rmempty = false
chat_id.datatype = "integer"
chat_id.placeholder = "123456789"

-- Test Button
test_telegram = telegram:option(Button, "_test_telegram", translate("Test Connection"))
test_telegram.inputtitle = translate("Test Telegram")
test_telegram.inputstyle = "apply"

function test_telegram.write(self, section)
	local token = m:get(section, "bot_token")
	local chatid = m:get(section, "chat_id")
	
	if not token or token == "" then
		m.message = translate("Error: Bot token not configured")
		return
	end
	
	if not chatid or chatid == "" then
		m.message = translate("Error: Chat ID not configured")
		return
	end
	
	-- Send test message
	local url = "https://api.telegram.org/bot" .. token .. "/sendMessage"
	local cmd = string.format(
		"curl -s -X POST '%s' -d 'chat_id=%s' -d 'text=🧪 Test from Auto-Edu' 2>&1",
		url, chatid
	)
	
	local result = sys.exec(cmd)
	
	if result:match('"ok":true') then
		m.message = translate("Success: Test message sent to Telegram")
	else
		m.message = translate("Error: Failed to send test message")
	end
end

-- USSD Settings Section
ussd = m:section(TypedSection, "autoedu", translate("USSD Codes"))
ussd.anonymous = true
ussd.addremove = false

kode_unreg = ussd:option(Value, "kode_unreg", translate("Unregister Code"),
	translate("USSD code to unregister old package"))
kode_unreg.default = "*808*5*2*1*1#"
kode_unreg.rmempty = false

kode_beli = ussd:option(Value, "kode_beli", translate("Purchase Code"),
	translate("USSD code to purchase new package"))
kode_beli.default = "*808*4*1*1*1*1#"
kode_beli.rmempty = false

-- Provider Preset
provider_preset = ussd:option(ListValue, "_preset", translate("Provider Preset"),
	translate("Quick preset for common providers"))
provider_preset:value("", translate("-- Select Provider --"))
provider_preset:value("xl", "XL Axiata")
provider_preset:value("telkomsel", "Telkomsel")
provider_preset:value("indosat", "Indosat Ooredoo")
provider_preset.default = ""

function provider_preset.write(self, section, value)
	if value == "xl" then
		m:set(section, "kode_unreg", "*808*5*2*1*1#")
		m:set(section, "kode_beli", "*808*4*1*1*1*1#")
	elseif value == "telkomsel" then
		m:set(section, "kode_unreg", "*363*844#")
		m:set(section, "kode_beli", "*363*844*1#")
	elseif value == "indosat" then
		m:set(section, "kode_unreg", "*123*075#")
		m:set(section, "kode_beli", "*123*075*1#")
	end
end

-- Quota Settings Section
quota = m:section(TypedSection, "autoedu", translate("Quota Settings"))
quota.anonymous = true
quota.addremove = false

threshold = quota:option(Value, "threshold", translate("Renewal Threshold (GB)"),
	translate("Trigger renewal when quota is below this value"))
threshold.datatype = "range(1,30)"
threshold.default = "3"
threshold.rmempty = false

-- Notification Settings Section
notif = m:section(TypedSection, "autoedu", translate("Notification Settings"))
notif.anonymous = true
notif.addremove = false

notif_startup = notif:option(Flag, "notif_startup", translate("Startup Notification"),
	translate("Send notification when script starts (⚠️ Not recommended for interval < 5 minutes)"))
notif_startup.default = "0"
notif_startup.rmempty = false

notif_safe = notif:option(Flag, "notif_safe", translate("Safe Quota Notification"),
	translate("Send notification when quota is still safe (⚠️ Not recommended for interval < 5 minutes)"))
notif_safe.default = "0"
notif_safe.rmempty = false

notif_detail = notif:option(Flag, "notif_detail", translate("Detailed Notifications"),
	translate("Send detailed notifications (✅ Recommended - important alerts only)"))
notif_detail.default = "1"
notif_detail.rmempty = false

o = notif:option(DummyValue, "_info", " ")
o.rawhtml = true
o.default = [[
<style>
.autoedu-notif-info {
	margin-top: 6px;
	padding: 8px 10px;
	border-radius: 10px;
	background: rgba(15,23,42,0.92);
	color: #e5e7eb;
	border: 1px solid rgba(75,85,99,0.9);
	font-size: 0.8rem;
}
.autoedu-notif-info ul {
	margin: 4px 0 0 16px;
}
</style>
<div class="autoedu-notif-info">
	<strong>Notifications that are ALWAYS sent:</strong>
	<ul>
		<li>⚠️ Low quota alert</li>
		<li>🔄 Renewal process</li>
		<li>✅ Renewal result</li>
		<li>❌ Errors &amp; warnings</li>
	</ul>
</div>
]]

-- Advanced Settings Section
advanced = m:section(TypedSection, "autoedu", translate("Advanced Settings"))
advanced.anonymous = true
advanced.addremove = false

jeda_ussd = advanced:option(Value, "jeda_ussd", translate("USSD Delay (seconds)"),
	translate("Delay between USSD commands"))
jeda_ussd.datatype = "range(5,30)"
jeda_ussd.default = "10"
jeda_ussd.rmempty = false

timeout_adb = advanced:option(Value, "timeout_adb", translate("ADB Timeout (seconds)"),
	translate("Timeout for ADB operations"))
timeout_adb.datatype = "range(10,60)"
timeout_adb.default = "15"
timeout_adb.rmempty = false

log_file = advanced:option(Value, "log_file", translate("Log File Path"),
	translate("Path to log file"))
log_file.default = "/tmp/auto_edu.log"
log_file.rmempty = false

max_log_size = advanced:option(Value, "max_log_size", translate("Max Log Size (bytes)"),
	translate("Maximum log file size before rotation"))
max_log_size.datatype = "uinteger"
max_log_size.default = "102400"
max_log_size.rmempty = false

-- Danger Zone Section
danger = m:section(TypedSection, "autoedu", translate("Danger Zone"))
danger.anonymous = true
danger.addremove = false

clear_creds = danger:option(Button, "_clear", translate("Clear Credentials"))
clear_creds.inputtitle = translate("Clear All Credentials")
clear_creds.inputstyle = "remove"

function clear_creds.write(self, section)
	m:set(section, "bot_token", "")
	m:set(section, "chat_id", "")
	m.message = translate("Credentials cleared. Please configure again.")
end

-- After save, sync config to .env
function m.on_after_commit(self)
	-- Sync config first
	sys.call("/usr/share/autoedu/sync_config.sh")
	
	-- Check enabled status
	local enabled = uci:get("autoedu", "config", "enabled")
	
	if enabled == "1" then
		-- Service should be running
		sys.call("/etc/init.d/autoedu stop 2>/dev/null")
		sys.call("/etc/init.d/autoedu start")
	else
		-- Service should be stopped
		sys.call("/etc/init.d/autoedu stop")
	end
end

return m
