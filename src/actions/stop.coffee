{ $, echo, warn, verbose, required, echoResponse } = require '../../common'
{ simpleAction } = require "../daemon/groups"

Object.assign module.exports, {
	options: [
		[ "--instance <id>", "Stop one particular instance." ]
		[ "--group <group>", "Stop all instances in a group." ]
	]
	toMessage: (cmd) -> { c: 'stop', g: cmd.group, i: cmd.instance }
	onMessage: simpleAction 'stop'
	onResponse: echoResponse
}
