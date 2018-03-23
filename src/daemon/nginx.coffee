
{ $, echo, warn, verbose } = require '../common'
Fs = require 'fs'
Files = require '../files'
{ Groups } = require './groups'
Handlebars = require 'handlebars'
ChildProcess = require 'child_process'

defaults = {
	reload: reload = "service nginx reload"
	server_name: server_name = null
	server_port: server_port = 80
	disabled: disabled = true
	template:  template = "%/nginx.template"
}

setReload = (r) -> reload = r
setTemplate = (f) -> template = f
setFile = (f) -> Files.nginxFile = f.replace(/^~/, process.env.HOME).replace(/^%/, Files.basePath)
setDisabled = (d) -> disabled = d

generate = (t)=>
	buf = ""
	return "no template" unless t?
	Groups.forEach (group) =>
		if group.port?
			buf += t {
				group: group,
				public_name: group.public_name ? group.name
				public_port: group.public_port ? 80
				ssl_cert: group.ssl_cert
				ssl_key: group.ssl_key
				name: group.name
			}
	buf

writeNginxFile = (cb) =>
	return cb?(null, false) if disabled
	verbose "Reading nginx template...", template
	Fs.readFile template.replace(/^%/, Files.basePath), (err, data) ->
		if err
			warn "Failed to read nginx template:", err
			return cb?(null, false)
		t = Handlebars.compile data.toString('utf8')
		text = generate(t)
		verbose "Saving nginx file...", Files.nginxFile
		Fs.writeFile Files.nginxFile, text, (err) ->
			cb?(err, not err?)
		null
	null

toConfig = =>
	_reload = if reload is defaults.reload then "" else " --reload '#{reload}'"
	_file = if Files.nginxFile is Files.makePath("nginx") then "" else " --file '#{Files.nginxFile}'"
	_template = if template is defaults.template then "" else " --template '#{template}'"
	_disabled = if disabled then " --disable" else " --enable"
	buf = "nginx#{_disabled}#{_reload}#{_file}#{_template}"
	Groups.forEach (group) =>
		if group.public_name? or group.public_port? or group.ssl_cert? or group.ssl_key?
			buf += ("\nnginx --group #{group.name}" +
				(if group.public_name then " --name #{group.public_name}" else "") +
				(if group.public_port then " --port #{group.public_port}" else "") +
				(if group.ssl_cert then " --ssl_cert #{group.ssl_cert}" else "") +
				(if group.ssl_key then " --ssl_key #{group.ssl_key}" else ""))
	buf

willCall = null

reloadNginx = (cb) =>
	return cb?(null, false) if disabled
	clearTimeout willCall
	willCall = setTimeout (=>
		echo "Reloading nginx..."
		p = ChildProcess.exec(reload, { shell: true })
		p.stdout.on 'data', (data) -> $.log "#{reload}", data.toString("utf8")
		p.stderr.on 'data', (data) -> $.log "#{reload} (stderr)", data.toString("utf8")
	), 2000
	cb?(null, false)

sync = (cb) =>
	writeNginxFile (err, acted) =>
		return cb?(err, acted) if err or not acted
		reloadNginx cb

Object.assign module.exports, { writeNginxFile, reloadNginx, setReload, setTemplate, setFile, setDisabled, toConfig, sync }

