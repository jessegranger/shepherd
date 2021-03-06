$ = require 'bling'
module.exports.read_stream = (socket, cb) ->
	ret = new $.Promise()
	buf = ""
	socket.on 'data', (data) ->
		buf += data.toString("utf8")
		while buf.length > 0
			[ item, rest ] = $.TNET.parseOne( buf )
			break if rest.length is buf.length # if we didn't consume anything, wait for the next data to resume parsing
			buf = rest
			cb item
	socket.on 'error', (err) -> ret.reject(err)
	socket.on 'close', -> ret.resolve()
	socket.on 'end', -> ret.resolve()
	ret
