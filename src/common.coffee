$ = require 'bling'
$.log.enableTimestamps()

{ parseArgv } = require './util/parse-args'
cmd = process.cmdv ?= parseArgv()

echo = (msg...) -> cmd.quiet or $.log "[shep-#{process.pid}]", msg...
warn = (msg...) -> $.log "[shep-#{process.pid}] Warning:", msg...; return false
verbose = (msg...) -> cmd.verbose and $.log "[shep-#{process.pid}]", msg...
exit_soon = (code=0, ms=100) => setTimeout (=> process.exit code), ms
required = (msg, key, label) ->
	unless msg
		return warn "msg is required."
	unless msg[key] and msg[key].length
		return warn "#{label} is required."
	true
echoResponse = (resp, socket) -> console.log resp; socket.end()

Object.assign module.exports, { $, cmd, echo, warn, verbose, exit_soon, required, echoResponse }
