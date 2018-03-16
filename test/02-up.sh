
describe 'up'
it 'should start the daemon'
	cd $(mkdeploy)
	check_init
	check_up
	check_down
	pass

it 'can add and start from the config'
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js $$' --count 1 --port 9011" > "$TEMP_PATH/.shepherd/config"
	echo "start" >> "$TEMP_PATH/.shepherd/config"
	check_up
	check_process "echo_server.js $$"
	check_down
	pass

