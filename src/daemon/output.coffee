{ $, die, echo, verbose } = require '../common'
Fs = require 'fs'
{ Writable } = require 'stream'
{ outputFile, expandPath } = require '../files'

fileStream = null

outputStream = new Writable {
	decodeStrings: false
	objectMode: false
	write: (chunk, enc, cb) ->
		outputStream.emit 'tail', chunk
		return cb?(null) unless outputFile and fileStream
		fileStream.write chunk, enc, cb
	writev: (chunks, cb) ->
		return cb?(null) unless outputFile and fileStream
		if chunks?.length > 0
			line = ''
			for item in chunks
				line += item.chunk
			fileStream.write line, chunks[0].enc, cb
		null
}

dataToOutputLine = (label, data) => 
	str = (if label? then "#{label} " else "") + data.toString("utf8")
	if str[str.length - 1] isnt '\n'
		str += '\n'

$.log.out = (args...) ->
	str = dataToOutputLine(null, args.map($.toString).join ' ')
	try process.stdout.write str
	catch err
		if err then process.stderr.write "Failed to write to stdout: " + $.toString err
	outputStream.write str, 'utf8', (err) ->
		if err then process.stderr.write "Failed to write to outputStream: " + $.toString err
	return str

setOutputFile = (file, cb) ->
	if outputFile is file and fileStream?
		return cb?(null, false)
	if not file?
		outputFile = null
		return cb?(null, true)
	else
		try
			echo "Starting output to", file
			s = fileStream = Fs.createWriteStream expandPath(file), { flags: 'a' }
			outputFile = file
			s.on 'open', ->
				s.write "Opened for writing at " + String(new Date()) + "\n"
				cb?(null, true)
			s.on 'close', ->
				console.log "writeStream close:", file
				setOutputFile null, cb
			s.on 'error', (err) ->
				console.error "writeStream error:", (err.stack ? err)
				setOutputFile null, cb
		catch err
			console.error "setOutputFile error:", (err.stack ? err)
			outputFile = fileStream = null
			cb?(err, false)
	null

toConfig = -> outputFile and "log --file \"#{outputFile}\"" or ""

getOutputFile = -> return outputFile and outputFile.substring(0)

Object.assign module.exports, { getOutputFile, setOutputFile, toConfig, stream: outputStream }

process.stdout.on 'error', (err) ->
	if err.code is "EPIPE"
		process.exit(2)
