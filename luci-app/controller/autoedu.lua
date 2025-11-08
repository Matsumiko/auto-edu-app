-- Copyright 2025 Matsumiko
-- Licensed under the Apache License, Version 2.0

module("luci.controller.autoedu", package.seeall)

local sys = require "luci.sys"
local http = require "luci.http"
local uci = require "luci.model.uci".cursor()
local json = require "luci.jsonc"

function index()
	if not nixio.fs.access("/etc/config/autoedu") then
		return
	end

	-- Main menu entry
	entry({"admin", "services", "autoedu"}, 
		alias("admin", "services", "autoedu", "dashboard"), 
		_("Auto-Edu"), 60).dependent = false

	-- Dashboard
	entry({"admin", "services", "autoedu", "dashboard"}, 
		template("autoedu/dashboard"), 
		_("Dashboard"), 1)

	-- Configuration
	entry({"admin", "services", "autoedu", "config"}, 
		cbi("autoedu/config"), 
		_("Configuration"), 2)

	-- Mode Selection
	entry({"admin", "services", "autoedu", "mode"}, 
		cbi("autoedu/mode"), 
		_("Mode Selection"), 3)

	-- System Status
	entry({"admin", "services", "autoedu", "status"}, 
		template("autoedu/status"), 
		_("System Status"), 4)

	-- Logs
	entry({"admin", "services", "autoedu", "logs"}, 
		template("autoedu/logs"), 
		_("Logs"), 5)

	-- API Endpoints
	entry({"admin", "services", "autoedu", "api", "status"}, 
		call("api_status")).leaf = true
	
	entry({"admin", "services", "autoedu", "api", "stats"}, 
		call("api_stats")).leaf = true
	
	entry({"admin", "services", "autoedu", "api", "logs"}, 
		call("api_logs")).leaf = true
	
	entry({"admin", "services", "autoedu", "api", "action"}, 
		call("api_action")).leaf = true
	
	entry({"admin", "services", "autoedu", "api", "test"}, 
		call("api_test")).leaf = true
end

