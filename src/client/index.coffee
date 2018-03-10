#!/usr/bin/env coffee
{ parseArgv } = require '../util/parse-args'
cmd = parseArgv()
if cmd.path?.length > 0
	process.env.SHEPHERD_HOME = cmd.path

Net = require 'net'
Tnet = require '../util/tnet'
{ Actions } = require '../actions'
{ socketFile } = require '../files'
echo = $.logger '[shepherd]'

_cmd = cmd._[0]
if cmd.help or cmd.h
	console.log "shepherd <start|stop|restart|status|add|remove|enable|disable>"
	process.exit 0
return unless action = Actions[_cmd]

on_error = (err) ->
	echo "socket error", $.debugStack err

connectStart = Date.now()
socket = Net.connect path: socketFile
socket.on 'error', (err) -> # probably daemon is not running, should start it
	if err.code is 'ENOENT'
		echo "master daemon (shepd) is not running."
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

