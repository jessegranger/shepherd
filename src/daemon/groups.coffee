
$ = require 'bling'
Nginx = null # placeholder for out of order import
saveConfig = null
Shell = require 'shelljs'
ChildProcess = require 'child_process'
SlimProcess = require '../util/process-slim'

echo = $.logger "[shepd-#{process.pid}]"
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
		@monitors = Object.create null # used later by health checks
	scale: (n) ->
		if (dn = n - @n) > 0
			echo "[scale(#{n})] Adding #{dn} instances..."
			for d in [0...dn] by 1
				p = createProcess @, @n++
				p.start()
				@push p
			echo "[scale(#{n})] @n is now #{@n}"
		else if dn < 0
			echo "[scale(#{n})] Trimming #{dn} instances..."
			while @n > n
				@pop().stop()
				@n -= 1
			echo "[scale(#{n})] @n is now #{@n}"
		else return false
		saveConfig()
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
	actOnAll: (method) ->
		(x[method]() for x in @).reduce ((a,x)=>a or x), false
	toString: ->
		"[group #{@name}] " + ("#{if proc.port then "(#{proc.port}) " else ""}#{proc.statusString}" for proc,i in @).join ", "

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
				if owner.pid is process.pid or (owner.uid isnt process.getuid())
					@enabled = @expected = @started = @healthy = false
					return cb @statusString = "invalid port"
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
				echo "exec:", @exec, "as", @id
				@proc = ChildProcess.exec @exec, { shell: true, cwd: @cd, env: env }
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
					echo "Waiting for port #{@port} to be owned by #{@proc.pid} (will wait #{@group.grace} ms)"
					SlimProcess.waitForPortOwner @proc.pid, @port, @group.grace, (err, owner) ->
						if err?
							echo "Failed to find port owner, err:", err, (Date.now() - _s)
							return retryStart()
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
					@proc?.unref?()
					@proc = undefined
				return true

	stop: (cb) ->
		@statusString = "stopping"
		@expected = false
		if @started and @proc?.pid
			@proc.on 'exit', =>
				@started = false
				@statusString = if @enabled then "stopped" else "disabled"
				if @port
					Nginx.sync => cb? true
				else
					cb? true
			process.kill @proc.pid
			return true
		@started = false
		@statusString = if @enabled then "stopped" else "disabled"
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
	proc = Groups.get(groupId)?[index]
	return afterAction method, proc?[method]?()

actOnGroup = (method, groupId) ->
	group = Groups.get(groupId)
	unless group?
		return false
	if group?[method]?
		return group[method]()
	return afterAction method, group.actOnAll method

actOnAll = (method) ->
	acted = false
	Groups.forEach (group) ->
		if group[method]?
			acted = group[method]() or acted
		else for proc in group
			acted = proc[method]() or acted
	return afterAction method, acted

addGroup = (name, cd, exec, count, port, grace=DEFAULT_GRACE) ->
	return false if Groups.has(name)
	echo "Adding group:", name, cd, exec, count, port, grace
	Groups.set name, new Group(name, cd, exec, count, port, grace)
	return afterAction 'add', true

removeGroup = (name) ->
	return false unless Groups.has(name)
	echo "Deleting group:", name
	Groups.delete name
	return afterAction 'remove', true

afterAction = (method, ret) ->
	if method in ['enable', 'disable', 'add', 'remove']
		saveConfig()
	ret

simpleAction = (method) -> (msg, client) ->
	echo "simpleAction", method, JSON.stringify(msg)
	switch
		when msg.g then return actOnGroup method, msg.g
		when msg.i then return actOnInstance method, msg.i
		else return actOnAll method

Object.assign module.exports, { Groups, actOnAll, actOnInstance, addGroup, removeGroup, simpleAction }

Nginx = require './nginx'
{ saveConfig } = require '../util/config'
