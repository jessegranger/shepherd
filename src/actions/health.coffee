$ = require 'bling'
Health = require '../daemon/health'
{ Groups } = require '../daemon/groups'
{ trueFalse } = require '../format'

Object.assign module.exports, {
	options: [
		[ "--group <group>", "Check all processes in this group." ]
		[ "--path <path>", "Will request http://localhost:port/<path> and check the response." ]
		[ "--status <code>", "Check the status code of the response."]
		[ "--contains <text>", "Check that the response contains some bit of text."]
		[ "--interval <secs>", "How often to run a check." ]
		[ "--timeout <ms>", "Fail if response is slower than this." ]
		[ "--delete", "Remove a health check." ]
		[ "--pause", "Temporarily pause a health check." ]
		[ "--resume", "Resume a health check after pausing." ]
		[ "--list", "List all current health checks." ]
	]
	toMessage: (cmd) -> {
		c: 'health',
		g: cmd.group,
		p: cmd.path,
		s:(int cmd.status),
		v:(1000 * int cmd.interval),
		o:(int cmd.timeout),
		t: cmd.contains,
		d:(trueFalse cmd.delete),
		z:(trueFalse cmd.pause),
		r:(trueFalse cmd.resume),
		l: (trueFalse cmd.list)
	}
	onMessage: (msg, client, cb) ->
		reply = (x, ret) -> client?.write $.TNET.stringify x; cb?(ret); ret
		if msg.l # --list
			return reply Health.toConfig(), false

		unless 'g' of msg
			return reply "Group is required.", false

		if not Groups.has(msg.g)
			return reply "No such group: #{msg.g}", false

		if msg.d # --delete
			Health.unmonitor Groups.get(msg.g)
			return reply "Will stop monitoring #{msg.g}.", true

		if msg.z # --pause
			if Health.pause msg.g
				return reply "Pausing monitor of #{msg.g}.", true
			else
				return reply "Group is not currently monitored.", false

		if msg.r # --resume
			if Health.resume msg.g
				return reply "Resuming monitor of #{msg.g}.", true
			else
				return reply "Group does not have a resumable monitor.", false

		unless 'p' of msg
			return reply "--path is required when adding a monitor.", false

		if Health.monitor Groups.get(msg.g), msg.p, msg.v, msg.s, msg.t, msg.o
			return reply "Adding monitor for #{msg.g}.", true
		else
			return reply "Did not add monitor.", false

	onResponse: (resp, socket) -> console.log resp; socket.end()
}