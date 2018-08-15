{ $, echo, warn, verbose, required, echoResponse } = require '../../common'
{ simpleAction } = require "../daemon/groups"

Object.assign module.exports, {
	options: [
		[ "--instance <id>", "Restart one particular instance." ]
		[ "--group <group>", "Restart all instances in a group." ]
	]
	toMessage: (cmd) -> { c: 'restart', g: cmd.group, i: cmd.instance }
	onMessage: simpleAction 'restart'
	onResponse: echoResponse
}
