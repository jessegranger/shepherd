{ $, echo, warn, verbose, required, echoResponse } = require '../../common'
{ addGroup } = require '../daemon/groups'

Object.assign module.exports, {
	options: [
		[ "--group <group>", "Name of the group to create." ]
		[ "--cd <path>", "The working directory to spawn processes in." ]
		[ "--exec <script>", "Any shell command, e.g. 'node app.js'." ]
		[ "--count <n>", "The starting size of the group.", int ]
		[ "--port <port>", "If specified, set PORT in env for each child, incrementing port each time.", int ]
		[ "--grace <ms>", "How long to wait for a process to start." ]
	]
	toMessage: (cmd) ->
		{ c: 'add', g: cmd.group, d: cmd.cd, x: cmd.exec, n: cmd.count, p: cmd.port, ms: cmd.grace }
	onMessage: (msg, client, cb) ->
		acted = \
			required(msg, 'g', "--group is required with 'add'") and
			required(msg, 'x', "--exec is required with 'add'") and
			addGroup(msg.g, msg.d, msg.x, msg.n, msg.p, msg.ms, cb)
		client?.write $.TNET.stringify (if acted then "Group #{msg.g} added." else "No group added.")
		cb? null, acted
	onResponse: echoResponse
}
