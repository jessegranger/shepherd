$ = require 'bling'
$.log.enableTimestamps()

{ parseArgv } = require './util/parse-args'
cmd = process.cmdv ?= parseArgv()

verboseMode = !!(cmd.verbose or cmd.v)
setVerbose = (v) -> echo "Setting verbose mode:", verboseMode = !!v

echo = (msg...) -> $.log "shep-#{process.pid}", msg...
warn = (msg...) -> $.log "shep-#{process.pid} [warn]", msg...; return false
verbose = (msg...) -> verboseMode and $.log "shep-#{process.pid} [verbose]", msg...
quoted = (s) -> '"' + s.replace(/"/g,'\\"') + '"'
exit_soon = (code=0, ms=100) => setTimeout (=> process.exit code), ms
required = (msg, key, label) ->
	unless msg
		return warn "msg is required."
	unless msg[key] and msg[key].length
		return warn "#{label} is required."
	true

echoResponse = (resp, socket) -> echo resp

Object.assign module.exports, { $, cmd, echo, warn, verbose, exit_soon,
	required, echoResponse, quoted, setVerbose }
