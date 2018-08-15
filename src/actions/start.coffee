{ $, echo, warn, verbose, required, echoResponse } = require '../common'
{ simpleAction } = require "../daemon/groups"

Object.assign module.exports, {
	options: [
		[ "--instance <id>", "Start one particular instance." ]
		[ "--group <group>", "Start all instances in a group." ]
	]
	toMessage: (cmd) -> { c: 'start', g: cmd.group, i: cmd.instance }
	onMessage: simpleAction 'start'
	onResponse: echoResponse
}