-- API: Get service status
function api_status()
	local status = {}
	
	-- Check if enabled in UCI
	status.enabled = (uci:get("autoedu", "config", "enabled") == "1")
	
	-- Check if cron is active
	local cron_check = sys.exec("crontab -l 2>/dev/null | grep auto_edu.py")
	status.cron_active = (cron_check ~= "")
	
	-- Service is running if enabled AND cron active
	status.running = status.enabled and status.cron_active
	
	-- Get mode from UCI
	status.mode = uci:get("autoedu", "config", "mode") or "EFFICIENT"
	
	-- Get cron schedule
	if status.cron_active then
		local interval = cron_check:match("^([^%s]+%s+[^%s]+%s+[^%s]+%s+[^%s]+%s+[^%s]+)")
		if interval then
			status.cron_schedule = interval
			-- Translate cron to readable
			if interval:match("%*/1") then
				status.cron_readable = "Every 1 minute"
			elseif interval:match("%*/3") then
				status.cron_readable = "Every 3 minutes"
			elseif interval:match("%*/5") then
				status.cron_readable = "Every 5 minutes"
			else
				status.cron_readable = interval
			end
		else
			status.cron_schedule = "Active"
			status.cron_readable = "Active"
		end
	else
		status.cron_schedule = "Not configured"
		status.cron_readable = "Not configured"
	end
	
	-- Get last check time from log
	local log_file = uci:get("autoedu", "config", "log_file") or "/tmp/auto_edu.log"
	if nixio.fs.access(log_file) then
		-- Get last "Script Started" or "SELESAI" line
		local last_check_line = sys.exec("grep -E 'Script Started|SELESAI' " .. log_file .. " | tail -1")
		
		if last_check_line and last_check_line ~= "" then
			-- Try to extract timestamp [DD/MM/YYYY HH:MM:SS]
			local timestamp = last_check_line:match("%[([^%]]+)%]")
			if timestamp then
				status.last_check = timestamp
				
				-- Calculate time ago
				local pattern = "(%d+)/(%d+)/(%d+) (%d+):(%d+):(%d+)"
				local d, m, y, h, min, s = timestamp:match(pattern)
				if d and m and y then
					local log_time = os.time({year=y, month=m, day=d, hour=h, min=min, sec=s})
					local diff = os.time() - log_time
					local mins_ago = math.floor(diff / 60)
					
					if mins_ago < 1 then
						status.last_check_ago = "just now"
					elseif mins_ago < 60 then
						status.last_check_ago = mins_ago .. " min ago"
					else
						local hours = math.floor(mins_ago / 60)
						status.last_check_ago = hours .. " hour(s) ago"
					end
				end
			else
				status.last_check = "Unknown"
				status.last_check_ago = "unknown"
			end
		else
			status.last_check = "Not running yet"
			status.last_check_ago = ""
		end
	else
		status.last_check = "No logs yet"
		status.last_check_ago = ""
	end
	
	-- Get last renewal time
	local renewal_file = "/tmp/auto_edu_last_renewal"
	if nixio.fs.access(renewal_file) then
		local f = io.open(renewal_file, "r")
		if f then
			local timestamp_str = f:read("*all")
			f:close()
			
			-- Remove whitespace/newlines
			timestamp_str = timestamp_str:match("^%s*(.-)%s*$")
			
			local timestamp = tonumber(timestamp_str)
			if timestamp and timestamp > 0 then
				status.last_renewal = os.date("%d/%m/%Y %H:%M:%S", timestamp)
				
				-- Calculate time ago
				local diff = os.time() - timestamp
				local mins_ago = math.floor(diff / 60)
				
				if mins_ago < 60 then
					status.last_renewal_ago = mins_ago .. " min ago"
				elseif mins_ago < 1440 then
					local hours = math.floor(mins_ago / 60)
					status.last_renewal_ago = hours .. " hour(s) ago"
				else
					local days = math.floor(mins_ago / 1440)
					status.last_renewal_ago = days .. " day(s) ago"
				end
			else
				status.last_renewal = "Never"
				status.last_renewal_ago = ""
			end
		else
			status.last_renewal = "Never"
			status.last_renewal_ago = ""
		end
	else
		status.last_renewal = "Never"
		status.last_renewal_ago = ""
	end
	
	-- Get next check time (based on cron and last check)
	if status.cron_active and status.last_check ~= "No logs yet" and status.last_check ~= "Unknown" then
		-- Parse last check time
		local pattern = "(%d+)/(%d+)/(%d+) (%d+):(%d+):(%d+)"
		local d, m, y, h, min, s = status.last_check:match(pattern)
		
		if d and m and y then
			local last_time = os.time({year=y, month=m, day=d, hour=h, min=min, sec=s})
			
			-- Determine interval in seconds
			local interval_secs = 180 -- default 3 minutes
			if status.mode == "AGGRESSIVE" then
				interval_secs = 60 -- 1 minute
			end
			
			local next_time = last_time + interval_secs
			local diff = next_time - os.time()
			
			if diff > 0 then
				local mins = math.floor(diff / 60)
				local secs = diff % 60
				if mins > 0 then
					status.next_check = "in " .. mins .. " min " .. secs .. " sec"
				else
					status.next_check = "in " .. secs .. " sec"
				end
			else
				status.next_check = "now"
			end
		else
			status.next_check = "unknown"
		end
	else
		status.next_check = "unknown"
	end
	
	-- Get ADB status
	status.adb_connected = (sys.call("adb devices 2>/dev/null | grep -q 'device$'") == 0)
	if status.adb_connected then
		-- Get device name
		local device_line = sys.exec("adb devices 2>/dev/null | grep -v 'List' | grep device")
		local device_id = device_line:match("^([^%s]+)")
		status.adb_device = device_id or "Connected"
	end
	
	-- Get Telegram config status
	local bot_token = uci:get("autoedu", "config", "bot_token") or ""
	local chat_id = uci:get("autoedu", "config", "chat_id") or ""
	status.telegram_configured = (bot_token ~= "" and chat_id ~= "")
	
	http.prepare_content("application/json")
	http.write_json(status)
end

-- API: Get statistics
function api_stats()
	local stats = {}
	
	-- Read from UCI stats
	stats.total_checks = tonumber(uci:get("autoedu", "stats", "total_checks") or 0)
	stats.total_renewals = tonumber(uci:get("autoedu", "stats", "total_renewals") or 0)
	stats.success_rate = tonumber(uci:get("autoedu", "stats", "success_rate") or 100)
	
	-- Calculate from logs if available
	local log_file = uci:get("autoedu", "config", "log_file") or "/tmp/auto_edu.log"
	if nixio.fs.access(log_file) then
		-- Count checks in last 24h
		local checks_24h = sys.exec("grep -c 'Script Started' " .. log_file .. " 2>/dev/null || echo 0")
		stats.checks_24h = tonumber(checks_24h) or 0
		
		-- Count renewals in last 24h
		local renewals_24h = sys.exec("grep -c 'PROSES RENEWAL SELESAI' " .. log_file .. " 2>/dev/null || echo 0")
		stats.renewals_24h = tonumber(renewals_24h) or 0
	else
		stats.checks_24h = 0
		stats.renewals_24h = 0
	end
	
	http.prepare_content("application/json")
	http.write_json(stats)
