
{ $, echo, warn, verbose } = require './common'
Fs = require 'fs'
Tnet = require './util/tnet'
Chalk = require 'chalk'
Output = require './daemon/output'
SlimProcess = require './util/process-slim'
ChildProcess = require 'child_process'
int = (n) -> parseInt((n ? 0), 10)
{ yesNo, trueFalse } = require "./format"
{ configFile, exists, nginxTemplate, expandPath } = require "./files"
saveConfig = null

{ Groups, addGroup, removeGroup, simpleAction } = require "./daemon/groups"

required = (msg, key, label) ->
	unless msg
		return warn "msg is required."
	unless msg[key] and msg[key].length
		return warn "#{label} is required."
	true

echoResponse = (resp, socket) -> console.log resp; socket.end()

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
	status: statusAction = require "./actions/status"
	stats: statusAction
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
	health: require './actions/health'

	# Configure nginx integration.
	nginx: require './actions/nginx'

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
