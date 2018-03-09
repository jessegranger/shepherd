#!/usr/bin/env coffee

Net = require 'net'
Tnet = require '../util/tnet'
{ Actions } = require '../actions'
{ socketFile } = require '../files'
parseArguments = require 'minimist-string'
echo = $.logger '[shepherd]'

exec_command_string = (str) ->
	cmd = parseArguments(str)
	_cmd = cmd._[0]
	# echo "parsed:", cmd, Actions[_cmd]
	return unless action = Actions[_cmd]

	on_error = (err) ->
		echo "socket error", $.debugStack err

	socket = Net.connect path: socketFile
	socket.on 'error', (err) -> # probably daemon is not running, should start it
		if err.code is 'ENOENT'
			echo "master daemon (shepd) is not running."
		else on_error err

	socket.on 'connect', ->
		try
			msg = action.toMessage cmd
			bytes = $.TNET.stringify msg
		catch err then return on_error err
		socket.write bytes, ->
			# some commands wait for a response
			echo "Connected."
			action.onConnect?(socket)
			if 'onResponse' of action
				timeout = $.delay 1000, ->
					echo "Timed-out waiting for a response from the daemon."
					socket.end()
				Tnet.read_stream socket, (item) ->
					timeout.cancel()
					action.onResponse item, socket
			else socket.end()

exec_command_string process.argv.slice(2).join ' '
