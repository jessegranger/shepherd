{ $, echo, warn, verbose, required, echoResponse } = require '../common'
{ addGroup, removeGroup } = require "../daemon/groups"
addAction = require './add'
removeAction = require './remove'

Object.assign module.exports, {
	options: addAction.options
	toMessage: (cmd) ->
		Object.assign addAction.toMessage(cmd), { c: 'replace' }
	onMessage: (msg, client, cb) ->
		removeAction.onMessage { g: msg.g }, null, =>
			addAction.onMessage msg, client, cb
	onResponse: echoResponse
}
