
describe 'restart'
if it "$*" 'should restart - everything'; then
	cd $(mkdeploy)
	C="$(pwd)/.shep/config"
	L="$(pwd)/.shep/log"
	check_init
	echo "$echo_server" > echo_server.js
	echo "$simple_worker" > simple_worker.js
	echo "add --group testA --exec 'node echo_server.js A $TEST_NAME' --count 1 --port $(next_port)" > $C
	echo "add --group testB --exec 'node echo_server.js B $TEST_NAME' --count 1 --port $(next_port)" >> $C
	echo "add --group testC --exec 'node echo_server.js C $TEST_NAME' --count 1 --port $(next_port)" >> $C
	echo "add --group testD --exec 'node echo_server.js D $TEST_NAME' --count 1 --port $(next_port)" >> $C
	echo "disable --group testD" >> $C
	echo "add --group testE --exec 'node simple_worker.js F $TEST_NAME' --count 1" >> $C
	echo "add --group testF --exec 'node simple_worker.js G $TEST_NAME' --count 1" >> $C
	# echo "nginx --enable --reload-cmd 'echo'" >> $C
	check_up
	check_contains "`shep start`" "Starting everything"
	dotsleep 3
	check_process "echo_server.js A $TEST_NAME"
	check_process "echo_server.js B $TEST_NAME"
	check_process "echo_server.js C $TEST_NAME"
	check_no_process "echo_server.js D $TEST_NAME"
	check_process "simple_worker.js F $TEST_NAME"
	check_process "simple_worker.js G $TEST_NAME"
	dotsleep 3
	check_contains "`shep restart`" "Restarting everything"
	dotsleep 3
	check_process "echo_server.js A $TEST_NAME"
	check_process "echo_server.js B $TEST_NAME"
	check_process "echo_server.js C $TEST_NAME"
	check_no_process "echo_server.js D $TEST_NAME"
	check_process "simple_worker.js F $TEST_NAME"
	check_process "simple_worker.js G $TEST_NAME"
	check_down
	pass
fi
