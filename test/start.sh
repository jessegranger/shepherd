
describe 'start'
if it "$*" 'should start - everything'; then
	cd $(mkdeploy)
	C="$(pwd)/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $TEST_NAME' --count 1 --port $(next_port)" > $C
	echo "add --group testB --exec 'node echo_server.js B $TEST_NAME' --count 1 --port $(next_port)" >> $C
	check_up
	check_contains "`shep start`" "Starting everything"
	sleep 1
	check_process "echo_server.js A $TEST_NAME"
	check_process "echo_server.js B $TEST_NAME"
	check_down
	pass
fi

if it "$*" 'should start - workers'; then
	cd $(mkdeploy)
	C="$(pwd)/.shep/config"
	check_init
	echo "$simple_worker" > simple_worker.js
	echo "add --group testA --exec 'node simple_worker.js A $TEST_NAME' --count 1" > $C
	echo "add --group testB --exec 'node simple_worker.js B $TEST_NAME' --count 1" >> $C
	check_up
	check_contains "`shep start`" "Starting everything"
	sleep 1
	check_process "simple_worker.js A $TEST_NAME"
	check_process "simple_worker.js B $TEST_NAME"
	check_down
	pass
fi

if it "$*" 'should start - groups'; then
	cd $(mkdeploy)
	C="$(pwd)/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $TEST_NAME' --count 1 --port $(next_port)" > $C
	echo "add --group testB --exec 'node echo_server.js B $TEST_NAME' --count 1 --port $(next_port)" >> $C
	check_up
	check_contains "`shep start --group testA`" "Starting group testA"
	dotsleep 2
	check_process "echo_server.js A $TEST_NAME"
	check_no_process "echo_server.js B $TEST_NAME"
	check_contains "`shep start --group testB`" "Starting group testB"
	dotsleep 2
	check_process "echo_server.js A $TEST_NAME"
	check_process "echo_server.js B $TEST_NAME"
	check_down
	pass
fi

if it "$*" 'should start - instances'; then
	cd $(mkdeploy)
	C="$(pwd)/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js A $TEST_NAME' --count 3 --port $(next_port)" > $C
	check_up
	check_contains "`shep start --instance test-1`" "Starting instance test-1"
	check_process "echo_server.js A $TEST_NAME"
	check_contains "`shep stop --instance test-1`" "Stopping instance test-1"
	dotsleep 2
	check_no_process "echo_server.js A $TEST_NAME"
	check_contains "`shep start --instance test-2`" "Starting instance test-2"
	check_process "echo_server.js A $TEST_NAME"
	check_down
	pass
fi

if it "$*" 'should keep instance up if it dies'; then
	cd $(mkdeploy)
	C="$(pwd)/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js A $TEST_NAME' --count 3 --port $(next_port)" > $C
	check_up
	check_contains "`shep start --instance test-1`" "Starting instance test-1"
	check_contains "`shep status test-1`" " started"
	P=`shep status test-1 | grep test-1 | awk '{print $2}'`
	check [ -n "$P" ]
	kill $P
	check [ "$?" -eq 0 ]
	dotsleep 4
	O=$(shep status test-1)
	check_contains "$O" " started"
	check_contains "$O" " [0-9]*s"
	check_down
	pass
fi
