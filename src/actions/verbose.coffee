{ $, echo, warn, verbose, required, echoResponse, setVerbose } = require '../common'
{ simpleAction } = require "../daemon/groups"

Object.assign module.exports, {
	options: [ ]
	toMessage: (cmd) ->
		{ c: 'verbose', v: switch cmd._[1]
			when "true","yes","on" then true
			else false }
	onMessage: (msg, client, next) ->
		setVerbose(msg.v)
		next()
	onResponse: echoResponse
}
