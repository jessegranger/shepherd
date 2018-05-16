
$ = require 'bling'
$.log.enableTimestamps()

{ parseArgv } = require './util/parse-args'
cmd = process.cmdv ?= parseArgv()

echo = (msg...) -> cmd.quiet or $.log "[shepherd-#{process.pid}]", msg...
warn = (msg...) -> $.log "[shepherd-#{process.pid}] Warning:", msg...; return false
verbose = (msg...) -> cmd.verbose and $.log "[shepherd-#{process.pid}]", msg...
exit_soon = (code=0, ms=100) => setTimeout (=> process.exit code), ms

Object.assign module.exports, { $, cmd, echo, warn, verbose, exit_soon }
