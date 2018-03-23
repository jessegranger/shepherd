$ = require 'bling'
Http = require 'http'
{ echo } = require '../common'

$.extend module.exports, Health = {
	defaultPath: "/",
	defaultInterval: 10000,
	defaultStatus: 200,
	defaultText: "",
	defaultTimeout: 3000,
	monitor: (group, path, interval, status, text, timeout) ->
		path = String(path ? Health.defaultPath)
		unless path.length > 0 then return new Error("Invalid path: #{path}")

		interval = parseInt(interval ? Health.defaultInterval, 10)
		unless isFinite(interval) and not isNaN(interval) then return new Error("Invalid interval: #{interval}.")

		status = parseInt(status ? Health.defaultStatus, 10)
		unless isFinite(status) and not isNaN(status) then return new Error("Invalid status: #{status}.")

		text = String(text ? Health.defaultText)
		# if text.length > 0 then return new Error("Invalid text: #{text}.")

		timeout = parseInt(timeout ? Health.defaultTimeout)
		unless isFinite(timeout) and not isNaN(timeout) then return new Error("Invalid timeout: #{timeout}.")

		group.monitors or= Object.create null
		if path of group.monitors
			return new Error("Group is already monitored.")
		group.monitors[path] = $.interval interval, ->
			for proc in group when proc.expected then do (group, path, interval, status, text, timeout, proc) ->
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
		Object.assign group.monitors[path], { interval, status, text, timeout }
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
		buf = ""
		Groups.forEach (group) ->
			return unless group.monitors?
			for path, mon of group.monitors
				{ interval, status, text, timeout } = mon
				buf += "health --group #{group.name} --path \"#{path}\"" +
					(if status > 0 then " --status #{status}" else "") +
					(if interval > 0 then " --interval #{interval}" else "") +
					(if text.length > 0 then " --contains \"#{text}\"" else "") +
					(if timeout > 0 then " --timeout #{timeout}")
		buf

}
