{ $, echo, warn, verbose, required, echoResponse } = require '../common'
{ simpleAction } = require "../daemon/groups"

Object.assign module.exports, {
	options: [
		[ "--instance <id>", "Disable (stop and don't restart) one instance." ]
		[ "--group <group>", "Disable all instances in a group." ]
	]
	toMessage: (cmd) -> { c: 'disable', g: cmd.group, i: cmd.instance }
	onMessage: simpleAction 'disable'
	onResponse: echoResponse
}
