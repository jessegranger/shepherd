#!/usr/bin/env coffee

# this is the master process that maintains the herd of processes

$ = require "bling"
Fs = require "fs"
Net = require "net"
Shell = require "shelljs"
Chalk = require "chalk"
Output = require "./output"
{ Groups } = require("./groups")
{ Actions } = require("../actions")
{ pidFile,
	socketFile,
	configFile } = require "../files"
{ readConfig } = require "../util/config"

echo = $.logger "[shepd]"

exit_soon = (n, ms=200) => setTimeout (=> process.exit n), ms

unless 'HOME' of process.env
	echo "No $HOME in environment, can't place .shepherd directory."
	return exit_soon 1

readPid = ->
	try parseInt Fs.readFileSync(pidFile).toString(), 10
	catch then undefined

handleMessage = (msg, client) ->
	Actions[msg.c]?.onMessage? msg, client

exists = (path) -> try (stat = Fs.statSync path).isFile() or stat.isSocket() catch then false

doStop = (exit) ->
	if pid = readPid()
		echo "Sending stop action..."
		Actions.stop.onMessage({}) # send a stop command to all running instances
		# give them a little time to exit gracefully
		echo "Killing daemon pid: #{pid}..."
		# then kill the pid from the pid file (our own?)
		result = Shell.exec "kill #{pid}", { silent: true, async: false } # use Shell.exec for easier stderr peek after
		if result.stderr.indexOf("No such process") > -1
			echo "Removing stale PID file and socket."
			try Fs.unlinkSync(pidFile)
			try Fs.unlinkSync(socketFile)
	if exit
		echo "Exiting with code 0"
		return exit_soon 0

doStatus = ->
	echo "Socket:", socketFile, if exists(socketFile) then Chalk.green("(exists)") else Chalk.yellow("(does not exist)")
	echo "PID File:", pidFile, if exists(pidFile) then Chalk.green("(exists)") else Chalk.yellow("(does not exist)")

doStart = ->
	echo "Starting..."
	if exists(pidFile)
		echo "Already running as PID:", readPid()
		return exit_soon 1

	if exists(socketFile)
		echo "Socket file still exists:", socketFile
		return exit_soon 1
	
	echo "Writing PID #{process.pid} to file...", pidFile
	Fs.writeFileSync(pidFile, process.pid)

	echo "Reading config...", configFile
	readConfig()

	echo "Listening on master socket...", socketFile
	socket = Net.Server().listen({ path: socketFile })
	socket.on 'error', (err) ->
		echo "Socket error:", $.debugStack err
		return exit_soon 1
	socket.on 'connection', (client) ->
		client.on 'data', (msg) ->
			msg = $.TNET.parse(msg.toString())
			handleMessage(msg, client)

	shutdown = (signal) -> ->
		echo "Shutting down...", signal
		try Fs.unlinkSync(pidFile)
		try socket.close()
		Groups.forEach (group) ->
			for proc in group
				proc.expected = false
		Groups.forEach (group) -> group.stop()
		if signal isnt 'exit'
			return exit_soon 0

	for sig in ['SIGINT','SIGTERM','exit']
		process.on sig, shutdown(sig) 
	

switch _cmd = $(process.argv).last()
	when "stop" then doStop(true) # stop and exit
	when "start" then doStart()
	when "restart"
		doStop(false) # stop but dont exit
		# replace " restart" with " start"
		cmd = process.argv.join(' ').replace(/ restart$/, " start")
		# start a new child with the "start" command-line
		console.log "exec:", cmd
		child = Shell.exec(cmd, { silent: false, async: true })
		child.unref()

		exit_soon 0
	when "status" then doStatus()
	else
		console.log "Usage: shepd <command>"
		console.log "Commands: start stop restart status help"
		exit_soon 0

