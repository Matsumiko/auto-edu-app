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
.mode-wrap {
	margin-top: 16px;
}

/* Card deskripsi mode: dark glass */
.mode-desc {
	background: rgba(15,23,42,0.92);
	backdrop-filter: blur(8px);
	-webkit-backdrop-filter: blur(8px);
	padding: 12px 12px 10px;
	border-radius: 14px;
	border: 1px solid rgba(75,85,99,0.9);
	color: #e5e7eb;
	margin: 10px 0 14px;
	box-shadow: 0 8px 22px rgba(15,23,42,0.95);
}
.mode-desc h4 {
	margin: 0 0 6px;
	font-size: 0.9rem;
}
.mode-desc ul {
	margin: 0 0 0 16px;
	font-size: 0.8rem;
}

/* Table: dark glass */
.mode-table {
	width: 100%;
	border-collapse: collapse;
	margin-top: 6px;
	font-size: 0.8rem;
}
.mode-table th,
.mode-table td {
	border: 1px solid rgba(75,85,99,0.95);
	padding: 7px 8px;
}
.mode-table th {
	background: rgba(15,23,42,0.98);
	color: #bfdbfe;
	font-weight: 600;
}
.mode-table tr:nth-child(even) {
	background-color: rgba(9,9,11,0.98);
}
.mode-table tr:nth-child(odd) {
	background-color: rgba(3,7,18,0.98);
}

.mode-efficient {
	color: #22c55e;
	font-weight: 700;
}
.mode-aggressive {
	color: #ef4444;
	font-weight: 700;
}

/* Note */
.cbi-value-description {
	margin-top: 10px;
	font-size: 0.8rem;
	color: #e5e7eb;
	background: rgba(15,23,42,0.92);
	border-radius: 10px;
	padding: 8px 10px;
	border: 1px solid rgba(75,85,99,0.9);
}
.cbi-value-description ul {
	margin: 4px 0 0 16px;
}
</style>

<div class="mode-wrap">
	<div class="mode-desc">
		<h4>🟢 EFFICIENT Mode (Recommended)</h4>
		<ul>
			<li><strong>Best for:</strong> Normal to heavy usage (30GB/30+ minutes)</li>
			<li><strong>Cron:</strong> Every 3 minutes</li>
			<li><strong>SMS Check:</strong> 3 messages</li>
			<li><strong>Max Age:</strong> 15 minutes</li>
			<li><strong>Logic:</strong> Standard (konfirmasi → kuota)</li>
			<li><strong>CPU Usage:</strong> ~1% (very low)</li>
			<li>✅ Hemat resource &amp; stabil</li>
		</ul>
	</div>

	<div class="mode-desc" style="border-color: rgba(220,53,69,0.9);">
		<h4>🔴 AGGRESSIVE Mode (Extreme Usage)</h4>
		<ul>
			<li><strong>Best for:</strong> Extreme heavy usage (30GB/5-10 minutes)</li>
			<li><strong>Cron:</strong> Every 1 minute</li>
			<li><strong>SMS Check:</strong> 5 messages</li>
			<li><strong>Max Age:</strong> 5 minutes</li>
			<li><strong>Logic:</strong> Priority (kuota → konfirmasi) 🔥</li>
			<li><strong>CPU Usage:</strong> ~3% (medium)</li>
			<li>⚡ Fastest detection, ⚠️ lebih boros resource</li>
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
			<tr><td>Cron Interval</td><td>Every 3 minutes</td><td>Every 1 minute</td></tr>
			<tr><td>SMS Check</td><td>3 messages</td><td>5 messages</td></tr>
			<tr><td>Max SMS Age</td><td>15 minutes</td><td>5 minutes</td></tr>
			<tr><td>Detection Time</td><td>0–3 minutes</td><td>0–1 minute</td></tr>
			<tr><td>CPU Usage</td><td>~1%</td><td>~3%</td></tr>
			<tr><td>Handle Speed</td><td>30GB/30+ min</td><td>30GB/5–10 min</td></tr>
			<tr><td>Best For</td><td>95% users</td><td>5% extreme users</td></tr>
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
