
{ $, echo, verbose } = require '../common'
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
		fileStream.write $(chunks).select('chunk').join(''), chunks[0].enc, cb
		null
}

$.log.out = (args...) ->
	str = args.map($.toString).join ' '
	if str[str.length - 1] isnt '\n'
		str += '\n'
	process.stdout.write str
	outputStream.write str, 'utf8', =>
	return str

setOutput = (file, cb) =>
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
				setOutput null, cb
			s.on 'error', (err) ->
				console.error "writeStream error:", (err.stack ? err)
				setOutput null, cb
		catch err
			console.log "Caught error:", (err.stack ? err)
			outputFile = fileStream = null
			cb?(err, false)
	null

toConfig = =>
	outputFile and "log --file \"#{outputFile}\"" or ""

getOutputFile = => return outputFile and outputFile.substring(0)

Object.assign module.exports, { getOutputFile, setOutput, toConfig, stream: outputStream }

process.stdout.on 'error', (err) ->
	if err.code is "EPIPE"
		process.exit(2)
