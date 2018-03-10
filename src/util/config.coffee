
$ = require 'bling'
Fs = require 'fs'
Nginx = require '../daemon/nginx'
{ Groups } = require '../daemon/groups'
{ Actions } = require '../actions'
{ configFile } = require '../files'
{ parseArguments } = require './parse-args'

echo = $.logger "[config]"

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
	buf += Nginx.toConfig() + "\n"
	buf += "start\n"
	Fs.writeFileSync configFile, buf
	true

readConfig = ->
	return if _reading
	_reading = true
	_err_text = ""
	try for line in String(Fs.readFileSync configFile).split("\n")
		continue if line[0] is '#'
		cmd = parseArguments(line)
		if (_cmd  = cmd._[0]) of Actions
			Actions[_cmd].onMessage \
				Actions[_cmd].toMessage(cmd)
	catch err
		_err_text = String(err)
	echo "Reading config...", configFile, _err_text
	_reading = false
	true

Object.assign module.exports, { saveConfig, readConfig }
