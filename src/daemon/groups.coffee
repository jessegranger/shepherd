
$ = require 'bling'
Shell = require 'shelljs'
Process = require '../util/process'
SlimProcess = require '../util/process-slim'
ChildProcess = require 'child_process'
echo = $.logger "[shepd]"
warn = $.logger "[warning]"

# the global herd of processes
Groups = new Map()
# m.clear m.delete m.entries m.forEach m.get m.has m.keys m.set m.size m.values

`const DEFAULT_GRACE = 9000;`

class Group extends Array
	createProcess = (g, i) ->
		port = undefined
		if g.port
			port = g.port + i
		new Proc "#{g.name}-#{i}", g.cd, g.exec, port, g
	constructor: (@name, @cd, @exec, @n, @port, @grace=DEFAULT_GRACE) ->
		for i in [0...@n] by 1
			@push createProcess @, i
	scale: (n) ->
		if (dn = n - @n) > 0
			echo "[scale(#{n})] Adding #{dn} instances..."
			for d in [0...dn] by 1
				@push createProcess(@, @n + d).start()
		else if dn < 0
			echo "[scale(#{n})] Trimming #{dn} instances..."
			while @n-- > n
				@pop().stop()
		else false
		true
	restart: (cb) -> # Slowly kill and restart one at a time
		do oneStep = (i=0) =>
			return cb?() unless i < @length
			@[i].restart => oneStep(i+1)
		true
	start: (cb) ->
		do oneStep = (i=0) =>
			return cb?() unless i < @length
			@[i].start => oneStep(i+1)
		true
	stop: (cb) ->
		for proc in @
			proc.expected = false
		for proc in @
			proc.stop()
		cb?()
	actOnAll: (method) ->
		(x[method]() for x in @).reduce ((a,x)=>a or x), false
	toString: ->
		@name + " " + ("[#{i}:#{proc.port ? ""}:#{proc.statusString}] " for proc,i in @).join " "

class Proc
	constructor: (@id, @cd, @exec, @port, @group) ->
		# the time of the most recent start
		@started = false
		@enabled = true
		@cooldown = 100 # this increases after each failed restart
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
				echo "Group:", @group.toString()
		}
	
	log: (args...) ->
		$.log "[#{@id}]", args...

	# Start this process if it isn't already.
	start: (cb) -> # cb called with a 'started' flag that indicates if any work was done
		return false if @started or not @enabled
		@expected = true
		env = Object.assign {}, process.env, { PORT: @port }
		done = (ret) => cb(ret); ret
		retryStart = =>
			return done(false) unless @enabled
			@cooldown = (Math.min 20000, @cooldown * 2)
			@statusString = "waiting #{@cooldown}"
			setTimeout doStart, @cooldown
			return true
		doStart = =>
			return done(false) unless @enabled
			checkStarted = null
			@statusString = "starting"
			@proc = ChildProcess.exec @exec, { shell: true, cwd: @cd, env: env }
			finishStarting = =>
				@started = $.now
				@cooldown = 25
				@statusString = "started"
				done(true)
			if @port
				_s = Date.now()
				# echo "Waiting for port #{@port} to be owned by #{@proc.pid} (will wait #{@group.grace} ms)"
				SlimProcess.waitForPortOwner @proc.pid, @port, @group.grace, (err, owner) ->
					if err?
						echo "Failed to find port owner, err:", err, (Date.now() - _s)
						return retryStart()
					finishStarting()
			else # if there is no port to wait for then staying up for 3 seconds counts as started
				checkStarted = setTimeout finishStarting, (Math.max 3000, @cooldown)
			
			# Connect the process output to our log writer.
			@proc.stdout.on 'data', (data) => @log data.toString("utf8")
			@proc.stderr.on 'data', (data) => @log "(stderr)", data.toString("utf8")
			@proc.on 'exit', (code, signal) =>
				clearTimeout checkStarted
				@statusString = "exit(#{code},#{signal})"
				@started = false
				if @expected
					echo "Exit was not expected, restarting..."
					return retryStart()
				@proc?.unref?()
				@proc = undefined
			return true
		return doStart() unless @port
		# @log "Checking if port #{@port} is owned."
		SlimProcess.getPortOwner @port, (err, proc) =>
			return doStart() unless proc
			@statusString = "killing #{proc.pid}"
			process.kill proc.pid, 'SIGTERM'
			setTimeout retryStart, 1000
		return @

	stop: (cb) ->
		@statusString = "stopping"
		@expected = false
		if @started and @proc?.pid
			try process.kill @proc.pid
			@started = false
			@statusString = "stopped"
			cb? true
			return true
		@started = false
		@statusString = "stopped"
		cb? false
		return false

	restart: (cb) ->
		@statusString = "restarting"
		@stop => @start cb

	enable: ->
		acted = ! @enabled
		@enabled = true
		@statusString = "enabled"
		if acted then @start()
		acted

	disable: ->
		acted = @enabled
		@enabled = false
		if acted then @stop()
		@statusString = "disabled"
		acted

actOnInstance = (method, instanceId) ->
	return false unless instanceId?.length
	acted = false
	chunks = instanceId.split '-'
	index = chunks[chunks.length - 1]
	groupId = chunks.slice(0, chunks.length - 1).join('-')
	index = parseInt index, 10
	proc = Groups.get(groupId)[index]
	return proc[method]()

actOnGroup = (method, groupId) ->
	group = Groups.get(groupId)
	unless group?
		return false
	if group?[method]?
		return group[method]()
	return group.actOnAll method

actOnAll = (method) ->
	acted = false
	Groups.forEach (group) ->
		if group[method]?
			acted = group[method]() or acted
		else for proc in group
			acted = proc[method]() or acted
	return acted

addGroup = (name, cd, exec, count, port, grace=DEFAULT_GRACE) ->
	return false if Groups.has(name)
	echo "Adding group:", name, cd, exec, count, port, grace
	Groups.set name, new Group(name, cd, exec, count, port, grace)
	return true

removeGroup = (name) ->
	return false unless Groups.has(name)
	echo "Deleting group:", name
	Groups.delete name
	return true

simpleAction = (method) -> (msg, client) ->
	echo "simpleAction", method, msg
	switch
		when msg.g then return actOnGroup method, msg.g
		when msg.i then return actOnInstance method, msg.i
		else return actOnAll method

$.extend module.exports, { Groups, actOnAll, actOnInstance, addGroup, removeGroup, simpleAction }
