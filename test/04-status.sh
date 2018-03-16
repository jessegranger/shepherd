
describe 'status'
it 'should do nothing if daemon is stopped'
	cd $(mkdeploy)
	shep init -q
	check [ "$?" -eq 0 ]
	shep status | grep -q "not running"
	check [ "$?" -eq 0 ]
	pass

it 'should list - unstarted'
	cd $(mkdeploy)
	shep init -q
	check [ "$?" -eq 0 ]
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js $$' --count 1 --port 9011" > "$TEST_PATH/.shepherd/config"
	shep up | grep -q "Starting"
	check [ "$?" -eq 0 ]
	sleep 2
	check [ -e "$TEST_PATH/.shepherd/socket" ]
	check [ -e "$TEST_PATH/.shepherd/pid" ]
	check [ -e "$TEST_PATH/.shepherd/log" ]
	ps -eo pid,ppid,command | grep -q "echo_server.js $$"
	check [ "$?" -eq 0 ]
	OUTPUT=$(shep status)
	check [ "$?" -eq 0 ]
	echo "$OUTPUT" | grep -q "Status: online"
	check [ "$?" -eq 0 ]
	echo "$OUTPUT" | grep -q "Groups: 1"
	check [ "$?" -eq 0 ]
	echo "$OUTPUT" | grep -q "test-0"
	check [ "$?" -eq 0 ]
	echo "$OUTPUT" | grep -q " unstarted"
	check [ "$?" -eq 0 ]
	shep down | grep -q "Stopping"
	check [ "$?" -eq 0 ]
	ps -eo pid,ppid,command | grep -v -q "echo_server.js $$"
	check [ "$?" -eq 0 ]
	pass

it 'should list - started'
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
	OUTPUT=$(shep status)
	check [ "$?" -eq 0 ]
	echo "$OUTPUT" | grep -q "Status: online"
	check [ "$?" -eq 0 ]
	echo "$OUTPUT" | grep -q "Groups: 1"
	check [ "$?" -eq 0 ]
	echo "$OUTPUT" | grep -q "test-0"
	check [ "$?" -eq 0 ]
	echo "$OUTPUT" | grep -q " started"
	check [ "$?" -eq 0 ]
	shep down | grep -q "Stopping"
	check [ "$?" -eq 0 ]
	pass
