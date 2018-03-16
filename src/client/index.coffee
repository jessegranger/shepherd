#!/usr/bin/env coffee

$ = require 'bling'
Fs = require 'fs'
{ exists, socketFile, configFile, createBasePath } = require '../files'
Daemon = require '../daemon'
{ cmd, echo, warn, verbose } = require '../common'
_cmd = cmd._[0]

if cmd.help or cmd.h
	console.log "shepherd <start|stop|restart|status|add|remove|enable|disable>"
	process.exit 0

exit_soon = (code=0, ms=100) =>
	setTimeout (=> process.exit code), ms

doInit = (cb) ->
	defaultsFile = process.cwd() + "/.shepherd/defaults"
	verbose "Checking for defaults file:", defaultsFile
	if exists(configFile) and not (cmd.f or cmd.force)
		echo "Configuration already exists (#{configFile})"
		cb?()
	else if exists(defaultsFile)
		echo "Applying default config..."
		Fs.copyFile defaultsFile, configFile, cb
	else
		createBasePath ".", cb
	null

switch _cmd # some commands get handled without connecting to the daemon
	when 'init' then return doInit exit_soon
	when 'up' then return Daemon.doStart(true)
	when 'down' then return Daemon.doStop(true)

{ Actions } = require '../actions'
unless action = Actions[_cmd]
	return warn "No such action:", _cmd

Net = require 'net'
Tnet = require '../util/tnet'

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
		else if err.code is 'EADDRNOTAVAIL'
			echo "Daemon socket does not exist:", socketFile
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
					warn "Timed-out waiting for a response from the daemon."
					socket.end()
				Tnet.read_stream socket, (item) ->
					timeout.cancel()
					action.onResponse item, socket
			else socket.end()

