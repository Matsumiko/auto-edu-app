-- Copyright 2025 Matsumiko
-- Licensed under the Apache License, Version 2.0

local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()

m = Map("autoedu", translate("Monitoring Mode Selection"),
	translate("Select the monitoring mode based on your usage pattern."))

s = m:section(TypedSection, "autoedu", translate("Current Mode"))
s.anonymous = true
s.addremove = false

-- Display current mode
current = s:option(DummyValue, "mode", translate("Active Mode"))
function current.cfgvalue(self, section)
	local mode = self.map:get(section, self.option) or "EFFICIENT"
	if mode == "AGGRESSIVE" then
		return "🔴 AGGRESSIVE (Extreme Usage)"
	else
		return "🟢 EFFICIENT (Recommended)"
	end
end

-- Mode Selection
mode = s:option(ListValue, "mode", translate("Select Mode"),
	translate("Choose monitoring mode based on your usage pattern"))
mode:value("EFFICIENT", "🟢 EFFICIENT - Recommended (Every 3 minutes)")
mode:value("AGGRESSIVE", "🔴 AGGRESSIVE - Extreme Usage (Every 1 minute)")
mode.default = "EFFICIENT"
mode.rmempty = false

-- Mode Comparison Table
comparison = s:option(DummyValue, "_comparison", " ")
comparison.rawhtml = true
comparison.default = [[
<style>
.mode-table {
	width: 100%;
	border-collapse: collapse;
	margin-top: 20px;
	margin-bottom: 20px;
}
.mode-table th, .mode-table td {
	border: 1px solid #ddd;
	padding: 12px;
	text-align: left;
}
.mode-table th {
	background-color: #f2f2f2;
	font-weight: bold;
}
.mode-table tr:nth-child(even) {
	background-color: #f9f9f9;
}
.mode-efficient {
	color: #28a745;
	font-weight: bold;
}
.mode-aggressive {
	color: #dc3545;
	font-weight: bold;
}
.mode-desc {
	background: #f8f9fa;
	padding: 15px;
	border-left: 4px solid #007bff;
	margin: 15px 0;
}
.mode-desc h4 {
	margin-top: 0;
}
.mode-desc ul {
	margin-bottom: 0;
}
</style>

<div class="mode-desc">
	<h4>🟢 EFFICIENT Mode (Recommended)</h4>
	<ul>
		<li><strong>Best for:</strong> Normal to heavy usage (30GB/30+ minutes)</li>
		<li><strong>Cron:</strong> Every 3 minutes</li>
		<li><strong>SMS Check:</strong> 3 messages</li>
		<li><strong>Max Age:</strong> 15 minutes</li>
		<li><strong>Logic:</strong> Standard (konfirmasi → kuota)</li>
		<li><strong>CPU Usage:</strong> ~1% (very low)</li>
		<li>✅ Hemat resource</li>
		<li>✅ Cocok untuk 95% pengguna</li>
		<li>✅ Reliable &amp; tested</li>
	</ul>
</div>

<div class="mode-desc" style="border-left-color: #dc3545;">
	<h4>🔴 AGGRESSIVE Mode (Extreme Usage)</h4>
	<ul>
		<li><strong>Best for:</strong> Extreme heavy usage (30GB/5-10 minutes)</li>
		<li><strong>Cron:</strong> Every 1 minute</li>
		<li><strong>SMS Check:</strong> 5 messages</li>
		<li><strong>Max Age:</strong> 5 minutes</li>
		<li><strong>Logic:</strong> Priority (kuota → konfirmasi) 🔥</li>
		<li><strong>CPU Usage:</strong> ~3% (medium)</li>
		<li>⚡ Fastest detection</li>
		<li>⚡ Priority kuota check</li>
		<li>⚠️ Higher CPU usage</li>
	</ul>
</div>

<table class="mode-table">
	<thead>
		<tr>
			<th>Feature</th>
			<th class="mode-efficient">EFFICIENT</th>
			<th class="mode-aggressive">AGGRESSIVE</th>
		</tr>
	</thead>
	<tbody>
		<tr>
			<td>Cron Interval</td>
			<td>Every 3 minutes</td>
			<td>Every 1 minute</td>
		</tr>
		<tr>
			<td>SMS Check</td>
			<td>3 messages</td>
			<td>5 messages</td>
		</tr>
		<tr>
			<td>Max SMS Age</td>
			<td>15 minutes</td>
			<td>5 minutes</td>
		</tr>
		<tr>
			<td>Detection Time</td>
			<td>0-3 minutes</td>
			<td>0-1 minute</td>
		</tr>
		<tr>
			<td>CPU Usage</td>
			<td>~1%</td>
			<td>~3%</td>
		</tr>
		<tr>
			<td>Handle Speed</td>
			<td>30GB/30+ min</td>
			<td>30GB/5-10 min</td>
		</tr>
		<tr>
			<td>Best For</td>
			<td>95% users</td>
			<td>5% extreme users</td>
		</tr>
	</tbody>
</table>

<div class="cbi-value-description">
	<strong>⚠️ Changing mode will:</strong>
	<ul>
		<li>Update cron schedule automatically</li>
		<li>Restart monitoring service</li>
		<li>Apply new parameters immediately</li>
	</ul>
</div>
]]

-- After save, update cron and restart
function m.on_after_commit(self)
	-- Sync config
	sys.call("/usr/share/autoedu/sync_config.sh")
	
	-- Restart service to apply new mode
	local enabled = uci:get("autoedu", "config", "enabled")
	if enabled == "1" then
		sys.call("/etc/init.d/autoedu restart")
		luci.http.redirect(luci.dispatcher.build_url("admin", "services", "autoedu", "dashboard"))
	end
end

return m
