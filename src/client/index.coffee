#!/usr/bin/env coffee
{ parseArgv } = require '../util/parse-args'
cmd = process.cmdv ?= parseArgv()
_cmd = cmd._[0]

if cmd.help or cmd.h
	console.log "shepherd <start|stop|restart|status|add|remove|enable|disable>"
	process.exit 0

if _cmd is 'init'
	return require("../files").createBasePath ".", => process.exit 0

{ Actions } = require '../actions'
unless action = Actions[_cmd]
	echo "No such action:", _cmd
	return

Net = require 'net'
Tnet = require '../util/tnet'
{ socketFile } = require '../files'
echo = $.logger '[shepherd]'


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

