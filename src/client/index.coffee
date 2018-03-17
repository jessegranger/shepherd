#!/usr/bin/env coffee

{ $, cmd, echo, warn, verbose } = require '../common'
Fs = require 'fs'
{ exists, socketFile, configFile, createBasePath } = require '../files'
Daemon = require '../daemon'

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

doServerCommand = (_cmd, cb) =>
	{ Actions } = require '../actions'
	unless action = Actions[_cmd]
		return warn "No such action:", _cmd

	Net = require 'net'
	Tnet = require '../util/tnet'

	on_error = (err) ->
		warn "socket error", $.debugStack err

	do retryConnect = ->
		connectStart = Date.now()
		socket = Net.connect path: socketFile
		socket.on 'close', => cb?()
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
				else
					socket.end()
				null
			null
		null
	null

switch cmd._[0] # some commands get handled without connecting to the daemon
	when 'init' then return doInit exit_soon
	when 'up' then Daemon.doStart(false); $.delay 1000, => doServerCommand 'status'
	when 'down' then return Daemon.doStop(true)
	else doServerCommand cmd._[0], =>
		if cmd._[0] in ['start','stop','enable','disable','add','remove','scale']
			setTimeout (=>
				doServerCommand 'status'
			), 300
