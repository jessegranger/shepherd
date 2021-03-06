
{ $, echo, warn, verbose } = require '../common'

Fs = require 'fs'
Nginx = require '../daemon/nginx'
Output = require '../daemon/output'
Health = require '../daemon/health'
{ Groups } = require '../daemon/groups'
{ parseArguments } = require './parse-args'
{ configFile, basePath, expandPath } = require '../files'
Actions = null

_reading = false

saveConfig = (cb) ->
	if _reading
		verbose "Cannot call saveConfig() while reading configuration file."
		return cb?(null, false)
	verbose "Saving config..."
	clean = (o) -> (o?.replace(basePath, '%') ? '') + (o?.length and "\n" or "")
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
	buf += clean Health.toConfig()
	buf += clean Nginx.toConfig()
	buf += "start\n"
	Fs.writeFile expandPath(configFile), buf, (err) ->
		cb?(err, false)
	true

readConfig = (cb) ->
	if _reading
		return cb?(null, false)
	_reading = true
	_err_text = ""
	config_lines = null
	done = =>
		if _reading
			verbose "Finished reading config...", configFile, _err_text
			_reading = false
			cb?(null, true)
	try config_lines = String(Fs.readFileSync expandPath configFile).split("\n")
	catch err
		_err_text = "(empty config file)"
		return done()
	do next = =>
		return done() unless config_lines?.length > 0
		try
			line = config_lines.shift()
			return next() if line.length is 0
			echo "config:", line
			cmd = parseArguments(line)
			if (_cmd = cmd._[0]) of Actions
				Actions[_cmd].onMessage \
					Actions[_cmd].toMessage(cmd), \
						null, next
			else next()
		catch err
			console.error err.stack
			_err_text = String(err)
			done()
	true

Object.assign module.exports, { saveConfig, readConfig }
{ Actions } = require '../actions'
