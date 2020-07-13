#!/usr/bin/env coffee

__VERSION__ = '0.3.24'

Fs = require 'fs'
Net = require 'net'
Daemon = require '../daemon'
{ Actions } = require '../actions'
{ $, cmd, echo, warn, verbose, exit_soon } = require '../common'
{ exists, socketFile, configFile, basePath, createBasePath, expandPath } = require '../files'

readTimeout = 3000 # how long to wait for a response, to any command
startupTimeout = 1000 # how long to wait after issuing an 'up' before inquiring with 'status'

nop = ->
doInit = (cb) ->
	defaultsFile = process.cwd() + "/.shep/defaults"
	cb or= nop
	if exists(configFile) and not (cmd.f or cmd.force)
		echo "Configuration already exists (#{configFile})"
		cb(null, false)
	else
		if exists(defaultsFile)
			echo "Applying default config...", configFile
			Fs.copyFile expandPath(defaultsFile), expandPath(configFile), (err) => cb(null, true)
		else
			createBasePath ".", cb
	null

_on = (s, kv) => s.on(k, v.bind(s)) for k,v of kv

sendServerCmd = (_cmd, cb) =>
	unless exists(basePath)
		return echo "No .shep directory found."
	unless exists(socketFile)
		return echo "Status: offline (no socket file)."

	cb or= nop

	unless action = Actions[_cmd]
		return warn "No such action:", _cmd

	Net = require 'net'
	Tnet = require '../util/tnet'

	on_error = (err) =>
		console.error "on_error:", err
		warn "socket error", $.debugStack err

	do retryConnect = =>
		_on Net.connect( path: expandPath socketFile ),
			close: -> cb(null, true)
			error: (err) ->
				if err.code is 'ENOENT'
					if _cmd is 'start'
						Daemon.doStart(false)
						setTimeout retryConnect, readTimeout
					else
						echo "Status: offline (#{err.code}, #{_cmd})."
						exit_soon 1
				else if err.code in ['EADDRNOTAVAIL', 'ECONNREFUSED']
					echo "Status: offline (#{err.code})."
					exit_soon 1
				else on_error err
			connect: ->
				try
					msg = action.toMessage cmd
					if cmd._.length > 1 and not (('group' of cmd) or ('instance' of cmd))
						if /\w+/.test cmd._[1]
							msg.auto = cmd._[1]
					bytes = $.TNET.stringify msg
				catch err then return on_error err
				# Send the command bytes to the server
				@write bytes, =>
					# Notify this action of a new connection
					action.onConnect?(@)
					unless 'onResponse' of action
						return @end()
					# If there's an onResponse, read the 
					timeout = $.delay readTimeout, =>
						warn "Timed-out waiting for a response from the daemon."
						@end()
					perItem = (item) => action.onResponse item, @
					Tnet.read_stream(@, perItem).then =>
						timeout.cancel()
						@end()
					null
				null
		null
	null

waitForSocket = (timeout, cb) => # wait for the daemon to connect to the other side of the socketFile
	start = +new Date()
	do poll = =>
		if (elapsed = +new Date() - start) > timeout
			return cb('timeout')
		unless exists(socketFile)
			return setTimeout poll, 100
		_on Net.connect( path: expandPath socketFile ),
			error: (err) ->
				@end() # close our side
				verbose "Ignoring error while waiting:", err
				setTimeout poll, 100 # retry
			connect: ->
				@end() # close our side, its just a probe
				cb(null)

doHelp = =>
	console.log if cmd._[1] of Actions
		"shep #{cmd._[1]}\n  " +
		(o.join(' - ') for o in Actions[cmd._[1]].options ? [[ "No options." ]]).join("\n  ")
	else "shep <#{(k for k of Actions).join "|"}>"
	process.exit 0

# the subset of commands that cause status changes (and should show status)
statusChangeCommands = ['start','stop','enable','disable','add','remove','scale','replace']

c = cmd._[0]
switch c # some commands get handled without connecting to the daemon
	when 'help' then doHelp()
	when 'version' then console.log(__VERSION__)
	when 'init' then doInit (err) =>
		err and warn err
		exit_soon (if err then 1 else 0)
	when 'up'
		Daemon.doStart(false)
		waitForSocket 5000, (err) =>
			if err is 'timeout'
				warn "Daemon did not start within timeout."
				exit_soon 1
			else sendServerCmd 'status', =>
				exit_soon 0
	# disabled special 'down' case, so that we create a 'down' message in the 'else' case below
	# when 'down' then Daemon.doStop(true)
	else sendServerCmd c, =>
		if c in statusChangeCommands
			$.delay 500, => sendServerCmd 'status', => exit_soon 0
		else exit_soon 0
