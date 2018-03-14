
$ = require 'bling'
Fs = require 'fs'
Nginx = require '../daemon/nginx'
Output = require '../daemon/output'
{ Groups } = require '../daemon/groups'
{ Actions } = require '../actions'
{ parseArguments } = require './parse-args'
{ configFile, basePath } = require '../files'

echo = $.logger "[config]"
verbose = echo # TODO: gate this by some param or env

_reading = false

saveConfig = (cb) ->
	if _reading
		$.log "Cannot saveConfig while reading config..."
		return cb?(false)
	$.log "Saving config..."
	clean = (o) -> o.replace(basePath, '%') + (o.length and "\n" or "")
	buf = clean Output.toConfig()
	Groups.forEach (group) ->
		buf += clean group.toConfig()
		all_disabled = true
		for proc in group when proc.enabled
			all_disabled = false
			break
		if all_disabled
			buf += "disable --group #{group.name}\n"
		else
			for proc in group when not proc.enabled
				buf += "disable --instance #{proc.id}\n"
	buf += clean Nginx.config()
	buf += "start\n"
	Fs.writeFile configFile, buf, (err) ->
		cb?(not err)
	true

readConfig = (cb) ->
	if _reading
		return cb?(false)
	_reading = true
	_err_text = ""
	config_lines = null
	done = =>
		verbose "Finished reading config...", configFile, _err_text
		_reading = false
		cb?()
	try config_lines = String(Fs.readFileSync configFile).split("\n")
	catch err
		_err_text = "(empty config file)"
		done()
	do next = =>
		return done() unless config_lines?.length > 0
		try
			line = config_lines.shift()
			return next() if line.length is 0
			line = line.replace(/%/g, basePath)
			echo line
			cmd = parseArguments(line)
			if (_cmd  = cmd._[0]) of Actions
				msg = Actions[_cmd].toMessage(cmd)
				echo "Calling #{_cmd}:onMessage with next =", (typeof next)
				Actions[_cmd].onMessage msg, null, next
			else next()
		catch err
			console.error err.stack
			_err_text = String(err)
			done()
	true

Object.assign module.exports, { saveConfig, readConfig }
