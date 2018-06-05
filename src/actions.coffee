
{ $, echo, warn, verbose } = require './common'
Fs = require 'fs'
Tnet = require './util/tnet'
Chalk = require 'chalk'
Nginx = require './daemon/nginx'
Health = require './daemon/health'
Output = require './daemon/output'
SlimProcess = require './util/process-slim'
ChildProcess = require 'child_process'
int = (n) -> parseInt((n ? 0), 10)
{ yesNo, formatUptime, trueFalse } = require "./format"
{ configFile, exists, nginxTemplate, expandPath } = require "./files"
saveConfig = null

healthSymbol = (v) -> switch v
	when undefined then Chalk.yellow "?"
	when true then Chalk.green "\u2713"
	when false then Chalk.red "x"

{ Groups, addGroup, removeGroup, simpleAction } = require "./daemon/groups"

required = (msg, key, label) ->
	unless msg
		return warn "msg is required."
	unless msg[key] and msg[key].length
		return warn "#{label} is required."
	true

echoResponse = (resp, socket) -> console.log "Daemon says:", resp; socket.end()

Object.assign module.exports, { Actions: {

	# Adding a group
	add: addAction = {
		options: [
			[ "--group <group>", "Name of the group to create." ]
			[ "--cd <path>", "The working directory to spawn processes in." ]
			[ "--exec <script>", "Any shell command, e.g. 'node app.js'." ]
			[ "--count <n>", "The starting size of the group.", int ]
			[ "--port <port>", "If specified, set PORT in env for each child, incrementing port each time.", int ]
			[ "--grace <ms>", "How long to wait for a process to start." ]
		]
		toMessage: (cmd) ->
			{ c: 'add', g: cmd.group, d: cmd.cd, x: cmd.exec, n: cmd.count, p: cmd.port, ms: cmd.grace }
		onMessage: (msg, client, cb) ->
			acted = \
				required(msg, 'g', "--group is required with 'add'") and
				required(msg, 'x', "--exec is required with 'add'") and
				addGroup(msg.g, msg.d, msg.x, msg.n, msg.p, msg.ms, cb)
			client?.write $.TNET.stringify (if acted then "Group #{msg.g} added." else "No group added.")
			cb? null, acted
		onResponse: echoResponse
	}

	# Removing a group
	remove: removeAction = {
		options: [
			[ "--group <group>", "Name of the group to create." ]
		]
		toMessage: (cmd) -> { c: 'remove', g: cmd.group }
		onMessage: (msg, client, cb) ->
			acted = \
				required(msg, 'g', "--group is required with 'add'") and
				removeGroup msg.g
			client?.write $.TNET.stringify (if acted then "Group #{msg.g} removed." else "No group removed.")
			cb? null, acted
		onResponse: echoResponse
	}

	# Replace (remove then add) a group
	replace: {
		options: addAction.options
		toMessage: (cmd) ->
			Object.assign addAction.toMessage(cmd), { c: 'replace' }
		onMessage: (msg, client, cb) ->
			echo "in replace.onMessage", msg, (typeof client), (typeof cb)
			removeAction.onMessage { g: msg.g }, null, =>
				echo "before addAction.onMessage", msg, (typeof client), (typeof cb)
				addAction.onMessage msg, client, cb
		onResponse: echoResponse
	}

	# Start a group or instance.
	start: {
		options: [
			[ "--instance <id>", "Start one particular instance." ]
			[ "--group <group>", "Start all instances in a group." ]
		]
		toMessage: (cmd) -> { c: 'start', g: cmd.group, i: cmd.instance }
		onMessage: simpleAction 'start'
		onResponse: echoResponse
	}

	# Stop a group or instance.
	stop: {
		options: [
			[ "--instance <id>", "Stop one particular instance." ]
			[ "--group <group>", "Stop all instances in a group." ]
		]
		toMessage: (cmd) -> { c: 'stop', g: cmd.group, i: cmd.instance }
		onMessage: simpleAction 'stop'
		onResponse: echoResponse
	}

	# Restart a group or instance.
	restart: _restart_action = {
		options: [
			[ "--instance <id>", "Restart one particular instance." ]
			[ "--group <group>", "Restart all instances in a group." ]
		]
		toMessage: (cmd) -> { c: 'restart', g: cmd.group, i: cmd.instance }
		onMessage: simpleAction 'restart'
		onResponse: echoResponse
	}

	reload: _restart_action # alias

	# Get the status of everything.
	status: statusAction = {
		toMessage: (cmd) -> { c: 'status' }
		onResponse: (resp, socket) ->
			try
				if not socket?
					return console.log "Socket: null."
				if not ( resp? and ('object' is typeof resp) and ('groups' of resp) )
					return console.log "Response:", resp

				console.log "Status: online, pid: #{resp.pid} net: (#{socket._connectLatency}ms, #{resp.send - resp.start}ms, #{Date.now() - resp.send}ms)"
				console.log "Groups: #{resp.groups.length}"

				pad_columns = (a,w=[19, 7, 7, 10, 8, 8, 14, 7, 7]) ->
					(($.padLeft String(item ? ''), w[i]) for item,i in a ).join ''

				for group,g in resp.groups
					if g is 0
						console.log pad_columns ["Instance", "PID", "Port", "Uptime", "Healthy", "Enabled", "Status", "CPU", "RAM"]
					else
						console.log pad_columns ["--------", "---", "----", "------", "-------", "-------", "------", "---", "---"]
					for line,i in group.procs
						has_pid = line[1]?
						line[1] ?= Chalk.red "-"
						line[2] ?= Chalk.red "-"
						line[3] = formatUptime line[3]
						line[4] = has_pid and (healthSymbol line[4]) or line[1]
						line[5] = healthSymbol(line[5])
						line[7] = has_pid and (parseFloat(line[7]).toFixed(1) + "%") or line[1]
						line[8] = has_pid and ($.commaize(Math.round(line[8]/1024)) + "mb") or line[1]
						console.log pad_columns line
				socket.end()
			finally
				socket?.end()

		onMessage: (msg, client, cb) ->
			output = {
				start: Date.now()
				pid: process.pid
				groups: []
			}
			SlimProcess.getProcessTable (err, procs) => # force the cache to be fresh
				if err then return cb?(err, false)
				Groups.forEach (group) ->
					output.groups.push _group = { name: group.name, cd: group.cd, exec: group.exec, n: group.n, port: group.port, grace: group.grace, procs: [] }
					for proc in group
						pid = proc.proc?.pid
						pcpu = rss = 0
						if pid?
							SlimProcess.visitProcessTree pid, (_p) ->
								pcpu += _p.pcpu
								rss += _p.rss
						_group.procs.push [ proc.id, proc.proc?.pid, proc.port, proc.uptime, proc.healthy, proc.enabled, proc.statusString, pcpu, rss ]
				output.send = Date.now()
				client.write $.TNET.stringify output
				cb? null, true
			return false
	}
	stat: statusAction

	# Disable a group or instance.
	disable: {
		options: [
			[ "--instance <id>", "Disable (stop and don't restart) one instance." ]
			[ "--group <group>", "Disable all instances in a group." ]
		]
		toMessage: (cmd) -> { c: 'disable', g: cmd.group, i: cmd.instance }
		onMessage: simpleAction 'disable'
		onResponse: echoResponse
	}

	# Enable a group or instance.
	enable: {
		options: [
			[ "--instance <id>", "Enable (stop and don't restart) one instance." ]
			[ "--group <group>", "Enable all instances in a group." ]
		]
		toMessage: (cmd) -> { c: 'enable', g: cmd.group, i: cmd.instance }
		onMessage: simpleAction 'enable'
		onResponse: echoResponse
	}

	# Scale the number of instance in a group up/down.
	scale: {
		options: [
			[ "--group <group>", "Which group to scale." ]
			[ "--count <n>", "How many processes should be running.", int ]
		]
		toMessage: (cmd) -> { c: 'scale', g: cmd.group, n: cmd.count }
		onMessage: (msg, client) ->
			acted = \
				required msg, 'g', "--group is required with 'scale'" and
				(Groups.has(msg.g) or warn "Unknown group name passed to --group ('#{msg.g}')") and
				Groups.get(msg.g).scale(msg.n)
			if acted
				client?.write $.TNET.stringify "Scaled group to #{msg.n} processes."
			else
				client?.write $.TNET.stringify "Nothing to scale."
			acted
		onResponse: echoResponse
	}

	# Add/remove log output destinations.
	log: {
		options: [
			[ "--list", "List the current output file." ]
			[ "--file <file>", "Send output to this log file." ]
			[ "--disable", "Stop logging to file." ]
			[ "--clear", "Clear the log file." ]
			[ "--purge", "(alias for clear)" ]
			[ "--tail", "Pipe the log output to your console now." ]
		]
		toMessage: (cmd) -> { c: 'log', l: (trueFalse cmd.list), d: (cmd.disable), f: cmd.file, t: (trueFalse cmd.tail), p: (cmd.clear ? cmd.purge) }
		onMessage: (msg, client, cb) ->
			ret = false
			send = (obj) =>
				try client?.write $.TNET.stringify [ msg, obj ]
				catch err
					return cb?(err, false)
			if msg.f
				Output.setOutput msg.f, (err, acted) => acted and send msg.f
			if msg.d
				Output.setOutput null, (err, acted) => acted and send msg.d
			if msg.p
				outputFile = Output.getOutputFile()
				if exists(outputFile)
					ChildProcess.spawn("echo Log purged at `date`> #{expandPath outputFile}", { shell: true }).on 'exit', => send msg.p
			if client?
				if msg.l
					send Output.getOutputFile()
				if msg.t
					send null # signal the other side to init the stream
					handler = (data) =>
						try client.write $.TNET.stringify [ { t: true }, String(data) ]
						catch err
							echo "tail socket error:", err.stack ? err
							detach()
					detach = => Output.stream.removeListener 'tail', handler
					client.on 'close', detach
					client.on 'error', detach
					Output.stream.on 'tail', handler
			ret = (msg.f or msg.d)
			if ret then saveConfig?()
			cb?(null, ret)
			return ret
		onResponse: (item, socket) ->
			[ msg, resp ] = item
			if msg.f
				echo "Log file set:", msg.f
			if msg.d
				echo "Log file disabled."
			if msg.l
				echo 'Output files:'
				echo(file) for file in resp
			if msg.t
				if resp then process.stdout.write resp
				else echo "Connecting to log tail..."
			else
				socket.end()
			false
	}

	# Add/remove a health check.
	health: {
		options: [
			[ "--group <group>", "Check all processes in this group." ]
			[ "--path <path>", "Will request http://localhost:port/<path> and check the response." ]
			[ "--status <code>", "Check the status code of the response."]
			[ "--contains <text>", "Check that the response contains some bit of text."]
			[ "--interval <secs>", "How often to run a check." ]
			[ "--timeout <ms>", "Fail if response is slower than this." ]
			[ "--delete", "Remove a health check." ]
			[ "--pause", "Temporarily pause a health check." ]
			[ "--resume", "Resume a health check after pausing." ]
			[ "--list", "List all current health checks." ]
		]
		toMessage: (cmd) -> {
			c: 'health',
			g: cmd.group,
			p: cmd.path,
			s:(int cmd.status),
			v:(1000 * int cmd.interval),
			o:(int cmd.timeout),
			t: cmd.contains,
			d:(trueFalse cmd.delete),
			z:(trueFalse cmd.pause),
			r:(trueFalse cmd.resume),
			l: (trueFalse cmd.list)
		}
		onMessage: (msg, client, cb) ->
			reply = (x, ret) -> client?.write $.TNET.stringify x; cb?(ret); ret
			if msg.l # --list
				return reply Health.toConfig(), false

			unless 'g' of msg
				return reply "Group is required.", false

			if not Groups.has(msg.g)
				return reply "No such group: #{msg.g}", false

			if msg.d # --delete
				Health.unmonitor Groups.get(msg.g)
				return reply "Will stop monitoring #{msg.g}.", true

			if msg.z # --pause
				if Health.pause msg.g
					return reply "Pausing monitor of #{msg.g}.", true
				else
					return reply "Group is not currently monitored.", false

			if msg.r # --resume
				if Health.resume msg.g
					return reply "Resuming monitor of #{msg.g}.", true
				else
					return reply "Group does not have a resumable monitor.", false

			unless 'p' of msg
				return reply "--path is required when adding a monitor.", false

			if Health.monitor Groups.get(msg.g), msg.p, msg.v, msg.s, msg.t, msg.o
				return reply "Adding monitor for #{msg.g}.", true
			else
				return reply "Did not add monitor.", false

		onResponse: echoResponse
	}

	# Configure nginx integration.
	nginx: {
		options: [
			[ "--enable", "Generate a config file and automatically reload nginx when state changes." ]
			[ "--disable", "Don't generate files or reload nginx." ]
			[ "--file <file>", "Auto-generate an nginx file here using '.shep/nginx.template'."]
			[ "--reload-cmd <cmd>", "What command to run in order to cause nginx to reload."]
			[ "--reload-now", "Read nginx.template, write a fresh config file, and issue the reload cmd to nginx." ]

			[ "--group <name>", "Optional. If given, the following options apply:" ]
			[ "  --port <n>", "Default 80 (or 443). 'server { listen <n>; }'" ]
			[ "  --name <hostname>", "Default is the group name. 'server { server_name <name>; }'" ]
			[ "  --ssl_cert <path>", "Optional. If given, port defaults to 443." ]
			[ "  --ssl_key <path>", "Optional. If given, port defaults to 443." ]

			[ "--list", "Show the current nginx configuration." ]

		]
		toMessage: (cmd) -> {
			c: 'nginx'
			f: cmd.file
			r: cmd['reload-cmd']
			k: cmd.keepalive
			d: (trueFalse cmd.disable)
			e: (trueFalse cmd.enable)
			l: cmd.list
			g: cmd.group
			p: cmd.port
			n: cmd.name
			sc: cmd.ssl_cert
			sk: cmd.ssl_key
			rn: (trueFalse cmd['reload-now'])
		}
		onMessage: (msg, client, cb) ->
			reply = (m, ret) ->
				if ret
					client?.write $.TNET.stringify m
					saveConfig?()
				cb? (not ret and m or null), ret
				ret

			if msg.rn?
				Nginx.sync()
				return reply "writing nginx config", true

			if msg.g?
				if not Groups.has(msg.g)
					return reply "No such group.", false
				group = Groups.get(msg.g)
				if msg.p?
					group.public_port = parseInt(msg.p, 10)
				if msg.n?
					group.public_name = msg.n
				if msg.sc?
					unless exists(msg.sc)
						return reply "ssl_cert file '#{msg.sc}' does not exist.", false
					group.ssl_cert = msg.sc
				if msg.sk?
					unless exists(msg.sk)
						return reply "ssl_key file '#{msg.sk}' does not exist.", false
					group.ssl_key = msg.sc
				return reply "Group updated.", true

			if msg.l?
				return reply Nginx.toConfig(), false

			acted = 0
			if msg.f?.length then ++acted and Nginx.setFile(msg.f)
			if msg.r?.length then ++acted and Nginx.setReload(msg.r)
			if msg.e
				++acted and Nginx.setDisabled false
				if not exists(nginxTemplate)
					bytes = Nginx.defaults.templateText
					Fs.writeFile expandPath(nginxTemplate), bytes, (err, written) =>
						if err
							warn err
						else if written isnt bytes.length
							warn "Only wrote #{written} out of #{bytes.length} to #{nginxTemplate}"
						else
							echo "Wrote default content to #{nginxTemplate}"
			if msg.d then ++acted and Nginx.setDisabled true
			if acted > 0
				saveConfig?()
				return reply "nginx configuration updated.", true
			else
				return reply "nginx - no actions requested.", false
		onResponse: echoResponse
	}

	config: {
		options: [
			[ "--purge", "Remove all configuration." ]
			[ "--list", "Show the current configuration." ]
		]
		toMessage: (cmd) -> { c: 'config', p: (trueFalse cmd.purge), l: (trueFalse cmd.list) }
		onMessage: (msg, client, cb) ->
			if msg.p
				Fs.writeFile expandPath(configFile), "", cb
				client?.write $.TNET.stringify "Cleared log file."
			else
				Fs.readFile expandPath(configFile), (err, data) ->
					return if err
					client?.write $.TNET.stringify String(data)
			false
		onResponse: echoResponse
	}

}}

{ saveConfig } = require './util/config'
