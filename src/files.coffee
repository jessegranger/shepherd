{ $, echo, warn, verbose } = require './common'
Fs = require 'fs'
ChildProcess = require 'child_process'
{ parseArgv } = require './util/parse-args'
process.cmdv ?= parseArgv()

dirExists = (p) =>
	try
		Fs.accessSync(p, Fs.constants.R_OK)
		return true
	return false

seekForBasePath = =>
	paths = $(process.cwd().split '/')
	while paths.length > 0
		path = paths.join('/') + '/.shepherd'
		if dirExists path
			return path
		paths.pop()

if "SHEPHERD_HOME" of process.env
	basePath = process.env.SHEPHERD_HOME
else
	cmd = process.cmdv
	if cmd.path?
		basePath = cmd.path + "/.shepherd"
	else
		basePath = seekForBasePath()
dirExists(basePath) and verbose "Using", basePath

createBasePath = (prefix, cb) =>
	return ChildProcess.spawn("mkdir -p \"#{prefix}/.shepherd\"", { shell: true }).on 'exit', =>
		echo "Created .shepherd folder..."
		cb()

makePath = (parts...) =>
	unless basePath? then undefined
	else [basePath].concat(parts).join("/").replace(/\/\//g,'/')

Object.assign module.exports, {
	createBasePath,
	dirExists,
	makePath,
	basePath,
	exists: dirExists
	pidFile: makePath "pid"
	socketFile: makePath "socket"
	configFile: makePath "config"
	nginxFile: makePath "nginx"
	outputFile: makePath "log"
}
