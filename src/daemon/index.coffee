#!/usr/bin/env coffee
# this is the master process that maintains the herd of processes

{ $, cmd, echo, warn, verbose } = require '../common'
Fs = require 'fs'
Net = require 'net'
Shell = require 'shelljs'
Chalk = require 'chalk'
Output = require './output'
{ Groups } = require('./groups')
{ Actions } = require('../actions')
{ pidFile,
	socketFile,
	outputFile,
	configFile,
	basePath,
	expandPath } = require '../files'
{ readConfig } = require '../util/config'
ChildProcess = require 'child_process'
SlimProcess = require '../util/process-slim'

exit_soon = (n, ms=200) =>
	setTimeout (=>
		verbose "Calling process.exit(#{n}), after delay of #{ms}ms"
		process.exit n
	), ms
die = (msg...) ->
	console.error msg...
	exit_soon 1

readPid = ->
	try parseInt Fs.readFileSync(expandPath pidFile).toString(), 10
	catch then undefined

handleMessage = (msg, client, cb) ->
	if 'auto' of msg
		if Groups.has(msg.auto)
			msg.g = msg.auto
		else
			[g, i] = msg.auto.split '-'
			if Groups.has(g)
				msg.i = g + "-" + parseInt(i, 10)
			else
				msg.g = msg.auto
	Actions[msg.c]?.onMessage? msg, client, cb

exists = (path) -> try (stat = Fs.statSync expandPath path).isFile() or stat.isSocket() catch then false

doStop = (exit, client) ->
	echo "Daemon.doStop(exit=#{exit})"
	unless pid = readPid()
		echo "No PID file."
		if exit
			echo "Exiting soon."
			return exit_soon 0
	else
		echo "Sending stop message to all groups..."
		Actions.stop.onMessage {}, null, (err) -> # send a stop command to all running instances
			echo "Returned from stop message..."
			# then kill the pid from the pid file
			SlimProcess.killAllChildren pid, "SIGTERM", (err) ->
				echo "Unlink: ", expandPath pidFile
				try Fs.unlinkSync expandPath pidFile
				echo "Unlink: ", expandPath socketFile
				try Fs.unlinkSync expandPath socketFile
				if exit
					return exit_soon 0
	null

doStatus = ->
	$.log "Socket:", socketFile, if exists(socketFile) then Chalk.green("(exists)") else Chalk.yellow("(does not exist)")
	$.log "PID File:", pidFile, if exists(pidFile) then Chalk.green("(exists)") else Chalk.yellow("(does not exist)")

started = false
runDaemon = => # in the foreground
	unless pidFile
		return die "Daemon has no pidFile configured."

	unless socketFile
		return die "Daemon has no socketFile configured."

	_pidFile = expandPath pidFile
	_socketFile = expandPath socketFile

	if exists(_pidFile)
		return die "Already running as PID:" + readPid()

	if exists(_socketFile)
		return die "Socket file still exists:" + socketFile

	Fs.writeFile _pidFile, String(process.pid), (err) =>
		if err then return die "Failed to write pid file:", err
		console.log "Setting output file...", outputFile
		Output.setOutput outputFile, (err) =>
			if err then return die "Failed to set output file:", err
			echo "Opening master socket...", socketFile
			socket = Net.Server().listen path: _socketFile
			socket.on 'error', (err) ->
				echo "Failed to open local socket:", $.debugStack err
				return exit_soon 1
			socket.on 'connection', (client) ->
				client.on 'error', (err) ->
					warn "client error:", err
				client.on 'data', (msg) ->
					start = Date.now()
					msg = $.TNET.parse(msg.toString())
					handleMessage msg, client, (err, acted) =>
						if err then try
							warn msg, "caused", $.debugStack(err)
							return client?.write $.TNET.stringify $.debugStack(err)
						_msg = Object.create null
						for k,v of msg when v? then _msg[k] = v
						echo "Command handled:", _msg, "in", (Date.now() - start), "ms"
			shutdown = (signal) -> ->
				echo "#{signal}: Shutting down..."
				verbose "#{signal}: Closing master socket..."
				try
					socket.close()
				catch err
					warn "Failed to close socket: ", err
				verbose "#{signal}: Stopping all groups..."
				Groups.forEach (group) -> group.stop()
				verbose "#{signal}: Unlinking PID file..."
				try
					Fs.unlinkSync(_pidFile)
				catch err
					warn "Failed to unlink pid file (#{_pidFile}):", err
				if signal isnt 'exit'
					verbose "#{signal}: Scheduling delayed exit..."
					return exit_soon 0, 2000
				null
			for sig in ['SIGINT','SIGTERM','exit']
				verbose "Signal #{sig}: attaching handler..."
				process.on sig, shutdown(sig) 
			readConfig()
			started = true

doStart = (exit) => # launch the daemon in the background and exit
	echo "Starting daemon..."
	cmd = process.argv[0]
	args = [
		process.argv[1].replace("client/index","daemon/index")
		"daemon",
		"--base \"#{basePath.replace /\/.shep$/,''}\"",
		(if cmd.verbose then "--verbose" else ""),
		(if cmd.quiet then "--quiet" else "")
	]
	devNull = Fs.openSync "/dev/null", 'a+'
	stdio = [ devNull, devNull, process.stderr ] # only let stderr pass through
	child = ChildProcess.spawn(cmd, args, { detached: true, shell: false, stdio: stdio })
	child.on 'error', (err) -> console.error "Child exec error:", err
	child.unref()
	if exit then exit_soon 0
	true

if require.main is module
	switch _c = cmd._[0]
		when "stop" then doStop(true); console.log("Stopped.")
		when "start" then doStart(true)
		when "daemon" then runDaemon()
		when "restart" then doStop(false); doStart(true)
		when "status" then doStatus()
		else
			console.log "Unknown usage:", cmd
			console.log "Usage: shepd <command>"
			console.log "Commands: start stop restart status help"
			exit_soon 0

true

Object.assign module.exports, { doStart, doStop, doStatus }
