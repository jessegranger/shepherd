
$ = require 'bling'
$.log.enableTimestamps()

{ parseArgv } = require './util/parse-args'
cmd = process.cmdv ?= parseArgv()

echo = (msg...) -> cmd.quiet or $.log "[shep-#{process.pid}]", msg...
warn = (msg...) -> $.log "[shep-#{process.pid}] Warning:", msg...; return false
verbose = (msg...) -> cmd.verbose and $.log "[shep-#{process.pid}]", msg...
exit_soon = (code=0, ms=100) => setTimeout (=> process.exit code), ms

Object.assign module.exports, { $, cmd, echo, warn, verbose, exit_soon }
