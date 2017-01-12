require './output'
$ = require 'bling'
Http = require 'http'
echo = $.logger "[health]"

$.extend module.exports, {
	monitor: (group, path, interval, status, text, timeout) ->
		group.monitors or= Object.create null
		return false if path of group.monitors
		group.monitors[path] = $.interval interval, ->
			for proc in group.procs when proc.expected then do (group, path, interval, status, text, timeout, proc) ->
				if proc.enabled and not proc.started
					proc.healthy = false
					return
				proc.healthy = undefined
				fail = (msg) ->
					countdown?.cancel()
					echo "Health check failed (#{msg}), pid: #{proc.proc?.pid} port: #{proc.port}"
					proc.healthy = false
					proc.proc?.kill()
				if timeout
					countdown = $.delay timeout, $.partial fail, "timeout"
				req = Http.get {
					host: "localhost"
					port: proc.port
					path: path
				}, (res) ->
					countdown?.cancel()
					proc.healthy = true
					if status and res.statusCode isnt status
						fail("bad status: " + res.statusCode)
					if text
						buffer = ""
						res.setEncoding 'utf8'
						res.on 'data', (data) -> buffer += data
						res.on 'end', ->
							unless buffer.indexOf(text) > -1
								fail("text not found: " + text)
					res.on 'error', (err) ->
						fail("response error: " + String(err))
				req.on 'error', (err) ->
					fail("request error: " + String(err))
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
		else
			check.pause() for path,check of group.monitors
		return true
	resume: (group, path) ->
		return false unless 'monitors' of group
		return false if path? and not (path of group.monitors)
		if path?
			group.monitors[path].resume()
		else
			check.resume() for path,check of group.monitors
		return true
}
