
$ = require 'bling'
Fs = require 'fs'
Nginx = require '../daemon/nginx'
Output = require '../daemon/output'
{ Groups } = require '../daemon/groups'
{ Actions } = require '../actions'
{ configFile } = require '../files'
{ parseArguments } = require './parse-args'

echo = $.logger "[config]"
verbose = echo # TODO: gate this by some param or env

_reading = false

saveConfig = ->
	return if _reading
	$.log "Saving config..."
	buf = ""
	Groups.forEach (group) ->
		buf += Actions.add.toConfig(group) + "\n"
		all_disabled = true
		for proc in group
			if proc.enabled
				all_disabled = false
				break
		if all_disabled
			buf += "disable --group #{group.name}\n"
		else
			for proc in group
				if not proc.enabled
					buf += "disable --instance #{proc.id}\n"
	buf += (n = Nginx.toConfig()) + (n.length and "\n" or "")
	buf += (o = Output.toConfig()) + (o.length and "\n" or "")
	buf += "start\n"
	Fs.writeFileSync configFile, buf
	true

readConfig = (cb) ->
	return if _reading
	_reading = true
	_err_text = ""
	config_lines = String(Fs.readFileSync configFile).split("\n")
	done = =>
		verbose "Finished reading config...", configFile, _err_text
		_reading = false
		cb?()
	do next = =>
		return done() unless config_lines.length > 0
		try
			line = config_lines.shift()
			return next() if line.length is 0
			echo line
			cmd = parseArguments(line)
			if (_cmd  = cmd._[0]) of Actions
				msg = Actions[_cmd].toMessage(cmd)
				Actions[_cmd].onMessage msg, null, next
			else next()
		catch err
			console.error err.stack
			_err_text = String(err)
	true

Object.assign module.exports, { saveConfig, readConfig }
