
describe 'down'
if it "$*" 'should do nothing if already stopped'; then
	check_init
	check_contains "`shep down 2>&1`" "Status: offline"
	pass
fi

if it "$*" 'should stop a started daemon'; then
	check_init
	check_up
	R="`shep down 2>&1`"
	echo -n "shep down: $R"
	dotsleep 1
	check_contains "`shep status`" "Status: offline"
	pass
fi

if it "$*" 'should stop all started children'; then
	C="$(pwd)/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $TEST_NAME' --count 1 --port $(next_port)" > $C
	echo "add --group testB --exec 'node echo_server.js B $TEST_NAME' --count 1 --port $(next_port)" >> $C
	echo "start" >> $C
	check_up
	check_contains "`shep down`" "Stopped"
	sleep 2
	check_no_process "node echo_server.js A $TEST_NAME"
	check_no_process "node echo_server.js B $TEST_NAME"
	check_contains "`shep status`" "Status: offline"
	pass
fi