end

-- API: Get logs
function api_logs()
	local lines = tonumber(http.formvalue("lines")) or 100
	local level = http.formvalue("level") or "all"
	
	local log_file = uci:get("autoedu", "config", "log_file") or "/tmp/auto_edu.log"
	
	if not nixio.fs.access(log_file) then
		http.prepare_content("application/json")
		http.write_json({
			success = false,
			message = "Log file not found",
			logs = {}
		})
		return
	end
	
	-- Read last N lines
	local cmd = "tail -n " .. lines .. " " .. log_file
	
	-- Filter by level if not "all"
	if level ~= "all" then
		cmd = cmd .. " | grep -i '\\[" .. level:upper() .. "\\]'"
	end
	
	local log_content = sys.exec(cmd)
	local logs = {}
	
	for line in log_content:gmatch("[^\r\n]+") do
		table.insert(logs, line)
	end
	
	http.prepare_content("application/json")
	http.write_json({
		success = true,
		count = #logs,
		logs = logs
	})
end

-- API: Perform actions
function api_action()
	local action = http.formvalue("action")
	local result = {success = false, message = "Unknown action"}
	
	if action == "start" then
		sys.call("/etc/init.d/autoedu start")
		result.success = true
		result.message = "Service started"
		
	elseif action == "stop" then
		sys.call("/etc/init.d/autoedu stop")
		result.success = true
		result.message = "Service stopped"
		
	elseif action == "restart" then
		sys.call("/etc/init.d/autoedu restart")
		result.success = true
		result.message = "Service restarted"
		
	elseif action == "run_now" then
		-- Run script immediately
		local script = "/usr/share/autoedu/auto_edu.py"
		local env_file = "/root/Auto-Edu/auto_edu.env"
		sys.call("AUTO_EDU_ENV=" .. env_file .. " /usr/bin/python3 " .. script .. " &")
		result.success = true
		result.message = "Script executed"
		
	elseif action == "clear_logs" then
		local log_file = uci:get("autoedu", "config", "log_file") or "/tmp/auto_edu.log"
		sys.call("echo '' > " .. log_file)
		result.success = true
		result.message = "Logs cleared"
		
	elseif action == "clear_credentials" then
		-- Clear sensitive data
		uci:set("autoedu", "config", "bot_token", "")
		uci:set("autoedu", "config", "chat_id", "")
		uci:commit("autoedu")
		
		-- Sync to .env
		sys.call("/usr/share/autoedu/sync_config.sh")
		
		result.success = true
		result.message = "Credentials cleared"
	end
	
	http.prepare_content("application/json")
	http.write_json(result)
end

-- API: Test connections
function api_test()
	local test_type = http.formvalue("type")
	local result = {success = false, message = ""}
	
	if test_type == "adb" then
		-- Test ADB connection
		local adb_output = sys.exec("adb devices 2>&1")
		if adb_output:match("device$") then
			result.success = true
			result.message = "ADB connected"
			result.device = adb_output:match("(%S+)%s+device")
		else
			result.success = false
			result.message = "No ADB device found"
		end
		
	elseif test_type == "telegram" then
		-- Test Telegram connection
		local bot_token = uci:get("autoedu", "config", "bot_token")
		local chat_id = uci:get("autoedu", "config", "chat_id")
		
		if not bot_token or bot_token == "" then
			result.success = false
			result.message = "Bot token not configured"
		elseif not chat_id or chat_id == "" then
			result.success = false
			result.message = "Chat ID not configured"
		else
			-- Try to send test message
			local url = "https://api.telegram.org/bot" .. bot_token .. "/sendMessage"
			local cmd = string.format(
				"curl -s -X POST '%s' -d 'chat_id=%s' -d 'text=🧪 Test from Auto-Edu LuCI' 2>&1",
				url, chat_id
			)
			
			local output = sys.exec(cmd)
			
			if output:match('"ok":true') then
				result.success = true
				result.message = "Telegram connected - Test message sent"
			else
				result.success = false
				result.message = "Failed to connect to Telegram"
				result.error = output
			end
		end
		
	elseif test_type == "sms" then
		-- Test SMS reading
		local cmd = "adb shell content query --uri content://sms/inbox --projection date,address,body 2>&1 | head -5"
		local output = sys.exec(cmd)
		
		if output:match("Row:") then
			result.success = true
			result.message = "SMS access OK"
			result.sample = output
		else
			result.success = false
			result.message = "Cannot read SMS"
			result.error = output
		end
	end
	
	http.prepare_content("application/json")
	http.write_json(result)
end
