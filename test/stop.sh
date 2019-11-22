describe 'stop'
if it "$*" 'should stop - everything'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js $$' --count 1 --port 19011" > $C
	echo "start" >> $C
	check_up
	check_process "echo_server.js $$"
	check_contains "`shep stop`" "Stopping everything"
	dotsleep 2
	check_no_process "echo_server.js $$"
	check_down
	pass
fi

if it "$*" 'should stop - groups'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 1 --port 19011" > $C
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> $C
	echo "start" >> $C
	check_up
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_contains "`shep stop --group testA`" "Stopping group testA"
	dotsleep 2
	check_no_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_contains "`shep stop --group testB`" "Stopping group testB"
	dotsleep 2
	check_no_process "echo_server.js A $$"
	check_no_process "echo_server.js B $$"
	check_down
	pass
fi

if it "$*" 'should stop - instances'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js $$' --count 2 --port 19011" > $C
	echo "start" >> $C
	check_up
	check_process "echo_server.js $$"
	check_contains "`shep stop --instance test-1`" "Stopping instance test-1"
	check_process "echo_server.js $$"
	check_contains "`shep stop --instance test-0`" "Stopping instance test-0"
	dotsleep 2
	check_no_process "echo_server.js $$"
	check_down
	pass
fi
