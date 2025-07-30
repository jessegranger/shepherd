
describe 'log'
if it "$*" 'should redirect output to default log file'; then
	C="$(pwd)/.shep/config"
	check_init
	echo "$simple_worker" > simple_worker.js
	echo "add --group testA --exec 'node simple_worker.js A $TEST_NAME' --count 1" > $C
	check_up
	check_contains "`shep start`" "Starting everything"
	sleep 1
	check_process "simple_worker.js A $TEST_NAME"
	sleep 5
	LOG_FILE="$(pwd)/.shep/log"
	check_file_contains $LOG_FILE "simple_worker is Working"
	check_down
	pass
fi
