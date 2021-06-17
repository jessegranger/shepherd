{ $, echo, echoResponse } = require '../common'
Daemon = require '../daemon'

Object.assign module.exports, {
	options: [ ]
	toMessage: (cmd) -> { c: 'down' }
	onResponse: echoResponse
	onMessage: (msg, client, cb) ->
		client_echo = (msg) ->
			echo "src/action/down", msg
			client?.write $.TNET.stringify msg
		client_echo "Shutting down..."
		Daemon.doStop true, client, (err, acted) ->
			client_echo "Stopped."
			cb? null, acted
}
