{ $, echo } = require '../common'
Chalk = require 'chalk'
{ Groups } = require '../daemon/groups'
SlimProcess = require '../util/process-slim'
{ formatUptime } = require '../format'

healthSymbol = (v) -> switch v
	when undefined then Chalk.yellow "?"
	when true then Chalk.green "\u2713"
	when false then Chalk.red "x"

Object.assign module.exports, {
	options: [
		[ "--group <group>", "Only show status of one group." ]
		[ "--instance <id>", "Only show status of one instance." ]
	]
	toMessage: (cmd) -> { c: 'status', i: cmd.instance, g: cmd.group }
	onResponse: (resp, socket) ->
		try
			if not socket?
				return console.log "Socket: null."
			if not ( resp? and ('object' is typeof resp) and ('groups' of resp) )
				return console.log "Response:", resp

			console.log "Status: online, pid: #{resp.pid} net: (#{resp.send - resp.start}ms, #{Date.now() - resp.send}ms)"
			console.log "Groups: #{resp.groups.length}"

			pad_columns = (a,w=[19, 7, 7, 10, 8, 8, 14, 7, 7]) ->
				(($.padLeft String(item ? ''), w[i]) for item,i in a ).join ''

			for group,g in resp.groups
				if g is 0
					console.log pad_columns ["Instance", "PID", "Port", "Uptime", "Healthy", "Enabled", "Status", "CPU", "RAM"]
				else
					console.log pad_columns ["--------", "---", "----", "------", "-------", "-------", "------", "---", "---"]
				for line,i in group.procs
					has_pid = line[1]?
					line[1] ?= Chalk.red "-"
					line[2] ?= Chalk.red "-"
					line[3] = formatUptime line[3]
					line[4] = has_pid and (healthSymbol line[4]) or line[1]
					line[5] = healthSymbol(line[5])
					line[7] = has_pid and (parseFloat(line[7]).toFixed(1) + "%") or line[1]
					line[8] = has_pid and ($.commaize(Math.round(line[8]/1024)) + "mb") or line[1]
					console.log pad_columns line
			socket.end()
		finally
			socket?.end()

	onMessage: (msg, client, cb) ->
		output = {
			start: Date.now()
			pid: process.pid
			groups: []
		}
		SlimProcess.getProcessTable (err, procs) => # force the cache to be fresh
			if err then return cb?(err, false)
			Groups.forEach (group) ->
				return unless msg.g in [null, undefined, group.name]
				output.groups.push _group = { name: group.name, cd: group.cd, exec: group.exec, n: group.n, port: group.port, grace: group.grace, procs: [] }
				for proc in group
					continue unless msg.i in [null, undefined, proc.id]
					pid = proc.proc?.pid
					pcpu = rss = 0
					if pid?
						SlimProcess.visitProcessTree pid, (_p) ->
							pcpu += _p.pcpu
							rss += _p.rss
					_group.procs.push [ proc.id, proc.proc?.pid, proc.port, proc.uptime, proc.healthy, proc.enabled, proc.statusString, pcpu, rss ]
			output.send = Date.now()
			client.write $.TNET.stringify output
			cb? null, true
		return false
}
