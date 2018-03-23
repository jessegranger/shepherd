{ $, cmd, echo, warn, verbose } = require './common'
Fs = require 'fs'
ChildProcess = require 'child_process'

expandPath = (s) => s.replace(/^~/, process.env.HOME).replace(/^%/, basePath)

exists = (p) =>
	try
		Fs.accessSync(expandPath p, Fs.constants.R_OK)
		return true
	return false

seekForBasePath = =>
	paths = $(process.cwd().split '/')
	while paths.length > 0
		path = paths.join('/') + '/.shepherd'
		if exists path
			return path
		paths.pop()

if "SHEPHERD_HOME" of process.env
	basePath = process.env.SHEPHERD_HOME
else
	if cmd.base?
		basePath = cmd.base + "/.shepherd"
	else
		basePath = seekForBasePath()
exists(basePath) and verbose "Using", basePath

createBasePath = (prefix, cb) =>
	return ChildProcess.spawn("mkdir -p \"#{prefix}/.shepherd\"", { shell: true }).on 'exit', =>
		echo "Created .shepherd folder..."
		cb()

makePath = (parts...) =>
	unless basePath? then undefined
	else
		ret = [basePath].concat(parts).join("/").replace(/\/\//g,'/')
		if ret.indexOf(process.env.HOME) is 0
			ret = ret.replace(process.env.HOME, '~')
		else if ret.indexOf(basePath) is 0
			ret = ret.replace(basePath, '%')
		ret


Object.assign module.exports, {
	createBasePath,
	exists,
	makePath,
	basePath,
	expandPath,
	exists: exists
	pidFile: makePath "pid"
	socketFile: makePath "socket"
	configFile: makePath "config"
	nginxFile: makePath "nginx"
	nginxTemplate: makePath "nginx.template"
	outputFile: makePath "log"
}
