{ $, echo, warn, verbose, required, echoResponse } = require '../common'
{ removeGroup } = require "../daemon/groups"

Object.assign module.exports, {
	options: [
		[ "--group <group>", "Name of the group to create." ]
	]
	toMessage: (cmd) -> { c: 'remove', g: cmd.group }
	onMessage: (msg, client, cb) ->
		acted = \
			required(msg, 'g', "--group is required with 'add'") and
			removeGroup msg.g
		client?.write $.TNET.stringify (if acted then "Group #{msg.g} removed." else "No group removed.")
		cb? null, acted
	onResponse: echoResponse
}
