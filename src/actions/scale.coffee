{ $, echo, warn, verbose, required, echoResponse } = require '../common'
{ Groups } = require '../daemon/groups'
{ int } = require '../format'

Object.assign module.exports, {
	options: [
		[ "--group <group>", "Which group to scale." ]
		[ "--count <n>", "How many processes should be running.", int ]
	]
	toMessage: (cmd) -> { c: 'scale', g: cmd.group, n: cmd.count }
	onMessage: (msg, client) ->
		acted = \
			required msg, 'g', "--group is required with 'scale'" and
			(Groups.has(msg.g) or warn "Unknown group name passed to --group ('#{msg.g}')") and
			Groups.get(msg.g).scale(msg.n)
		if acted
			client?.write $.TNET.stringify "Scaled group to #{msg.n} processes."
		else
			client?.write $.TNET.stringify "Nothing to scale."
		acted
	onResponse: echoResponse
}
