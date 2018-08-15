
Object.assign module.exports, { Actions: {
	add:     require './actions/add'
	remove:  require './actions/remove'
	replace: require './actions/replace'
	start:   require './actions/start'
	stop:    require './actions/stop'
	restart: r=require './actions/restart'
	reload:  r,
	status:  s=require "./actions/status"
	stats:   s
	stat:    s
	disable: require './actions/disable'
	enable:  require './actions/enable'
	scale:   require './actions/scale'
	log:     require './actions/log'
	health:  require './actions/health'
	nginx:   require './actions/nginx'
	config:  require './actions/config'
}}
