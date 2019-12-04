$ = require 'bling'
Http = require 'http'
{ echo, verbose, quoted } = require '../common'
{ Groups } = require '../daemon/groups'

$.extend module.exports, Health = {
	defaultInterval: 10000,
	defaultTimeout: 3000,
	monitor: (group, path, exec, interval, status, text, timeout) ->
		if exec?
			unless exec.length > 0
				return new Error("Invalid exec command: #{exec}")
		else if path?
			unless path.length > 0
				return new Error("Invalid path: #{path}")
		else
			return new Error("Either path or exec is required.")
		verbose "Health.monitor", path, exec, interval, status, text, timeout

		interval = parseInt(interval ? Health.defaultInterval, 10)
		unless isFinite(interval) and not isNaN(interval) and (0 < interval < 4294967295)
			return new Error("Invalid interval: #{interval}.")

		if status?
			status = parseInt(status, 10)
			unless isFinite(status) and not isNaN(status) and (0 < status < 1000)
				return new Error("Invalid status: #{status}.")

		text = String(text ? '')

		timeout = parseInt(timeout ? Health.defaultTimeout, 10)
		unless isFinite(timeout) and not isNaN(timeout) and (0 < timeout < 4294967295)
			return new Error("Invalid timeout: #{timeout}.")

		monitorKey = (path ? exec)

		group.monitors or= Object.create null
		if monitorKey of group.monitors
			return new Error("Group is already monitored.")
		verbose "Adding health monitor", { path, interval, status, text, timeout }
		group.monitors[monitorKey] = $.interval interval, ->
			for proc in group when proc.expected then do (group, path, exec, interval, status, text, timeout, proc) ->
				countdown = null
				if proc.enabled and not proc.started
					proc.healthy = false
					return
				proc.healthy = undefined
				fail = (msg) ->
					clearTimeout countdown
					echo "Health check failed (#{msg}), pid: #{proc.proc?.pid} port: #{proc.port}"
					proc.healthy = false
					proc.proc?.kill()
				if timeout > 0
					countdown = setTimeout (=> fail 'timeout'), timeout
				if exec?
					res = Shell.exec exec, { silent: true, async: false }
					if status? and res.code isnt status
						fail("bad status: " + res.code)
					else if text? and not (res.stdout.indexOf(text) > -1)
						fail("bad text: " + res.stdout)
					else
						proc.healthy = true
				else if path?
					req = Http.get {
						host: "127.0.0.1"
						port: proc.port
						path: path
					}, (res) ->
						clearTimeout countdown
						if status isnt 0 and res.statusCode isnt status
							return fail("bad status: " + res.statusCode)
						if text.length > 0
							buffer = ""
							res.setEncoding 'utf8'
							res.on 'data', (data) -> buffer += data
							res.on 'end', ->
								unless buffer.indexOf(text) > -1
									fail("text not found: " + text)
						res.on 'error', (err) ->
							fail("response error: " + String(err))
						proc.healthy = true
					req.on 'error', (err) ->
						fail("request error: " + String(err))
		Object.assign group.monitors[monitorKey], { interval, status, text, timeout }
		return true
	unmonitor: (group, path) ->
		return false unless 'monitors' of group
		return false if path? and not (path of group.monitors)
		if path?
			group.monitors[path].cancel()
		else for path,check of group.monitors
			check.cancel()
			delete group.monitors[path]
		return true
	pause: (group, path) ->
		return false unless 'monitors' of group
		return false if path? and not (path of group.monitors)
		if path?
			group.monitors[path].pause()
			group.monitors[path].paused = true
		else
			check.pause() for path,check of group.monitors
		return true
	resume: (group, path) ->
		return false unless 'monitors' of group
		return false if path? and not (path of group.monitors)
		if path?
			group.monitors[path].resume()
			group.monitors[path].paused = false
		else
			check.resume() for path,check of group.monitors
		return true
	toConfig: ->
		items = []
		Groups.forEach (group) ->
			return unless group.monitors?
			for path, mon of group.monitors
				{ interval, status, text, timeout, paused } = mon
				items.push "health --group #{group.name} --path \"#{path}\"" +
					(if status > 0 then " --status #{status}" else "") +
					(if interval > 0 then " --interval #{Math.floor interval/1000}" else "") +
					(if text.length > 0 then " --contains #{quoted text}" else "") +
					(if timeout > 0 then " --timeout #{timeout}" else "") +
					(if paused then " --pause" else "")
		return items.join("\n")

}
