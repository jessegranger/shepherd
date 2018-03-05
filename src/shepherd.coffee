Opts    = require './opts'
if Opts.daemon then require('daemon') { # fork into the background
	# stdout: 'inherit', stdin: 'inherit'
	cwd: process.cwd() # work-around indexzero/daemon.node#41, needed for Node 8
}
$       = require "bling"
Fs      = require "fs"
log     = $.logger "[shepherd]"
exit_soon = (n) => setTimeout (=> process.exit n), 0
die     = (a...) ->
	log a...
	exit_soon 1
verbose = ->
	if Opts.verbose then log.apply null, arguments

# create the default output stream
outputs = {
	'-': process.stdout
	# add addtional { key: WriteStream } pairs here to log to additional places
}

# create additional output streams requested by the user
if Opts.O isnt "-"
	try
		retryCount = 12
		do reopen = ->
			if --retryCount <= 0
				console.error "Output stream giving up, too many open failures"
				return
			(outputs[Opts.O] = Fs.createWriteStream Opts.O, { flags: 'a', mode: 0o640, encoding: 'utf8' })\
				.on('finish', (e) ->
					console.error "Output stream 'finish' event:", e
					delete outputs[Opts.O]
					$.delay 0, reopen
				)
				.on('error', (err) ->
					console.error "Output stream 'error' event:", err
					delete outputs[Opts.O]
					$.delay 0, reopen
				)
	catch err then die "Failed to open output stream:", $.debugStack err

$.log.out = (a...) ->
	data = a.map($.toString).join(' ') + "\n"
	for k, s of outputs
		try s.write data, 'utf8'
		catch err
			console.error "failed to write to output[#{k}]:", $.debugStack err

$.log.enableTimestamps()

verbose "Opened output stream to: #{Opts.O}"

Helpers  = require './helpers'
Herd     = require './herd'
Validate = require './validate'

if Opts.example
	d = Herd.defaults()
	{ Server, Worker } = require "./child"
	d.servers.push Server.defaults()
	d.workers.push Worker.defaults()
	console.log JSON.stringify d, null, '  '
	return exit_soon 0

if Opts.P # write out a pid file
	verbose "Writing pid file:", Opts.P
	Fs.writeFileSync Opts.P, String process.pid


verbose "Reading config file:", Opts.F
Helpers.readJson(Opts.F).wait (err, config) ->
	if err then die "Failed to open json file:", Opts.F, err.stack
	config = Herd.defaults(config)
	errors = Validate.isValidConfig(config)
	if errors.length then die errors.join "\n"
	log "Starting new herd, shepherd PID: " + process.pid
	if config.loggly?.enabled
		outputs['loggly'] = require("./loggly").createWriteStream {
			token: config.loggly.token
			subdomain: config.loggly.subdomain
			tags: config.loggly.tags ? []
			json: config.loggly.json ? false
		}
		verbose "Opened output stream to Loggly (#{config.loggly.subdomain})."
	if config.mongodb?.enabled
		outputs['mongodb'] = require("./mongodb").createWriteStream {
			url: config.mongodb.url
			collection: config.mongodb.collection
			size: config.mongodb.size
		}
		verbose "Opened output stream to MongoDB (#{config.mongodb.url}/#{config.mongodb.collection})"
	new Herd(config).start().wait (err) ->
		if err then die "Failed to start herd:", $.debugStack err

