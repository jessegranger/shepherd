
{ $, echo, warn, verbose } = require '../common'
Fs = require 'fs'
Files = require '../files'
{ Groups } = require './groups'
Handlebars = require 'handlebars'
ChildProcess = require 'child_process'
{ expandPath } = Files

defaults = {
	reload: reload = "service nginx reload"
	server_name: server_name = null
	server_port: server_port = 80
	disabled: disabled = true
	template:  Files.nginxTemplate = "%/nginx.template"
	templateText: """
		upstream {{ name }} {
		{{#each group}}
		{{#if this.port}}
			server 127.0.0.1:{{ this.port }} {{#unless this.started}}down{{/unless}};
		{{/if}}
		{{/each}}
		}
		server {
			listen [::]:{{ public_port }};
			server_name {{ public_name }};
			location / {
				proxy_pass http://{{ name }};
			}
		}
		{{#if ssl_cert}}
		server {
			listen [::]:443;
			server_name {{ public_name }};
			ssl on;
			ssl_certificate {{ ssl_cert }};
			ssl_certificate_key {{ ssl_key }};
			location / {
				proxy_pass http://{{ name }};
			}
		}
		{{/if}}
	"""
}

setReload = (r) -> reload = r
setTemplate = (f) -> Files.nginxTemplate = f
setFile = (f) -> Files.nginxFile = f.replace(/^~/, process.env.HOME).replace(/^%/, Files.basePath)
setDisabled = (d) -> disabled = d

generate = (t)=>
	buf = ""
	return "no template" unless t?
	Groups.forEach (group) =>
		if group.public_port? and group.public_name?
			buf += t {
				group: group,
				public_name: group.public_name
				public_port: group.public_port
				ssl_cert: group.ssl_cert
				ssl_key: group.ssl_key
				name: group.name
			}
	buf

nop = ->
writeNginxFile = (cb) =>
	cb or= nop
	return cb('disabled', false) if disabled
	echo "Saving nginx file: #{expandPath Files.nginxFile}..."
	start = Date.now()
	inputFile = expandPath Files.nginxTemplate
	verbose "Reading nginx template...", inputFile
	Fs.readFile inputFile, (err, data) ->
		if err
			warn "Failed to read nginx template:", inputFile, err
			return cb(err, false)
		text = generate Handlebars.compile data.toString('utf8')
		outputFile = expandPath Files.nginxFile
		verbose "Writing nginx file...", outputFile
		Fs.writeFile outputFile, text, (err) ->
			verbose "writeNginxFile took #{Date.now() - start} ms"
			cb(err, true)
		null
	null

toConfig = =>
	_reload = if reload is defaults.reload then "" else " --reload-cmd '#{reload}'"
	_file = if Files.nginxFile is Files.makePath("nginx") then "" else " --file '#{Files.nginxFile}'"
	_template = if Files.nginxTemplate is defaults.template then "" else " --template '#{Files.nginxTemplate}'"
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

_callbacks = []
_deferTimeout = null
# like a debounce, but we save all the callback that _dont_ get fired
defer = (ms, cb, f) =>
	_callbacks.push cb
	clearTimeout _deferTimeout
	_deferTimeout = setTimeout (=>
		while _callbacks.length > 1
			_callbacks.pop()(null, false)
		if _callbacks.length > 0
			f(_callbacks.pop())
	), ms
	null

reloadNginx = (cb) =>
	cb or= nop
	return cb(null, false) if disabled
	defer 500, cb, (_cb) =>
		lastReload = $.now
		echo "Reloading nginx with command:", reload
		p = ChildProcess.exec reload, shell: true
		p.stdout.on 'data', (data) -> echo "#{reload} (stdout)", data.toString("utf8")
		p.stderr.on 'data', (data) -> echo "#{reload} (stderr)", data.toString("utf8")
		_cb null, true
	null

sync = (cb) =>
	cb or= nop
	return cb('disabled', false) if disabled
	defer 500, cb, (_cb) =>
		_cb or= nop
		writeNginxFile (err, acted) =>
			return _cb(err, false) if err
			if acted then reloadNginx _cb
			else _cb(null, false)

Object.assign module.exports, { writeNginxFile, reloadNginx, setReload, setTemplate, setFile, setDisabled, toConfig, sync, defaults }
