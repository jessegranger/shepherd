#!/usr/bin/env coffee

{ $, cmd, echo, warn, verbose } = require '../common'
Fs = require 'fs'
{ exists, socketFile, configFile, createBasePath, expandPath } = require '../files'
Daemon = require '../daemon'

if cmd.help or cmd.h
	console.log "shepherd <start|stop|restart|status|add|remove|enable|disable>"
	process.exit 0

exit_soon = (code=0, ms=100) =>
	setTimeout (=> process.exit code), ms

doInit = (cb) ->
	defaultsFile = process.cwd() + "/.shepherd/defaults"
	if exists(configFile) and not (cmd.f or cmd.force)
		echo "Configuration already exists (#{configFile})"
		cb?(null, false)
	else
		verbose "Checking for defaults file:", defaultsFile
		if exists(defaultsFile)
			echo "Applying default config..."
			Fs.copyFile expandPath(defaultsFile), expandPath(configFile), (err) => cb?(null, true)
		else
			createBasePath ".", cb
	null

sendServerCmd = (_cmd, cb) =>
	{ Actions } = require '../actions'
	unless action = Actions[_cmd]
		return warn "No such action:", _cmd

	Net = require 'net'
	Tnet = require '../util/tnet'

	on_error = (err) ->
		warn "socket error", $.debugStack err

	do retryConnect = ->
		connectStart = Date.now()
		socket = Net.connect path: expandPath socketFile
		socket.on 'close', => cb?()
		socket.on 'error', (err) -> # probably daemon is not running, should start it
			if err.code is 'ENOENT'
				if _cmd is 'start'
					Daemon.doStart(false)
					setTimeout retryConnect, 3000
				else
					echo "Status: offline."
					exit_soon 1
			else if err.code is 'EADDRNOTAVAIL'
				echo "Status: offline."
				exit_soon 1
			else on_error err

		socket.on 'connect', ->
			socket._connectLatency = Date.now() - connectStart
			try
				msg = action.toMessage cmd
				if cmd._.length > 1 and not (('group' of cmd) or ('instance' of cmd))
					if /\w/.test cmd._[1]
						msg.auto = cmd._[1]
				bytes = $.TNET.stringify msg
			catch err then return on_error err
			socket.write bytes, ->
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
	when 'up' then Daemon.doStart(false); $.delay 1000, => sendServerCmd 'status'
	when 'down' then return Daemon.doStop(true)
	else sendServerCmd cmd._[0], =>
		if cmd._[0] in ['start','stop','enable','disable','add','remove','scale','replace']
			setTimeout (=>
				sendServerCmd 'status'
			), 300
