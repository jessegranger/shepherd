{ $, echo, warn, verbose, required, echoResponse } = require '../common'
{ actOnAll } = require '../daemon/groups'
{ int } = require '../util/format'

Object.assign module.exports, {
	options: [
	]
	toMessage: (cmd) ->
		{ c: 'down' }
	onMessage: (msg, client, cb) ->
		client?.write $.TNET.stringify "Shutting down..."
		actOnAll 'stop', (err, acted) ->
			client?.write $.TNET.stringify "All stopped."
			cb? null, acted
	onResponse: echoResponse
}
