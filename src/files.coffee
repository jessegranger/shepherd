{ $, cmd, echo, warn, verbose } = require './common'
Fs = require 'fs'
ChildProcess = require 'child_process'

expandPath = (s) => s?.replace(/^~/, process.env.HOME).replace(/^%/, basePath)

exists = (p) =>
	try
		p = expandPath p
		return false unless p?
		Fs.accessSync(p, Fs.constants.R_OK)
		return true
	return false

seekForBasePath = =>
	paths = $(process.cwd().split '/')
	while paths.length > 0
		path = paths.join('/') + '/.shep'
		if exists path
			return path
		paths.pop()
	null

if "SHEPHERD_HOME" of process.env
	basePath = process.env.SHEPHERD_HOME
else
	if cmd.base?
		basePath = cmd.base + "/.shep"
	else
		basePath = seekForBasePath()
exists(basePath) and verbose "Using", basePath

createBasePath = (prefix, cb) =>
	ChildProcess.spawn("mkdir -p \"#{prefix}/.shep\"", { shell: true }).on 'exit', (code, signal) =>
		cb if code is 0 then null else new Error "mkdir failed: code #{code}"

makePath = (parts...) =>
	unless basePath? then undefined
	else
		ret = [basePath].concat(parts).join("/").replace(/\/\//g,'/')
		if ret.indexOf(process.env.HOME) is 0
			ret = ret.replace(process.env.HOME, '~')
		else if ret.indexOf(basePath) is 0
			ret = ret.replace(basePath, '%')
		ret

readPid = ->
	try parseInt Fs.readFileSync(expandPath module.exports.pidFile).toString(), 10
	catch then undefined

carefulUnlink = (path, cb) ->
	path = expandPath path
	echo "Unlinking file:", path
	try Fs.unlink path, cb
	catch err then cb(err)

Object.assign module.exports, {
	createBasePath,
	exists,
	makePath,
	basePath,
	expandPath,
	readPid,
	carefulUnlink,
	exists: exists
	pidFile: makePath "pid"
	socketFile: makePath "socket"
	configFile: makePath "config"
	nginxFile: makePath "nginx"
	nginxTemplate: makePath "nginx.template"
	outputFile: makePath "log"
}
