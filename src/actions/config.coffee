{ $, echo, warn, verbose, required, echoResponse } = require '../../common'
{ trueFalse } = require "../format"
Fs = require 'fs'

Object.assign module.exports, {
	options: [
		[ "--purge", "Remove all configuration." ]
		[ "--list", "Show the current configuration." ]
	]
	toMessage: (cmd) -> { c: 'config', p: (trueFalse cmd.purge), l: (trueFalse cmd.list) }
	onMessage: (msg, client, cb) ->
		if msg.p
			Fs.writeFile expandPath(configFile), "", cb
			client?.write $.TNET.stringify "Cleared log file."
		else
			Fs.readFile expandPath(configFile), (err, data) ->
				return if err
				client?.write $.TNET.stringify String(data)
		false
	onResponse: echoResponse
}
