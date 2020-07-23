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
die = (msg, code=1) -> echo msg; process.exit(code)
die_soon = (msg, code=1, ms=100) -> echo msg; exit_soon(code, ms)
required = (msg, key, label) -> switch true
	when (not msg?) then warn "msg is required."
	when not msg[key] and msg[key].length then warn "#{label} is required."
	else true

echoResponse = (resp, socket) -> echo resp

Object.assign module.exports, { $, cmd, echo, warn, verbose, exit_soon, die, die_soon,
	required, echoResponse, quoted, setVerbose }
