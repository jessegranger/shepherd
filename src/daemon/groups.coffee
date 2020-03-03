
{ $, echo, warn, verbose } = require '../common'
Path = require 'path'
Nginx = null # placeholder for out of order import
saveConfig = null
ChildProcess = require 'child_process'
SlimProcess = require '../util/process-slim'
{ exists } = require '../files'
{ quoted } = require '../common'

minutes = (n) -> n*60000

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
		for proc in @ then proc.stop()
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
		@expected = false # should this proc be up (right now)
		@enabled = true # should this proc be up (in general)
		@started = false # is it (when was it) started
		@healthy = undefined # used later by health checks
		@cooldown = Proc.cooldown# this increases after each failed restart
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
		if @started
			verbose "#{@id} already started, skipping."
			return done(null, false)
		if not @enabled
			verbose "#{@id} not enabled, skipping."
			return done(null, false)
		@expected = true
		@healthy = undefined
		env = Object.assign {}, process.env, { PORT: @port }

		# clearPort will try to kill any other process using our port
		# but will check some safeties first:
		# - dont kill processes owned by other users
		# - dont kill processes managed by our same shepherd
		clearPort = (cb) =>
			if not (@expected and @enabled)
				verbose "#{@id} giving up on clearPort", { @expected, @enabled }
				return done(null, false) # stopped while waiting
			verbose "#{@id} Checking for owner of port #{@port}..."
			if @port then SlimProcess.getPortOwner @port, (err, owner) =>
				return cb() unless owner
				# so, the @port is currently owned...
				invalidPort = =>
					verbose "#{@id} Marking port #{@port} as invalid."
					return done @markAsInvalid "invalid port"
				this_uid = process.getuid()
				verbose "#{@id} Checking if owner #{owner.uid} is same as ours #{this_uid}"
				# 1) - dont kill processes owned by other users
				if owner.uid isnt this_uid
					return invalidPort()
				# 2) - dont kill processes owned by any of our parents
				SlimProcess.getProcessTable (err, procs) =>
					verbose "#{@id} Checking if owner pid #{owner.pid} is one of our parents..."
					SlimProcess.visitProcessTree process.pid, (proc) =>
						invalidPort() if proc.pid is owner.pid
						null
					if @statusString isnt "invalid port"
						verbose "#{@id} Owner pid #{owner.pid} is not managed by shepherd, killing it..."
						verbose owner
						@statusString = "killing #{owner.pid}"
						SlimProcess.killProcessTree owner.pid, 'SIGTERM', (err) =>
							if err
								warn "#{@id} failed to kill other owner of port #{@port}: owner #{owner.pid}"
								warn err
							setTimeout (=> clearPort cb), 1000
					else
						warn "#{@id} asked for PORT #{@port} but it is in-use by another group in this shepherd"
			else cb?()
		retryStart = =>
			if @started or not @enabled
				return done(null, false)
			@cooldown = (Math.min 10000, @cooldown * 2)
			@statusString = "waiting #{@cooldown}ms"
			setTimeout doStart, @cooldown
			return true
		do doStart = =>
			if @started
				verbose "#{@id} ignoring start of already started instance."
				return done(null, false)
			if not @expected
				verbose "#{@id} ignoring start of unexpected instance."
				return done(null, false)
			clearPort (err) =>
				if err
					verbose "#{@id} aborting start while inside clearPort", { err }
					return done(null, false)
				if not @expected
					verbose "#{@id} aborting start while inside clearPort", { @expected }
					return done(null, false)
				checkStarted = null
				@statusString = "starting"
				try
					@cd = Path.resolve(process.cwd(), @cd)
					verbose "cd:", @cd
				catch err # it's actually possible for node's internals to throw an exception here if cwd() is weird
					verbose "#{@id} CWD error: #{err.message}"
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
								echo "#{@id} abort requested while waiting for port", { @expected, @enabled }
								return @stop => done(null, false)
							switch err
								when 'exit'
									warn "#{@id} exited immediately, attempting to resume."
									@proc = null
									return @stop retryStart
								when 'timeout'
									echo "#{@id} did not listen on port #{@port} within the timeout: #{@group.grace}ms"
									return @stop retryStart
								else
									if err?
										echo "#{@id} failed to find port owner after", (Date.now() - _s) + "ms"
										warn err
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
						@statusString = "exit(#{code}) ok" # just report it
					else # it should be up, but went down
						echo "#{@id} Unexpected exit, restarting..."
						return retryStart()
					return true

	stop: (cb) ->
		@expected = false
		@statusString = "stopping"
		if @checkResumeTimeout isnt null
			verbose "cancelling checkResumeTimeout..."
			clearTimeout @checkResumeTimeout
			@checkResumeTimeout = null
		if @proc?.pid > 1
			@proc.on 'exit', =>
				verbose "#{@id} event: 'exit'"
				@started = false
				@statusString = if @enabled then "stopped" else "disabled"
				if @port
					Nginx.sync => cb? null, true
				else
					cb? null, true
			try
				SlimProcess.killProcessTree @proc.pid, 'SIGTERM', (err) =>
					if err then warn "#{@id} killProcessTree error: #{err}"
			catch err
				warn "#{@id} killProcessTree threw exception:", err
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
		else cb?(null, false)
		acted

	markAsInvalid: (reason) ->
		@enabled = @expected = @started = @healthy = false
		@statusString = reason
		false

	disable: (cb) ->
		acted = @enabled
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
	finishOne = (err, act) =>
		acted = act or acted
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
