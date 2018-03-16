
$ = require 'bling'
$.log.enableTimestamps()

{ parseArgv } = require './util/parse-args'
cmd = process.cmdv ?= parseArgv()

echo = (msg...) -> cmd.quiet or $.log "[shepherd-#{process.pid}]", msg...
warn = (msg...) -> $.log "[shepherd-#{process.pid}] Warning:", msg...; return false
verbose = (msg...) -> cmd.verbose and $.log "[shepherd-#{process.pid}]", msg...

Object.assign module.exports, { $, cmd, echo, warn, verbose }
