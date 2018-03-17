$ = require 'bling'

machine = $.StateMachine

class ArgumentMachine extends $.StateMachine
	constructor: (debug=false) ->
		table = [
			# state 0: init
			enter: ->
				@obj = { _: [ '' ] }
				@param = @value = ''
				1
			# state 1: read unknown
			{
				'-': -> 2
				' ': ->
					if @obj._[@obj._.length - 1].length > 0
						@obj._.push ''
					1
				def: (c) ->
					@obj._[@obj._.length - 1] += c; 1
				eof: ->
					@param is '' or
						@obj[@param] = (@value is '') or
							isFinite(f = parseFloat @value) and not isNaN(f) and f or @value
			}
			# state 2: start reading a -p or --param
			{
				'-': -> 3 # read a full --param
				' ': -> 4
				def: (c) -> @param += c; 2
				eof: ->
					@param is '' or
						@obj[@param] = (@value is '') or
							isFinite(f = parseFloat @value) and not isNaN(f) and f or @value
			}
			# state 3: read a full --param
			{
				' ': -> 4 # read a value
				def: (c) -> @param += c; 3
				eof: ->
					@param is '' or
						@obj[@param] = (@value is '') or
							isFinite(f = parseFloat @value) and not isNaN(f) and f or @value
			}
			# state 4: read value after -p if there is one
			{
				' ': -> @next = 1; 9
				'-': -> (@value is '') and (@next = 2; 9) or (@value += '-'; 4)
				'"': -> 5
				"'": -> 6
				def: (c) -> @value += c; 4
				eof: ->
					@param is '' or
						@obj[@param] = (@value is '') or
							isFinite(f = parseFloat @value) and not isNaN(f) and f or @value
			}
			# state 5: read a double-quoted value
			{
				'"': -> @next = 1; 9
				'\\': -> 7
				def: (c) -> @value += c; 5
				eof: -> throw new Error "Unclosed double-quote from \"#{@value.substring(0,10)} "; null
			}
			# state 6: read a single-quoted value
			{
				"'": -> @next = 1; 9
				'\\': -> 8
				def: (c) -> @value += c; 6
				eof: -> throw new Error "Unclosed single-quote from \'#{@value.substring(0,10)} "; null
			}
			# state 7: escape one value from inside a double-quote
			{
				def: (c) -> @value += c; 5
			}
			# state 8: escape one value from inside a single quote
			{
				def: (c) -> @value += c; 6
			}
			# state 9: end a value and go to state @next
			{
				enter: ->
					@param is '' or
						@obj[@param] = (@value is '') or
							isFinite(f = parseFloat @value) and not isNaN(f) and f or @value
					@param = @value = ''
					@next
			}
		]
		super table, debug

machine = new ArgumentMachine(require.main is module)
parseArguments = (str) ->
	machine.run(str, 0).obj

safeQuote = (s) ->
	return s
parseArgv = ->
	argv = process.argv.slice(2).map(safeQuote).join(' ')
	ret = parseArguments argv
	ret.quiet or= ret.q
	ret.verbose or= ret.v
	ret.force or= ret.f
	ret


Object.assign module.exports, { parseArguments, parseArgv }

if require.main is module
	testStr = """add --group admin-api --cd test/server --exec "(cd bin && bash -c 'node app.js')" --count 1 --grace 3000 --enable --port 9101"""
	testStr = """add --group runtime_api_pool --count 1 --cd bin --exec "node server/runtime-api/runtime-server.js" --port 8030 --grace 45000"""
	console.log parseArguments testStr
	# console.log machine.run.toString()
	console.log parseArgv()

