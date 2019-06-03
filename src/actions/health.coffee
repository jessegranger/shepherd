{ $, echoResponse, warn, verbose }  = require '../common'
Health = require '../daemon/health'
{ Groups } = require '../daemon/groups'
{ saveConfig } = require '../util/config'
{ int, trueFalse } = require '../util/format'

Object.assign module.exports, {
	options: [
		[ "--group <group>", "Check all processes in this group." ]
		[ "--path <path>", "Will request http://localhost:port/<path> and check the response." ]
		[ "--status <code>", "Check the status code of the response."]
		[ "--exec <command>", "Instead of requesting a path, execute a shell command." ]
		[ "--contains <text>", "Check that the response contains some bit of text."]
		[ "--interval <secs>", "How often to run a check.", int ]
		[ "--timeout <ms>", "Fail if response is slower than this.", int ]
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
		e: cmd.exec,
		v:(1000 * int(cmd.interval ? 10)),
		o:(int(cmd.timeout ? 3000)),
		t: cmd.contains,
		d:(trueFalse cmd.delete),
		z:(trueFalse cmd.pause),
		r:(trueFalse cmd.resume),
		l:(trueFalse cmd.list)
	}
	onMessage: (msg, client, cb) ->
		verbose "health.onMessage", msg
		reply = (x, ret) ->
			client?.write $.TNET.stringify x
			ret and saveConfig()
			cb?(ret); ret
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

		unless ('p' of msg) or ('e' of msg)
			return reply "Either --path or --exec is required when adding a monitor.", false

		err = Health.monitor Groups.get(msg.g), msg.p, msg.e, msg.v, msg.s, msg.t, msg.o
		if err != true
			return reply "Failed to add monitor (error: "+err+")", false
		else
			return reply "Adding monitor for #{msg.g}.", true

	onResponse: echoResponse
}
