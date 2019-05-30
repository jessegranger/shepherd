{ $, echo, warn, verbose } = require '../common'
Fs = require 'fs'
Nginx = require '../daemon/nginx'
{ Groups } = require '../daemon/groups'
{ int, trueFalse } = require '../util/format'
{ saveConfig } = require '../util/config'
{ configFile, exists, nginxTemplate, expandPath } = require "../files"

Object.assign module.exports, {
	options: [
		[ "--enable", "Generate a config file and automatically reload nginx when state changes." ]
		[ "--disable", "Don't generate files or reload nginx." ]
		[ "--file <file>", "Auto-generate an nginx file here using '.shep/nginx.template'."]
		[ "--reload-cmd <cmd>", "What command to run in order to cause nginx to reload."]
		[ "--reload-now", "Read nginx.template, write a fresh config file, and issue the reload cmd to nginx." ]

		[ "--group <name>", "Optional. If given, the following options apply:" ]
		[ "  --port <n>", "Default 80 (or 443). 'server { listen <n>; }'", int ]
		[ "  --name <hostname>", "Default is the group name. 'server { server_name <name>; }'" ]
		[ "  --ssl_cert <path>", "Optional. If given, port defaults to 443." ]
		[ "  --ssl_key <path>", "Optional. If given, port defaults to 443." ]

		[ "--list", "Show the current nginx configuration." ]

	]
	toMessage: (cmd) -> {
		c: 'nginx'
		f: cmd.file
		r: cmd['reload-cmd']
		k: cmd.keepalive
		d: (trueFalse cmd.disable)
		e: (trueFalse cmd.enable)
		l: cmd.list
		g: cmd.group
		p: cmd.port
		n: cmd.name
		sc: cmd.ssl_cert
		sk: cmd.ssl_key
		rn: (trueFalse cmd['reload-now'])
	}
	onMessage: (msg, client, cb) ->
		reply = (m, ret) ->
			if ret
				client?.write $.TNET.stringify m
				saveConfig?()
				Nginx.reloadNginx()
			cb? (not ret and m or null), ret
			ret

		if msg.rn
			Nginx.sync()
			return reply "writing nginx config", true

		if msg.g?
			acted = false
			if not Groups.has(msg.g)
				return reply "No such group.", false
			group = Groups.get(msg.g)
			if msg.p?
				acted = true
				group.public_port = int msg.p
			if msg.n?
				acted = true
				group.public_name = msg.n
			if msg.sc?
				acted = true
				unless exists(msg.sc)
					warn "ssl_cert file '#{msg.sc}' does not exist.", false
				group.ssl_cert = msg.sc
			if msg.sk?
				acted = true
				unless exists(msg.sk)
					warn "ssl_key file '#{msg.sk}' does not exist.", false
				group.ssl_key = msg.sk
			if acted
				return reply "Group updated.", true
			else
				return reply "No valid options specified.", false

		if msg.l?
			return reply Nginx.toConfig(), false

		acted = 0
		if msg.f?.length then ++acted and Nginx.setFile(msg.f)
		if msg.r?.length then ++acted and Nginx.setReload(msg.r)
		if msg.e
			++acted and Nginx.setDisabled false
			if not exists(nginxTemplate)
				bytes = Nginx.defaults.templateText
				Fs.writeFile expandPath(nginxTemplate), bytes, (err, written) =>
					if err then warn err
					else if written isnt bytes.length
						warn "Only wrote #{written} out of #{bytes.length} to #{nginxTemplate}"
					else echo "Wrote default content to #{nginxTemplate}"
		if msg.d then ++acted and Nginx.setDisabled true
		if acted
			saveConfig?()
			return reply "nginx configuration updated.", true
		else
			return reply "nginx - no actions requested.", false
	onResponse: (resp, socket) -> console.log resp; socket.end()
}
