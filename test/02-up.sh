
describe 'up'
it 'should start the daemon'
	cd $(mkdeploy)
	shep init -q
	check [ "$?" -eq 0 ]
	shep up | grep -q "Starting"
	check [ "$?" -eq 0 ]
	sleep 1
	check [ -e "$TEST_PATH/.shepherd/socket" ]
	check [ -e "$TEST_PATH/.shepherd/pid" ]
	check [ -e "$TEST_PATH/.shepherd/log" ]
	shep down | grep -q "Stopping"
	check [ "$?" -eq 0 ]
	pass

it 'can add and start from the config'
	cd $(mkdeploy)
	shep init -q
	check [ "$?" -eq 0 ]
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js $$' --count 1 --port 9011" > "$TEST_PATH/.shepherd/config"
	echo "start" >> "$TEST_PATH/.shepherd/config"
	shep up | grep -q "Starting"
	check [ "$?" -eq 0 ]
	sleep 1
	check [ -e "$TEST_PATH/.shepherd/socket" ]
	check [ -e "$TEST_PATH/.shepherd/pid" ]
	check [ -e "$TEST_PATH/.shepherd/log" ]
	ps -eo pid,ppid,command | grep -v grep | grep -q "echo_server.js $$"
	check [ "$?" -eq 0 ]
	shep down | grep -q "Stopping"
	check [ "$?" -eq 0 ]
	pass

