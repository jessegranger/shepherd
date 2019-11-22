
describe 'disable'
if it "$*" 'should disable - everything'; then
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
	check_contains "`shep disable`" "Disabling everything"
	sleep 1
	check_contains "`shep status testA-0`" " disabled"
	check_contains "`shep status testB-0`" " disabled"
	check_no_process "echo_server.js A $$"
	check_no_process "echo_server.js B $$"
	check_down
	pass
fi

if it "$*" 'should disable - groups'; then
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
	check_contains "`shep disable --group testA`" "Disabling group testA"
	check_contains "`shep status testA-0`" " disabled"
	check_contains "`shep status testB-0`" " started"
	check_contains "`shep disable --group testB`" "Disabling group testB"
	check_contains "`shep status testB-0`" " disabled"
	check_no_process "echo_server.js A $$"
	check_no_process "echo_server.js B $$"
	check_down
	pass
fi

if it "$*" 'should disable - instances'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 3 --port 19011" > $C
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> $C
	echo "start" >> $C
	check_up
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_contains "`shep disable --instance testA-1`" "Disabling instance testA-1" "shep disable --instance testA-1"
	sleep 1
	check_contains "`shep status testA-0`" " started" "shep status testA-0 should be started"
	check_contains "`shep status testA-1`" " disabled" "shep status testA-1 should be disabled"
	check_contains "`shep status testA-2`" " started" "shep status testA-2 should be started"
	check_contains "`shep disable --instance testA-2`" "Disabling instance testA-2" "shep disable --instance testA-2"
	sleep 1
	check_contains "`shep status testA-2`" " disabled" "shep status testA-2"
	check_contains "`shep disable --instance testA-0`" "Disabling instance testA-0" "shep disable --instance testA-0"
	check_contains "`shep status testA-0`" " disabled" "shep status testA-0"
	check_no_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_down
	pass
fi

if it "$*" 'start on a disabled instance does nothing'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 1 --port 19011" > $C
	echo "disable --group testA" >> $C
	echo "start" >> $C
	check_up
	check_contains "`shep status testA-0`" " disabled"
	check_contains "`shep start --instance testA-0`" "Starting instance testA-0"
	check_contains "`shep status testA-0`" " disabled"
	check_no_process "echo_server.js A $$"
	check_down
	pass
fi
