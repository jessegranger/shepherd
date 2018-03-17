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

refresh_process_table = (cb) ->
	process_table = {}
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
				process_table[pid] = { uid, pid, ppid, pcpu, rss, command, ports: [] }
		lsof = ChildProcess.spawn('lsof', lsof_argv, { shell: false })
		lsof_buf = ""
		lsof.stdout.on 'data', (data) -> lsof_buf += data.toString 'utf8'
		lsof.on 'error', cb
		lsof.on 'close', ->
			for line in lsof_buf.split /\n/
				[ name, pid, user, fd, type, dev, sz, proto, addr, mode] = line.split(/ +/)
				if mode is "(LISTEN)"
					unless pid of process_table
						process_table[pid] = { pid, ppid: 0, ports: [], pcpu: 0, rss: 0, command: "???" }
					process_table[pid].ports.push addr
			process_table_ts = Date.now()
			cb null, process_table
	null

isChildOf = (ppid, pid, cb) ->
	refresh_process_table_if_needed (err, procs) ->
		return cb(err) if err
		return cb null, is_child_of(procs, ppid, pid)

is_child_of = (procs, ppid, pid) ->
	proc = procs[pid]
	return true if ppid in [pid, proc.ppid]
	return false if proc.ppid in [proc.pid,0,1,null,undefined,'','0','1']
	return is_child_of(procs, ppid, proc.ppid)

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

waitForPortOwner = (pid, port, timeout, cb) =>
	pid = parseInt pid
	port = String port
	_timeout = setTimeout (=>
		cb('timeout')
		cb = null
	), timeout
	do checkAgain = =>
		refresh_process_table (err, procs) =>
			return cb(err) if err
			for _,proc of procs
				for _port in proc.ports
					this_port = _port.split(':')[1]
					if this_port is port and is_child_of(procs, pid, proc.pid)
						clearTimeout _timeout
						return cb?(null, proc)
			cb? and setTimeout checkAgain, 400

getProcessTable = refresh_process_table

Object.assign module.exports, { formatProcess, waitForPortOwner, visitProcessTree, getPortOwner, isChildOf, getProcessTable }

if require.main is module
	start = Date.now()
	refresh_process_table (err, procs) ->
		$.log (elapsed = Date.now() - start) + "ms"
		waitForPortOwner 854, 27017, 1000, (err, owner) ->
			if err is 'timeout' then console.log "TIMED OUT"
			else
				console.log formatProcess(owner)
				visitProcessTree 854, (proc, level) ->
					console.log '+', $.repeat(". ", level) + formatProcess(proc)
				cpuSum = memSum = 0
				visitProcessTree 854, (proc, level) ->
					cpuSum += proc.pcpu
					memSum += proc.rss
				console.log "CPU: #{cpuSum.toFixed(0)}% MEM: #{$.commaize(Math.round(memSum/1024))}MB"

