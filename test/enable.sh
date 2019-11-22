
describe 'enable'
if it "$*" 'should enable - everything'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 1 --port 19011" > $C
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> $C
	echo "disable" >> $C
	echo "start" >> $C
	check_up
	check_contains "`shep status testA-0`" " disabled"
	check_contains "`shep status testB-0`" " disabled"
	check_contains "`shep enable`" "Enabling everything"
	sleep 1
	check_contains "`shep status testA-0`" " started"
	check_contains "`shep status testB-0`" " started"
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_down
	pass
fi

if it "$*" 'should enable - groups'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 1 --port 19011" > $C
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> $C
	echo "disable" >> $C
	echo "start" >> $C
	check_up
	check_contains "`shep enable --group testA`" "Enabling group testA"
	check_contains "`shep status testA-0`" " started"
	check_contains "`shep status testB-0`" " disabled"
	check_contains "`shep enable --group testB`" "Enabling group testB"
	check_contains "`shep status testB-0`" " started"
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_down
	pass
fi

if it "$*" 'should enable - instances'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 3 --port 19011" > $C
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> $C
	echo "disable --group testA" >> $C
	echo "start" >> $C
	check_up
	check_contains "`shep enable --instance testA-1`" "Enabling instance testA-1"
	check_contains "`shep status testA-0`" " disabled"
	check_contains "`shep status testA-1`" " started"
	check_contains "`shep status testA-2`" " disabled"
	check_contains "`shep enable --instance testA-2`" "Enabling instance testA-2"
	check_contains "`shep status testA-2`" " started"
	check_contains "`shep enable --instance testA-0`" "Enabling instance testA-0"
	check_contains "`shep status testA-0`" " started"
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_down
	pass
fi
