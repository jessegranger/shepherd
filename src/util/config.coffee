
$ = require 'bling'
Fs = require 'fs'
{ Groups } = require "../daemon/groups"
{ Actions } = require "../actions"
{ configFile } = require "../files"
parseArguments = require "minimist-string"


_reading = false

saveConfig = ->
	return if _reading
	$.log "Saving config..."
	buf = ""
	Groups.forEach (group) ->
		buf += Actions.add.toConfig(group) + "\n"
	buf += "start\n"
	Fs.writeFileSync configFile, buf
	true

readConfig = ->
	_reading = true
	for line in String(Fs.readFileSync configFile).split("\n")
		cmd = parseArguments(line)
		if (_cmd  = cmd._[0]) of Actions
			Actions[_cmd].onMessage \
				Actions[_cmd].toMessage(cmd)
	_reading = false
	true

Object.assign module.exports, { saveConfig, readConfig }
