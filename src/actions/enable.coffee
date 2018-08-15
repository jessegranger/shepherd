{ $, echo, warn, verbose, required, echoResponse } = require '../common'
{ simpleAction } = require "../daemon/groups"

Object.assign module.exports, {
	options: [
		[ "--instance <id>", "Enable (stop and don't restart) one instance." ]
		[ "--group <group>", "Enable all instances in a group." ]
	]
	toMessage: (cmd) -> { c: 'enable', g: cmd.group, i: cmd.instance }
	onMessage: simpleAction 'enable'
	onResponse: echoResponse
}
