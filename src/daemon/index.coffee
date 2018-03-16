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
	configFile } = require '../files'
{ readConfig } = require '../util/config'
ChildProcess = require 'child_process'

exit_soon = (n, ms=200) => setTimeout (=> process.exit n), ms
die = (msg...) ->
	console.error msg...
	exit_soon 1

unless 'HOME' of process.env
	echo "No $HOME in environment, can't place .shepherd directory."
	return exit_soon 1

readPid = ->
	try parseInt Fs.readFileSync(pidFile).toString(), 10
	catch then undefined

handleMessage = (msg, client, cb) ->
	Actions[msg.c]?.onMessage? msg, client, cb

exists = (path) -> try (stat = Fs.statSync path).isFile() or stat.isSocket() catch then false

doStop = (exit) ->
	echo "Stopping daemon..."
	if pid = readPid()
		Actions.stop.onMessage({}) # send a stop command to all running instances
		# give them a little time to exit gracefully
		echo "Killing daemon pid: #{pid}..."
		# then kill the pid from the pid file (our own?)
		result = Shell.exec "kill #{pid}", { silent: true, async: false } # use Shell.exec for easier stderr peek after
		if result.stderr.indexOf("No such process") > -1
			echo "Removing stale PID file and socket."
			try Fs.unlinkSync(pidFile)
			try Fs.unlinkSync(socketFile)
	else echo "Daemon not running."
	if exit
		return exit_soon 0

doStatus = ->
	$.log "Socket:", socketFile, if exists(socketFile) then Chalk.green("(exists)") else Chalk.yellow("(does not exist)")
	$.log "PID File:", pidFile, if exists(pidFile) then Chalk.green("(exists)") else Chalk.yellow("(does not exist)")

started = false
runDaemon = => # in the foreground

	unless pidFile and socketFile
		return die "Daemon does not have a base path."

	if exists(pidFile)
		echo "Already running as PID:", readPid()
		return exit_soon 1

	if exists(socketFile)
		echo "Socket file still exists:", socketFile
		return exit_soon 1

	Fs.writeFile pidFile, process.pid, (err) =>
		if err then return die "Failed to write pid file:", err
		Output.setOutput outputFile, (err) =>
			if err then return die "Failed to set output file:", err
			echo "Opening master socket...", socketFile
			socket = Net.Server().listen path: socketFile
			socket.on 'error', (err) ->
				echo "Failed to open local socket:", $.debugStack err
				return exit_soon 1
			socket.on 'connection', (client) ->
				client.on 'data', (msg) ->
					start = Date.now()
					msg = $.TNET.parse(msg.toString())
					handleMessage msg, client, =>
						_msg = Object.create null
						for k,v of msg when v? then _msg[k] = v
						echo "Command handled:", _msg, "in", (Date.now() - start), "ms"
			shutdown = (signal) -> ->
				echo "Shutting down...", signal
				try Fs.unlinkSync(pidFile)
				try socket.close()
				Groups.forEach (group) ->
					for proc in group
						proc.expected = false
					null
				Groups.forEach (group) -> group.stop()
				if signal isnt 'exit'
					return exit_soon 0
				null
			for sig in ['SIGINT','SIGTERM','exit']
				process.on sig, shutdown(sig) 
			readConfig()
			started = true

doStart = (exit) => # launch the daemon in the background and exit
	echo "Starting daemon..."
	_cmd = process.argv.slice(0,2).join(' ').replace("client/index","daemon/index") + " daemon"
	# start a new child with the "start" command-line
	devNull = Fs.openSync "/dev/null", 'a+'
	stdio = [ devNull, devNull, process.stderr ] # only let stderr pass through
	child = ChildProcess.spawn(_cmd, { detached: true, shell: true, stdio: stdio })
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
