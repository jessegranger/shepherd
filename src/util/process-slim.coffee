{ $, echo, warn, verbose } = require '../common'
ChildProcess = require "child_process"

# need to support some queries
# Wait until a PID (or a child of PID) owns port N

ps_argv = ["-eo", "uid,pid,ppid,pcpu,rss,command"]
lsof_argv = ["-Pni"]

# Process table entry:
# 0: { pid: 0, ppid: 0, ports: [], pcpu: 0, rss: 0, command: 0 }

process_table_ts = 0
process_table = {}

refresh_process_table_if_needed = (cb) ->
	if Date.now() - process_table_ts > 3000
		refresh_process_table(cb)
	else cb(null, process_table)

refresh_process_table = (cb, ports=true) ->
	new_table = {}
	ps = ChildProcess.spawn('ps', ps_argv, { shell: false })
	buf = ""
	ps.stdout.on 'data', (data) -> buf += data.toString 'utf8'
	ps.on 'error', cb
	ps.on 'close', ->
		for line in buf.split /\n/
			[_, uid, pid, ppid, pcpu, rss, command...] = line.split(/ +/)
			command = command.join ' '
			if pid?.length > 0 and pid isnt "PID"
				uid = parseInt uid
				pid = parseInt pid
				ppid = parseInt ppid
				pcpu = parseFloat pcpu
				rss = parseInt rss
				new_table[pid] = { uid, pid, ppid, pcpu, rss, command, ports: [] }
		if ports
			lsof = ChildProcess.spawn('lsof', lsof_argv, { shell: false })
			lsof_buf = ""
			lsof.stdout.on 'data', (data) -> lsof_buf += data.toString 'utf8'
			lsof.on 'error', cb
			lsof.on 'close', ->
				for line in lsof_buf.split /\n/
					[ name, pid, user, fd, type, dev, sz, proto, addr, mode] = line.split(/ +/)
					if mode is "(LISTEN)"
						unless pid of new_table
							new_table[pid] = { pid, ppid: 0, ports: [], pcpu: 0, rss: 0, command: "???" }
						new_table[pid].ports.push addr
				process_table_ts = Date.now()
				cb null, process_table = new_table
		else
				cb null, new_table
	null

isChildOf = (ppid, pid, cb) ->
	refresh_process_table_if_needed (err, procs) ->
		return cb(err) if err
		return cb null, is_child_of(procs, ppid, pid)

is_child_of = (procs, ppid, pid) ->
	proc = procs[pid]
	return true if ppid in [pid, proc.ppid]
	return false if proc.ppid in [proc.pid,0,1,null,undefined,'','0','1']
	return is_child_of(procs, proc.ppid, pid)

visitProcessTree = (pid, visit) =>
	refresh_process_table_if_needed (err, procs) =>
		procs[pid] and visit procs[pid], 0
		walk = (_pid, level) =>
			for _,proc of procs when proc?.ppid is _pid
				visit proc, level
				walk proc.pid, level + 1
		walk pid, 1

formatProcess = (proc) =>
	[ proc.pid,
		'[',
		proc.pcpu.toFixed(1) + "%",
		$.commaize(Math.round(proc.rss / 1024)) + "MB",
		']',
		$.stringTruncate(proc.command, 100, '...', '/'),
		proc.ports.length and ('[ ' + proc.ports.join(', ') + ' ]') or ("")
	].join ' '

getChildrenOf = (pid, cb) =>
	refresh_process_table_if_needed (err, procs) ->
		children = []
		recurse = (_pid) ->
			for _,proc of procs when proc.ppid is _pid
				children.push proc
				# list them all depth-first
				recurse(proc.pid)
		# start the recursion with our root process
		recurse(pid)
		return cb null, children

isValidPid = (pid) -> pid? and isFinite(pid) and (not isNaN pid) and pid > 0

getParentsOf = (pid, cb) =>
	refresh_process_table_if_needed (err, procs) ->
		parents = []
		recurse = (proc) ->
			ppid = proc.ppid
			if isValidPid(ppid)
				parents.push proc
				recurse procs[ppid]
		# kick start the recursion
		recurse procs[pid]
		return cb null, parents

getPortOwner = (port, cb) =>
	port = String port
	refresh_process_table_if_needed (err, procs) =>
		return cb(err) if err
		for _,proc of procs
			for _port in proc.ports
				this_port = _port.split(':')[1]
				if this_port is port
					return cb null, proc
		cb null, null

waitForPortOwner = (target, port, timeout, cb) =>
	done = (err, proc) =>
		clearTimeout _timeout
		target.removeListener 'exit', exit_handler
		cb?(err, proc)
		cb = null
	_timeout = setTimeout (=> done 'timeout'), timeout
	target.on 'exit', exit_handler = (=> done 'exit')
	target_port = String port
	do checkAgain = =>
		refresh_process_table (err, procs) =>
			return done(err) if err
			for _,proc of procs
				for _port in proc.ports
					this_port = _port.split(':')[1]
					if this_port is target_port
						verbose "someone (pid #{proc.pid}) listening on target port", target_port
						if is_child_of(procs, target.pid, proc.pid)
							return done(null, proc)
			cb? and setTimeout checkAgain, 400
			null
		null
	null

getProcessTable = refresh_process_table

getProcessTree = (pid, cb) =>
	ret = []
	getProcessTable (err, table) =>
		recurse = (_pid) =>
			ret.push _pid
			for _,proc of table when proc.ppid is _pid
				recurse proc.pid
		recurse pid
		cb ret
	null

killProcessTree = (pid, signal, cb) =>
	echo "killProcessTree(#{pid}, #{signal})"
	# Do multiple passes over the process table, to make sure the PIDs are really gone
	do onePass = =>
		getProcessTree pid, (tree) =>
			tree.pop() # always discard the first pid in the tree, which is a copy of pid
			verbose "PIDs to kill under #{pid}:", tree.join(" ")
			# because we dont want to kill the current pid, which would terminate the loop
			if tree.length < 1
				cb(null)
				return
			for pid in tree
				verbose "[process-slim] process.kill(#{pid}, #{signal})"
				try
					process.kill pid, signal
				catch err
					warn "[process-slim] process.kill(#{pid}) failed: #{err}"
			# do another pass, until the tree is only the root pid
			setTimeout(onePass, 1000)

Object.assign module.exports, { formatProcess, waitForPortOwner, visitProcessTree, getPortOwner, isChildOf, getProcessTable, killProcessTree, getParentsOf, getChildrenOf }

if require.main is module
	start = Date.now()
	getProcessTree 27824, (list) ->
		for pid in list
			console.log pid

