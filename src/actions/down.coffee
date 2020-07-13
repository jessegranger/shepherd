{ $, echo, warn, verbose, required, echoResponse } = require '../common'
{ actOnAll } = require '../daemon/groups'
Daemon = require '../daemon'
{ int } = require '../util/format'

Object.assign module.exports, {
	options: [ ]
	toMessage: (cmd) -> { c: 'down' }
	onResponse: echoResponse
	onMessage: (msg, client, cb) ->
		client_echo = (msg) ->
			echo "src/action/down", msg
			client?.write $.TNET.stringify "src/action/down " + msg
		client_echo "Shutting down..."
		Daemon.doStop true, client, (err) ->
			client_echo "Daemon.doStop cb returned. (err: #{err})"
			cb? null, true
}
