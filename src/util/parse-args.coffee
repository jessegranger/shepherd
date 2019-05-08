#!/usr/bin/env coffee
#
$ = require 'bling'

machine = $.StateMachine

count = (substr, str, i = 0) ->
	j = -1
	ret = 0
	while -1 < j = str.indexOf substr, i
		i += j + 1
		ret += 1
	return ret

class ArgumentMachine extends $.StateMachine
	constructor: (debug=false) ->
		table = [
			# state 0: init
			enter: ->
				@_ = ''
				@obj = { _: [ ] }
				@param = @value = ''
				1
			# state 1: read unknown
			{
				'-': ->
					if @_.length
						@_ += '-'
						return 1
					else
						return 2
				' ': ->
					@_.length and @obj._.push @_
					@_ = ''; 1
				def: (c) -> @_ += c; 1
				eof: -> @end()
			}
			# state 2: start reading a -p or --param
			{
				'-': -> 3 # read a full --param
				' ': -> 4
				def: (c) -> @param += c; 2
				eof: -> @end()
			}
			# state 3: read a full --param
			{
				' ': -> 4 # read a value
				def: (c) -> @param += c; 3
				eof: -> @end()
			}
			# state 4: read value after -p if there is one
			{
				' ': -> @next = 1; 9
				'-': -> (@value is '') and (@next = 2; 9) or (@value += '-'; 4)
				'"': -> 5
				"'": -> 6
				def: (c) -> @value += c; 4
				eof: -> @end()
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
					@endParam()
					@param = @value = ''
					@next
			}
		]
		super table, debug
	end: ->
		@_.length and @obj._.push @_
		@endParam()
	endParam: ->
		@param is '' or
			@obj[@param] = (@value is '') or
				isFinite(f = parseFloat @value) and not isNaN(f) and count(".", @value) < 2 and f or @value

machine = new ArgumentMachine(require.main is module)
parseArguments = (str) ->
	machine.run(str, 0).obj

parsed = null
parseArgv = ->
	if parsed? then return parsed
	argv = process.argv.slice(2).join(' ')
	ret = parseArguments argv
	ret.quiet or= ret.q
	ret.verbose or= ret.v
	ret.force or= ret.f
	parsed = ret

Object.assign module.exports, { parseArguments, parseArgv }

if require.main is module
	console.log machine.run.toString()
	console.log parseArgv()
	console.log ("80.80.").indexOf(".", 0)
	console.log ("80.80.").indexOf(".", 3)
	console.log count(".", "80.80.")

