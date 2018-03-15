#!/usr/bin/env coffee

$ = require 'bling'
echo = $.logger '[shepherd]'
Files = require '../files'
Daemon = require '../daemon'
{ parseArgv } = require '../util/parse-args'
cmd = process.cmdv ?= parseArgv()
_cmd = cmd._[0]

if cmd.help or cmd.h
	console.log "shepherd <start|stop|restart|status|add|remove|enable|disable>"
	process.exit 0

exit_soon = (code=0, ms=100) =>
	setTimeout (=> process.exit code), ms

doInit = (cb) ->
	defaultsFile = process.cwd() + "/.shepherd/defaults"
	echo "Checking for defaults file:", defaultsFile
	if Files.exists(configFile) and not (cmd.f or cmd.force)
		echo "Configuration already exists (#{Files.configFile})"
		cb?()
	else if Files.exists(defaultsFile)
		echo "Applying default config..."
		Fs.copyFile defaultsFile, Files.configFile, cb
	else
		echo "Creating base path shepherd here..."
		Files.createBasePath ".", cb
	null

switch _cmd # some commands get handled locally, without connecting to the daemon
	when 'init' then return doInit exit_soon
	when 'up'
		echo "Starting daemon..."
		return Daemon.doStart(true)
	when 'down'
		echo "Stopping daemon..."
		return Daemon.doStop(true)

{ Actions } = require '../actions'
unless action = Actions[_cmd]
	echo "No such action:", _cmd
	return

Net = require 'net'
Tnet = require '../util/tnet'
{ socketFile } = require '../files'

on_error = (err) ->
	echo "socket error", $.debugStack err

do retryConnect = ->
	connectStart = Date.now()
	socket = Net.connect path: socketFile
	socket.on 'error', (err) -> # probably daemon is not running, should start it
		if err.code is 'ENOENT'
			if _cmd is 'start'
				Daemon.doStart(false)
				setTimeout retryConnect, 3000
			else
				echo "Daemon not running."
				exit_soon 1
		else on_error err

	socket.on 'connect', ->
		socket._connectLatency = Date.now() - connectStart
		try
			msg = action.toMessage cmd
			bytes = $.TNET.stringify msg
		catch err then return on_error err
		socket.write bytes, ->
			# some commands wait for a response
			action.onConnect?(socket)
			if 'onResponse' of action
				timeout = $.delay 1000, ->
					echo "Timed-out waiting for a response from the daemon."
					socket.end()
				Tnet.read_stream socket, (item) ->
					timeout.cancel()
					action.onResponse item, socket
			else socket.end()

