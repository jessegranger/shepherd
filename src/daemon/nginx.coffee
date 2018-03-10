
$ = require 'bling'
Fs = require 'fs'
Files = require '../files'
{ Groups } = require './groups'
Handlebars = require 'handlebars'
ChildProcess = require 'child_process'

echo = $.logger "[shepd-#{process.pid}]"

template = Handlebars.compile """
upstream {{ name }} {
{{#each group}}
{{#if this.port}}
	server 127.0.0.1:{{ this.port }} {{#if this.enabled}}weight=1{{else}}weight=0{{/if}} {{#unless this.started}}down{{/unless}};
{{/if}}
{{/each}}
	keepalive {{ keepalive }};
}

"""
reload = "service nginx reload"
keepalive = 32
disabled = true

setReload = (r) -> reload = r
setTemplate = (t) -> template = Handlebars.compile(t)
setFile = (f) -> Files.nginxFile = f.replace(/^~/, process.env.HOME)
setDisabled = (d) -> disabled = d
setKeepAlive = (sec) -> keepalive = sec

generate = =>
	buf = ""
	Groups.forEach (group) =>
		if group.length > 0 and group[0].port
			buf += template { group, keepalive, name: group.name }
	buf

writeNginxFile = (cb) =>
	return cb?() if disabled
	# echo "Saving nginx file...", Files.nginxFile
	text = generate()
	Fs.writeFile Files.nginxFile, text, ->
		cb?()

toConfig = =>
	"nginx --file '#{Files.nginxFile}' --reload \"#{reload}\" --keepalive #{keepalive}#{if disabled then " --disable" else ""}"

willCall = null

reloadNginx = (cb) =>
	return cb?() if disabled
	clearTimeout willCall
	willCall = setTimeout (=>
		echo "Reloading nginx..."
		p = ChildProcess.exec(reload, { shell: true })
		p.stdout.on 'data', (data) -> $.log "#{reload}", data.toString("utf8")
		p.stderr.on 'data', (data) -> $.log "#{reload}", data.toString("utf8")
	), 2000
	cb?()

sync = (cb) =>
	writeNginxFile => reloadNginx cb

Object.assign module.exports, { writeNginxFile, reloadNginx, setReload, setTemplate, setFile, setDisabled, setKeepAlive, toConfig, sync }

