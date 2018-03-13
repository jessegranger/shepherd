
$ = require 'bling'
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
{ configFile } = require "./files"
echo = $.logger "-"

healthSymbol = (v) -> switch v
	when undefined then Chalk.yellow "?"
	when true then Chalk.green "\u2713"
	when false then Chalk.red "x"

{ Groups, addGroup, removeGroup, simpleAction } = require "./daemon/groups"

warn = (msg) ->
	$.log "[warning]", msg
	return false

required = (msg, key, label) ->
	unless msg[key] and msg[key].length
		return warn "#{label} is required."
	true

module.exports.Actions = Actions = {

	# Adding a group
	add: {
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
		toConfig: (group) ->
			"add --group #{group.name} --cd #{group.cd} --exec \"#{group.exec}\" --count #{group.n} --grace #{group.grace}" +
				(if group.port then " --port #{group.port}" else "")
		onMessage: (msg, client, cb) ->
			cb null,
				required(msg, 'g', "--group is required with 'add'") and
				required(msg, 'x', "--exec is required with 'add'") and
				addGroup(msg.g, msg.d, msg.x, msg.n, msg.p, msg.ms)
	}

	# Removing a group
	remove: {
		options: [
			[ "--group <group>", "Name of the group to create." ]
		]
		toMessage: (cmd) -> { c: 'remove', g: cmd.group }
		onMessage: (msg, client, cb) -> cb null, removeGroup msg.g
	}

	# Start a group or instance.
	start: {
		options: [
			[ "--instance <id>", "Start one particular instance." ]
			[ "--group <group>", "Start all instances in a group." ]
		]
		toMessage: (cmd) -> { c: 'start', g: cmd.group, i: cmd.instance }
		onMessage: simpleAction 'start'
	}

	# Stop a group or instance.
	stop: {
		options: [
			[ "--instance <id>", "Stop one particular instance." ]
			[ "--group <group>", "Stop all instances in a group." ]
		]
		toMessage: (cmd) -> { c: 'stop', g: cmd.group, i: cmd.instance }
		onMessage: simpleAction 'stop'
	}

	# Restart a group or instance.
	restart: _restart_action = {
		options: [
			[ "--instance <id>", "Restart one particular instance." ]
			[ "--group <group>", "Restart all instances in a group." ]
		]
		toMessage: (cmd) -> { c: 'restart', g: cmd.group, i: cmd.instance }
		onMessage: simpleAction 'restart'
	}

	reload: _restart_action # alias

	# Get the status of everything.
	status: {
		toMessage: (cmd) -> { c: 'status' }
		onResponse: (resp, socket) ->

			console.log "Status: online (connect: #{socket._connectLatency}ms, compute: #{resp.send - resp.start} ms, transfer: #{Date.now() - resp.send} ms)"
			console.log "Groups: #{resp.groups.length}"

			pad_columns = (a,w=[19, 7, 7, 10, 8, 8, 14, 7, 7]) ->
				(($.padLeft String(item ? ''), w[i]) for item,i in a ).join ''

			for group,g in resp.groups
				# console.log "Group: #{group.name} Count: #{group.n}"
				# console.log " -- "
				if g is 0
					console.log pad_columns ["Instance", "PID", "Port", "Uptime", "Healthy", "Enabled", "Status", "CPU", "RAM"]
				else
					console.log pad_columns ["--------", "---", "----", "------", "-------", "-------", "------", "---", "---"]
				for line,i in group.procs
					line[1] ?= Chalk.red "-"
					line[2] ?= Chalk.red "-"
					line[3] = formatUptime line[3]
					line[4] = healthSymbol line[4]
					line[5] = healthSymbol line[5]
					line[7] = line[7] + "%"
					line[8] = $.commaize(Math.round(line[8]/1024)) + "mb"
					console.log pad_columns line
			socket.end()

		onMessage: (msg, client, cb) ->
			output = {
				start: Date.now()
				groups: []
			}
			SlimProcess.getProcessTable (err, procs) => # force the cache to be fresh
				if err then return cb(err, false)
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
				cb null, true
			return false
	}

	# Disable a group or instance.
	disable: {
		options: [
			[ "--instance <id>", "Disable (stop and don't restart) one instance." ]
			[ "--group <group>", "Disable all instances in a group." ]
		]
		toMessage: (cmd) -> { c: 'disable', g: cmd.group, i: cmd.instance }
		onMessage: simpleAction 'disable'
	}

	# Enable a group or instance.
	enable: {
		options: [
			[ "--instance <id>", "Enable (stop and don't restart) one instance." ]
			[ "--group <group>", "Enable all instances in a group." ]
		]
		toMessage: (cmd) -> { c: 'enable', g: cmd.group, i: cmd.instance }
		onMessage: simpleAction 'enable'
	}

	# Scale the number of instance in a group up/down.
	scale: {
		options: [
			[ "--group <group>", "Which group to scale." ]
			[ "--count <n>", "How many processes should be running.", int ]
		]
		toMessage: (cmd) -> { c: 'scale', g: cmd.group, n: cmd.count }
		onMessage: (msg, client) ->
			required msg, 'g', "--group is required with 'scale'" and
			(Groups.has(msg.g) or warn "Unknown group name passed to --group ('#{msg.g}')") and
			Groups.get(msg.g).scale(msg.n)
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
			send = (obj) =>
				client?.write $.TNET.stringify [ msg, obj ]
			if msg.f
				Output.setOutput msg.f, (err, acted) =>
					acted and send msg.f
			if msg.d
				Output.setOutput null, (err, acted) =>
					acted and send msg.d
			if msg.p
				ChildProcess.spawn("echo > #{Output.getOutputFile()}", { shell: true }).on 'exit', =>
					send msg.p
			if client?
				if msg.l
					client.write $.TNET.stringify [ msg, Output.getOutputFile() ]
				if msg.t
					try client.write $.TNET.stringify [ msg, null ]
					catch err
						return cb()
					handler = (data) =>
						try client.write $.TNET.stringify [ { t: true }, String(data) ]
						catch err
							echo "tail socket error:", err.stack ? err
							detach()
					detach = => Output.stream.removeListener 'tail', handler
					client.on 'close', detach
					client.on 'error', detach
					Output.stream.on 'tail', handler
			cb()
			return false
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
				echo resp ? "Connecting to log tail..."
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
		]
		toMessage: (cmd) -> {
			c: 'health',
			g: cmd.group,
			p: cmd.path,
			s:(int cmd.status),
			i:(1000 * int cmd.interval),
			o:(int cmd.timeout),
			t: cmd.contains,
			d:(trueFalse cmd.delete),
			z:(trueFalse cmd.pause),
			r:(trueFalse cmd.resume)
		}
		onMessage: (msg, client, cb) ->
			ret = false
			if msg.d then ret = Health.unmonitor msg.u
			if msg.z then ret = Health.pause msg.u
			if msg.r then ret = Health.resume msg.u
			else
				if Groups.has(msg.g)
					Health.monitor Groups.get(msg.g), msg.p, msg.i, msg.s, msg.t, msg.o
				else ret = false
			cb?(ret)
			ret
	}

	# Configure nginx integration.
	nginx: {
		options: [
			[ "--file <file>", "Auto-generate an nginx file with an upstream definition for each group."]
			[ "--reload <cmd>", "What command to run in order to cause nginx to reload."]
			[ "--disable", "Don't generate files or reload nginx." ]
			[ "--keepalive <n>", "How many connections to hold open." ]
		]
		toMessage: (cmd) -> { c: 'nginx', f: cmd.file, r: cmd.reload, k: cmd.keepalive, d: trueFalse cmd.disable }
		onMessage: (msg, client, cb) ->
			if msg.f?.length then Nginx.setFile msg.f
			if msg.r?.length then Nginx.setReload msg.r
			if msg.k?.length then Nginx.setKeepAlive msg.k
			Nginx.setDisabled msg.d
			cb?()
	}

	config: {
		options: [
			[ "--purge", "Remove all configuration." ]
		]
		toMessage: (cmd) -> { c: 'config', p: (trueFalse cmd.purge) }
		onMessage: (msg, client, cb) ->
			if msg.p
				Fs.writeFile configFile, "", cb
			false
	}

}
