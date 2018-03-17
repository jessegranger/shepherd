
{ $, echo, warn, verbose } = require '../common'
Path = require 'path'
Nginx = null # placeholder for out of order import
saveConfig = null
Shell = require 'shelljs'
ChildProcess = require 'child_process'
SlimProcess = require '../util/process-slim'
{ dirExists } = require '../files'

# the global herd of processes
Groups = new Map()
# m.clear m.delete m.entries m.forEach m.get m.has m.keys m.set m.size m.values

`const DEFAULT_GRACE = 9000;`

quoted = (s) ->
	'"' + s.replace(/"/g,'\\"') + '"'

class Group extends Array
	createProcess = (g, i) ->
		port = undefined
		if g.port
			port = g.port + i
		new Proc "#{g.name}-#{i}", g.cd, g.exec, port, g
	constructor: (@name, @cd, @exec, @n, @port, @grace=DEFAULT_GRACE) ->
		super()
		for i in [0...@n] by 1
			@push createProcess @, i
		@monitors = Object.create null # used later by health checks
	scale: (n, cb) ->
		dn = n - @n
		progress = $.Progress dn
		progress.then => saveConfig cb
		if dn > 0
			echo "[scale(#{n})] Adding #{dn} instances..."
			for d in [0...dn] by 1
				p = createProcess @, @n++
				p.start => progress.finish 1
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
			return (if @port then Nginx.sync(cb) else cb?()) unless i < @length
			@[i].start => oneStep(i+1)
		true
	stop: (cb) ->
		for proc in @
			proc.expected = false
		for proc in @
			proc.stop()
		cb?()
	markAsInvalid: (reason) ->
		for proc in @
			proc.markAsInvalid reason
		@
	actOnAll: (method, cb) ->
		progress = $.Progress(@length)
		progress.wait cb
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
	constructor: (@id, @cd, @exec, @port, @group) ->
		# the time of the most recent start
		@started = false
		@enabled = true
		@healthy = undefined # used later by health checks
		@cooldown = 200 # this increases after each failed restart
		@expected = false # is this process expected to be running?
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
		@expected = true
		done = (ret) => cb?(ret); ret
		return done(false) if @started or not @enabled
		env = Object.assign {}, process.env, { PORT: @port }
		clearPort = (cb) =>
			if @port then SlimProcess.getPortOwner @port, (err, owner) =>
				return cb() unless owner
				invalidPort = =>
					return cb @markAsInvalid "invalid port"
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
			else cb()
		retryStart = =>
			return done(false) if @started or not @enabled
			@cooldown = (Math.min 30000, @cooldown * 2)
			@statusString = "waiting #{@cooldown}"
			setTimeout doStart, @cooldown
			return true
		do doStart = =>
			return done(false) if @started or not @enabled
			clearPort (err) =>
				return done(false) if err
				checkStarted = null
				@statusString = "starting"
				verbose "exec:", @exec, "as", @id
				verbose "cd:",
				@cd = Path.resolve(process.cwd(), @cd)
				# echo "opts:",
				opts = { shell: true, cwd: @cd, env: env }
				if not dirExists(@cd)
					return @stop => @group.markAsInvalid "invalid dir"
				@proc = ChildProcess.spawn @exec, opts
				finishStarting = =>
					@started = $.now
					@cooldown = 25
					@statusString = "started"
					if @port
						Nginx.sync => done(true)
					else
						done(true)
				if @port
					_s = Date.now()
					$.delay 50, =>
						if not @proc?
							return done(false)
						if not @proc?.pid?
							@statusString = "exec failed"
							@started = @expected = @enabled = @healthy = false
							return done(false)
						echo "Waiting for port #{@port} to be owned by #{@proc.pid} (will wait #{@group.grace} ms)"
						SlimProcess.waitForPortOwner @proc.pid, @port, @group.grace, (err, owner) =>
							if err?
								echo "Failed to find port owner, err:", err, (Date.now() - _s)
								return @stop retryStart
							finishStarting()
				else # if there is no port to wait for then staying up for a few seconds counts as started
					checkStarted = setTimeout finishStarting, @grace
				
				# Connect the process output to our log writer.
				@proc.stdout.on 'data', (data) => @log data.toString("utf8")
				@proc.stderr.on 'data', (data) => @log "(stderr)", data.toString("utf8")
				@proc.on 'exit', (code, signal) =>
					clearTimeout checkStarted
					@statusString = "exit(#{code})"
					@started = false
					if @expected
						echo "Exit was not expected, restarting..."
						return retryStart()
					if @proc?.pid
						try @proc?.unref?()
					@proc = undefined
				return true

	stop: (cb) ->
		@statusString = "stopping"
		@expected = false
		if @proc?.pid > 1
			@proc.on 'exit', =>
				@started = false
				@statusString = if @enabled then "stopped" else "disabled"
				if @port
					Nginx.sync => cb? true
				else
					cb? true
			try process.kill @proc.pid
			return true
		@started = false
		@statusString = if @enabled then "stopped" else "disabled"
		cb? false
		return false

	restart: (cb) ->
		@statusString = "restarting"
		@stop => @start cb

	enable: (cb) ->
		acted = ! @enabled
		@enabled = true
		@statusString = "enabled"
		if acted then @start cb
		else cb()
		acted
	
	markAsInvalid: (reason) ->
		@enabled = @expected = @started = @healthy = false
		@statusString = reason

	disable: (cb) ->
		acted = @enabled
		@enabled = false
		if acted then @stop cb
		@statusString = "disabled"
		if not acted then cb()
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
		return cb('invalid method')
	proc[method] (ret) =>
		afterAction method, ret, cb
	false

actOnGroup = (method, groupId, cb) ->
	group = Groups.get(groupId)
	unless group?
		return false
	if (not group)
		return cb('invalid group')
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
	Groups.forEach (group) ->
		if 'function' is typeof group[method]
			group[method] (ret) =>
				acted = ret or acted
				progress.finish 1
		else for proc in group when method of proc
			proc[method] (ret) =>
				acted = ret or acted
				progress.finish 1
	progress.finish 1

addGroup = (name, cd=".", exec, count=1, port, grace=DEFAULT_GRACE, cb) ->
	if Groups.has(name)
		echo "Group already exists. Did you mean 'replace'?"
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
		saveConfig => cb?(ret)
	else cb?(ret)
	ret

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
