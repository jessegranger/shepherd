{ $, echo, warn, verbose, required, echoResponse } = require '../common'
{ saveConfig } = require '../util/config'
{ trueFalse } = require "../util/format"
{ Groups } = require "../daemon/groups"
{ exists } = require "../files"
Output = require '../daemon/output'

Object.assign module.exports, {
	options: [
		[ "--list", "List the current output file." ]
		[ "--file <file>", "Send output to this log file." ]
		[ "--disable", "Stop logging to file." ]
		[ "--clear", "Clear the log file." ]
		[ "--purge", "(alias for clear)" ]
		[ "--tail", "Pipe the log output to your console now." ]
	]
	toMessage: (cmd) -> { c: 'log', l: (trueFalse cmd.list), d: (cmd.disable), f: cmd.file, t: (trueFalse cmd.tail), p: (cmd.clear ? cmd.purge) }
	onMessage: (msg, client, cb) ->
		ret = false
		send = (obj) =>
			try client?.write $.TNET.stringify [ msg, obj ]
			catch err
				return cb?(err, false)
		if msg.f
			Output.setOutput msg.f, (err, acted) => acted and send msg.f
		if msg.d
			Output.setOutput null, (err, acted) => acted and send msg.d
		if msg.p
			outputFile = Output.getOutputFile()
			if exists(outputFile)
				ChildProcess.spawn("echo Log purged at `date`> #{expandPath outputFile}", { shell: true }).on 'exit', => send msg.p
		if client?
			if msg.l
				send Output.getOutputFile()
			if msg.t
				send null # signal the other side to init the stream
				handler = (data) =>
					try client.write $.TNET.stringify [ { t: true }, String(data) ]
					catch err
						echo "tail socket error:", err.stack ? err
						detach()
				detach = => try Output.stream.removeListener 'tail', handler
				client.on 'close', detach
				client.on 'error', detach
				Output.stream.on 'tail', handler
		ret = (msg.f or msg.d)
		if ret then saveConfig?()
		cb?(null, ret)
		return ret
	onResponse: (item, socket) ->
		[ msg, resp ] = item
		if msg.f
			echo "Log file set:", msg.f
		if msg.d
			echo "Log file disabled."
		if msg.l
			echo 'Output files:'
			echo(file) for file in resp
		if msg.t
			if resp then process.stdout.write resp
			else echo "Connecting to log tail..."
		else
			socket.end()
		false
}
