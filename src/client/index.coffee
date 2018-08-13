#!/usr/bin/env coffee

Fs = require 'fs'
Net = require 'net'
Daemon = require '../daemon'
{ $, cmd, echo, warn, verbose, exit_soon } = require '../common'
{ exists, socketFile, configFile, basePath, createBasePath, expandPath } = require '../files'

if cmd.help or cmd.h or cmd._[0] is 'help'
	echo "shepherd <start|stop|restart|status|add|remove|enable|disable>"
	if cmd.verbose then echo """

		- start [id] : start an instance, group, or all (if no id given)
		- stop [id] : stop an instance, group, or all (if no id given)
		- restart [id] : restart an instance, group, or all (if no id given)
		- status : report status of everything
		- add [name] [--cd 'path'] <--exec 'command'> [--count n] [--port p] : adds a new process group
		  --cd 'path' - Optional, working directory of processes in the group.
		  --exec 'command' - Required. The shell command to execute, will be parsed by /bin/sh.
		  --count N - Optional. Number of processes to spawn. Default 1.
		  --port P - Optional. Assign the PORT environment variable for each process, incrementing from P.
		    A process given --port is "started" only when it starts listening on the proper PORT.
		- remove [name] : remove a process group
		- enable [id] : enable a group or single process
		- disable [id] : disable a group or single process

		e.g. 'shep add mygroup --cd test --exec "node app.js" --count 3 --port 1080'
		e.g. 'shep disable mygroup-2' # just disable the 3rd member of the group

	"""
	process.exit 0

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
		verbose "Checking for defaults file:", defaultsFile
		if exists(defaultsFile)
			echo "Applying default config..."
			Fs.copyFile expandPath(defaultsFile), expandPath(configFile), (err) => cb(null, true)
		else
			createBasePath ".", cb
	null

_on = (s, kv) => s.on(k, v.bind(s)) for k,v of kv

sendServerCmd = (_cmd, cb) =>
	unless exists(basePath)
		return echo "No .shep directory found."
	unless exists(socketFile)
		return echo "Status: offline."

	cb or= nop

	{ Actions } = require '../actions'
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
						echo "Status: offline."
						exit_soon 1
				else if err.code is 'EADDRNOTAVAIL'
					echo "Status: offline."
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
				@write bytes, =>
					action.onConnect?(@)
					unless 'onResponse' of action
						return @end()
					timeout = $.delay readTimeout, =>
						warn "Timed-out waiting for a response from the daemon."
						@end()
					Tnet.read_stream @, (item) =>
						timeout.cancel()
						action.onResponse item, @
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
			error: -> @end(); setTimeout poll, 100
			connect: -> @end(); cb(null)

# the subset of commands that cause status changes (and should show status)
statusChangeCommands = ['start','stop','enable','disable','add','remove','scale','replace']

c = cmd._[0]
switch c # some commands get handled without connecting to the daemon
	when 'version' then Fs.readFile("./VERSION").pipe(process.stdout)
	when 'init' then doInit (err) =>
		err and warn err
		exit_soon (if err then 1 else 0)
	when 'up'
		Daemon.doStart(false)
		waitForSocket 3000, (err) =>
			if err is 'timeout'
				console.log "timeout"
				exit_soon 1
			else
				sendServerCmd 'status', =>
					console.log "Finished."
					exit_soon 0
	when 'down' then Daemon.doStop(true)
	else sendServerCmd c, =>
		if c in statusChangeCommands
			$.delay 500, => sendServerCmd 'status', => exit_soon 0
		else exit_soon 0
