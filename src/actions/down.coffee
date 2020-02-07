{ $, echo, warn, verbose, required, echoResponse } = require '../common'
{ actOnAll } = require '../daemon/groups'
Daemon = require '../daemon'
{ int } = require '../util/format'

Object.assign module.exports, {
	options: [ ]
	toMessage: (cmd) ->
		{ c: 'down' }
	onMessage: (msg, client, cb) ->
		client?.write $.TNET.stringify "Shutting down..."
		actOnAll 'stop', (err, acted) ->
			client?.write $.TNET.stringify "All stopped (acted: #{acted})."
			if 'doStop' of Daemon
				Daemon.doStop(true)
			else
				console.error "Daemon did not export doStop: ", JSON.stringify(Object.keys(Daemon))
			cb? null, acted
	onResponse: echoResponse
}
