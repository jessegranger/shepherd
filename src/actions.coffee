{ $, echo, warn, verbose, required, echoResponse } = require './common'
Fs = require 'fs'
Tnet = require './util/tnet'
SlimProcess = require './util/process-slim'
ChildProcess = require 'child_process'
int = (n) -> parseInt((n ? 0), 10)
{ yesNo, trueFalse } = require "./format"
{ configFile, exists, nginxTemplate, expandPath } = require "./files"

{ Groups, removeGroup, simpleAction } = require "./daemon/groups"

Object.assign module.exports, { Actions: {
	add:     require './actions/add'
	remove:  require './actions/remove'
	replace: require './actions/replace'
	start:   require './actions/start'
	stop:    require './actions/stop'
	restart: r=require './actions/restart'
	reload:  r,
	status:  s=require "./actions/status"
	stats:   s
	stat:    s
	disable: require './actions/disable'
	enable:  require './actions/enable'
	scale:   require './actions/scale'
	log:     require './actions/log'
	health:  require './actions/health'
	nginx:   require './actions/nginx'
	config:  require './actions/config'
}}
