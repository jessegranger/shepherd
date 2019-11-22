
describe 'up'
if it "$*" 'should start the daemon'; then
	cd $(mkdeploy)
	check_init
	check_up
	check_down
	pass
fi

if it "$*" 'can add and start from the config'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js $$' --count 1 --port 19011" > $C
	echo "start" >> $C
	check_up
	check_process "echo_server.js $$"
	check_down
	pass
fi
