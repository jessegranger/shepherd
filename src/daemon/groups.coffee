
{ $, echo, warn, verbose } = require '../common'
Path = require 'path'
Nginx = null # placeholder for out of order import
saveConfig = null
ChildProcess = require 'child_process'
SlimProcess = require '../util/process-slim'
{ exists } = require '../files'
{ quoted } = require '../common'

# the global herd of processes
Groups = new Map()
# m.clear m.delete m.entries m.forEach m.get m.has m.keys m.set m.size m.values

`const DEFAULT_GRACE = 9000;`


class Group extends Array
	createProcess = (g, i) ->
		port = undefined
		if g.port
			port = parseInt(g.port) + i
		new Proc "#{g.name}-#{i}", g.cd, g.exec, port, g
	constructor: (@name, @cd, @exec, @n, @port, @grace=DEFAULT_GRACE) ->
		super()
		for i in [0...@n] by 1
			@push createProcess @, i
		@monitors = Object.create null # used later by health checks
		@enabled = true
		# @public_port, @public_name, @ssl_cert, and @ssl_key can all be set here from src/daemon/nginx
	enable: (cb) ->
		acted = not @enabled
		@enabled = true
		if acted then @actOnAll 'enable', cb
		else cb?()
	disable: (cb) ->
		acted = @enabled
		@enabled = false
		if acted then @actOnAll 'disable', cb
		else cb?()
	scale: (n, cb) ->
		unless (isFinite(n) and not isNaN(n) and n >= 0)
			echo "[scale] Count must be a number >= 0."
			return false
		dn = n - @n
		progress = $.Progress dn
		progress.then => saveConfig cb
		if dn > 0
			echo "[scale(#{n})] Adding #{dn} instances..."
			for d in [0...dn] by 1
				p = createProcess @, @n++
				if @enabled
					p.start => progress.finish 1
				else
					p.disable => progress.finish 1
				@push p
		else if dn < 0
			echo "[scale(#{n})] Trimming #{dn} instances..."
			while @n > n
				@pop().stop => progress.finish 1
				@n -= 1
		else return false
		true
	restart: (cb) -> # Slowly kill and restart one at a time
		do oneStep = (i=0) =>
			return cb?() unless i < @length
			@[i].restart => oneStep(i+1)
		true
	start: (cb) ->
		do oneStep = (i=0) =>
			return cb?(null, true) unless i < @length
			@[i].start => oneStep(i+1)
		true
	stop: (cb) ->
		for proc in @
			proc.expected = false
		for proc in @
			proc.stop()
		cb?(null, true)
	markAsInvalid: (reason) ->
		for proc in @
			proc.markAsInvalid reason
		@
	actOnAll: (method, cb) ->
		progress = $.Progress(@length)
		progress.wait (err) => cb(err, true)
		for x in @
			x[method] => progress.finish 1
		return progress
	toString: ->
		"[group #{@name}] " + ("#{if proc.port then "(#{proc.port}) " else ""}#{proc.statusString}" for proc,i in @).join ", "
	toConfig: ->
		"add --group #{@name}" +
			(if @cd isnt "." then " --cd #{quoted @cd}" else "") +
			" --exec #{quoted @exec} --count #{@n}" +
			(if @grace isnt DEFAULT_GRACE then " --grace #{@grace}" else "") +
			(if @port then " --port #{@port}" else "")

class Proc
	Proc.cooldown = 200
	constructor: (@id, @cd, @exec, @port, @group) ->
		# the time of the most recent start
		@started = false
		@enabled = true
		@healthy = undefined # used later by health checks
		@cooldown = Proc.cooldown# this increases after each failed restart
		@expected = false # should we restart this proc if it exits
		# expose uptime
		$.defineProperty @, 'uptime', {
			get: => if @started then ($.now - @started) else 0
		}
		statusString = "unstarted"
		$.defineProperty @, 'statusString', {
			get: => statusString
			set: (v) =>
				oldValue = statusString
				statusString = v
				# @log oldValue + " -> " + v
				$.log @group.toString()
		}
	
	log: (args...) ->
		$.log "[#{@id}]", args...

	# Start this process if it isn't already.
	start: (cb) -> # cb called with a 'started' flag that indicates if any work was done
		done = (err, ret) => cb?(err, ret); ret
		if @started or not @enabled
			@started and verbose "#{@id} already started, skipping."
			@enabled or verbose "#{@id} not enabled, skipping."
			return done(null, false)
		@expected = true
		env = Object.assign {}, process.env, { PORT: @port }
		clearPort = (cb) =>
			unless @expected and @enabled
				verbose "#{@id} giving up on clearPort", { @expected, @enabled }
				return done(null, false) # stopped while waiting
			if @port then SlimProcess.getPortOwner @port, (err, owner) =>
				return cb() unless owner
				invalidPort = =>
					return done @markAsInvalid "invalid port"
				if owner.uid isnt process.getuid()
					return invalidPort()
				SlimProcess.getProcessTable (err, procs) =>
					SlimProcess.visitProcessTree process.pid, (proc) =>
						invalidPort() if proc.pid is owner.pid
						null
					if @statusString isnt "invalid port"
						@statusString = "killing #{owner.pid}"
						try process.kill owner.pid, 'SIGTERM'
						setTimeout (=> clearPort cb), 1000
			else cb?()
		retryStart = =>
			return done(null, false) if @started or not @enabled
			@cooldown = (Math.min 30000, @cooldown * 2)
			@statusString = "waiting #{@cooldown}"
			setTimeout doStart, @cooldown
			return true
		do doStart = =>
			if @started or not @expected
				verbose "#{@id} giving up on doStart because", @expected, @enabled
				return done(null, false)
			clearPort (err) =>
				if err or not @expected
					verbose "Giving up after clearPort because", err, @expected
					return done(null, false)
				checkStarted = null
				@statusString = "starting"
				try
					@cd = Path.resolve(process.cwd(), @cd)
					verbose "cd:", @cd
				catch err # it's actually possible for node's internals to throw an exception here if cwd() is weird
					@markAsInvalid err.message
					return done(err, false)
				verbose "exec:", @exec, "as", @id
				opts = { shell: true, cwd: @cd, env: env }
				if not exists(@cd)
					return @stop => @group.markAsInvalid "invalid dir"
				@proc = ChildProcess.spawn @exec, opts
				@expected = true # tell the 'exit' handler to bring us back up if we die
				finishStarting = =>
					@started = $.now
					@cooldown = Proc.cooldown
					@statusString = "started"
					if @port
						Nginx.sync => done(true)
					else
						done(true)
				if @port
					_s = Date.now()
					checkStarted = setTimeout (=>
						return done(null, false) unless @proc? and @expected
						unless @proc?.pid?
							@markAsInvalid "exec failed"
							return done(null, false)
						echo "Waiting for port #{@port} to be owned by #{@proc.pid} (will wait #{@group.grace} ms)"
						SlimProcess.waitForPortOwner @proc, @port, @group.grace, (err, owner) =>
							unless @expected and @enabled # stopped while waiting?
								echo "#{@id} giving up after waiting for port because", @expected, @enabled
								return @stop => done(null, false)
							switch err
								when 'exit'
									warn "#{@id} exited immediately, will not retry."
									@proc = null
									return @stop => @disable =>
										@markAsInvalid "failed"
										done(null, false)
								when 'timeout'
									echo "#{@id} did not listen on port #{@port} within the timeout: #{@group.grace}ms"
									return @stop => done(null, false)
								else
									if err?
										echo "Failed to find port owner,", err, "after", (Date.now() - _s) + "ms"
										return @stop retryStart
							finishStarting()
					), 50
				else # if there is no port to wait for then staying up for a few seconds counts as started
					checkStarted = setTimeout finishStarting, @group.grace
				
				# Connect the process output to our log writer.
				@proc.stdout.on 'data', (data) => @log data.toString("utf8")
				@proc.stderr.on 'data', (data) => @log "(stderr)", data.toString("utf8")
				@proc.on 'exit', (code, signal) =>
					clearTimeout checkStarted
					@started = false
					if @proc?.pid then try @proc?.unref?()
					@proc = undefined
					if @expected is false # it went down and we dont care
						@statusString = "exit(#{code})" # just report it
					else if @statusString is "starting" # it went down right after launch
						echo "#{@id} exited immediately, will not retry."
						@disable => @statusString = "failed" # mark it as failed
					else # it should be up, but went down
						echo "#{@id} Unexpected exit, restarting..."
						return retryStart()
					return true

	stop: (cb) ->
		@statusString = "stopping"
		@expected = false
		if @proc?.pid > 1
			@proc.on 'exit', =>
				@started = false
				@statusString = if @enabled then "stopped" else "disabled"
				if @port
					Nginx.sync => cb? null, true
				else
					cb? null, true
			try process.kill @proc.pid
			return true
		@started = false
		@proc = null
		@statusString = if @enabled then "stopped" else "disabled"
		cb? null, false
		return false

	restart: (cb) ->
		@statusString = "restarting"
		@stop => @start cb

	enable: (cb) ->
		acted = not @enabled
		@enabled = true
		if acted then @start cb
		else cb?()
		acted
	
	markAsInvalid: (reason) ->
		@enabled = @expected = @started = @healthy = false
		@statusString = reason
		false

	disable: (cb) ->
		acted = @started or @enabled
		@enabled = false
		_end = => @statusString = "disabled"; cb?()
		if @started then @stop _end
		else _end()
		acted

actOnInstance = (method, instanceId, cb) ->
	return false unless instanceId?.length
	acted = false
	chunks = instanceId.split '-'
	index = chunks[chunks.length - 1]
	groupId = chunks.slice(0, chunks.length - 1).join('-')
	index = parseInt index, 10
	proc = Groups.get(groupId)?[index]
	if (not proc) or not (method of proc)
		return cb?('invalid method')
	proc[method] (ret) =>
		afterAction method, ret, cb
	false

actOnGroup = (method, groupId, cb) ->
	group = Groups.get(groupId)
	if (not group)
		return cb?('No such group.')
	if (method of group)
		group[method] (ret) =>
			afterAction method, ret, cb
	else
		group.actOnAll method, (ret) =>
			afterAction method, ret, cb
	false

actOnAll = (method, cb) ->
	acted = false
	progress = $.Progress(Groups.size + 1) \
		.then => afterAction method, acted, cb
	finishOne = (ret) =>
		acted = ret or acted
		progress.finish 1
	Groups.forEach (group) ->
		if 'function' is typeof group[method]
			group[method] finishOne
		else for proc in group
			proc[method]? finishOne
	progress.finish 1

addGroup = (name, cd=".", exec, count=1, port, grace=DEFAULT_GRACE, cb) ->
	if Groups.has(name)
		warn "Group already exists. Did you mean 'replace'?"
		return false
	echo "Adding group:", name
	verbose { cd, exec, count, port, grace }
	Groups.set name, new Group(name, cd, exec, count, port, grace)
	return afterAction 'add', true, cb

removeGroup = (name, cb) ->
	unless Groups.has(name)
		echo "No such group:", name
		return false
	echo "Removing group:", name
	g = Groups.get(name)
	done = $.Progress(g.length).then =>
		Groups.delete name
		return afterAction 'remove', true, cb
	for proc in g
		proc.stop => done.finish 1
	return true

afterAction = (method, ret, cb) ->
	if method in ['enable', 'disable', 'add', 'remove', 'replace']
		saveConfig (err, acted) => cb?(err, ret)
	else cb?(null, ret)

simpleAction = (method) -> (msg, client, cb) ->
	_line = ''
	targetText =
		if msg.g then "group #{msg.g}"
		else if msg.i then "instance #{msg.i}"
		else "everything"
	switch method
		when 'start' then _line += "Starting #{targetText}..."
		when 'stop' then _line += "Stopping #{targetText}..."
		when 'restart' then _line += "Restarting #{targetText}..."
		when 'enable' then _line += "Enabling #{targetText}..."
		when 'disable' then _line += "Disabling #{targetText}..."
	if _line.length > 0
		echo _line
		client?.write $.TNET.stringify _line
	else
		echo "simpleAction", method, JSON.stringify(msg)
	switch
		when msg.g then return actOnGroup method, msg.g, cb
		when msg.i then return actOnInstance method, msg.i, cb
		else return actOnAll method, cb

Object.assign module.exports, { Groups, actOnAll, actOnInstance, addGroup, removeGroup, simpleAction }

# fulfill some out-of-order obligations
Nginx = require './nginx'
{ saveConfig } = require '../util/config'
