
describe 'status'
if it "$*" 'should do nothing if daemon is stopped'; then
	check_init
	check_contains "`shep status`" "Status: offline"
	pass
fi

if it "$*" 'should list - unstarted'; then
	C="$(pwd)/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js $TEST_NAME' --count 1 --port $(next_port)" > $C
	check_up
	OUTPUT=$(shep status)
	check [ "$?" -eq 0 ]
	check_contains "$OUTPUT" "Status: online"
	check_contains "$OUTPUT" "Groups: 1"
	check_contains "$OUTPUT" "test-0"
	check_contains "$OUTPUT" " unstarted"
	check_down
	pass
fi

if it "$*" 'should list - started'; then
	C="$(pwd)/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js $TEST_NAME' --count 1 --port $(next_port)" > $C
	echo "start" >> $C
	check_up
	check_process "echo_server.js $TEST_NAME" || cat "$(pwd)/.shep/log"
	OUTPUT=$(shep status)
	check [ "$?" -eq 0 ]
	check_contains "$OUTPUT" "Status: online"
	check_contains "$OUTPUT" "Groups: 1"
	check_contains "$OUTPUT" "test-0"
	check_contains "$OUTPUT" " started"
	check_down
	pass
fi

if it "$*" 'can show status of a group'; then
	C="$(pwd)/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group groupA --exec 'node echo_server.js A $TEST_NAME' --count 1 --port $(next_port)" > $C
	echo "add --group groupB --exec 'node echo_server.js B $TEST_NAME' --count 1 --port $(next_port)" >> $C
	echo "start" >> $C
	check_up
	check_process "echo_server.js A $TEST_NAME"
	OUTPUT=$(shep status --group groupA)
	check [ "$?" -eq 0 ]
	check_contains "$OUTPUT" "Status: online"
	check_contains "$OUTPUT" "Groups: 1"
	check_contains "$OUTPUT" "groupA-0"
	check_contains "$OUTPUT" " started"
	check_down
	pass
fi

if it "$*" 'can show status of an instance'; then
	C="$(pwd)/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group groupA --exec 'node echo_server.js A $TEST_NAME' --count 1 --port $(next_port)" > $C
	echo "add --group groupB --exec 'node echo_server.js B $TEST_NAME' --count 1 --port $(next_port)" >> $C
	echo "start" >> $C
	check_up
	check_process "echo_server.js A $TEST_NAME"
	OUTPUT=$(shep status --instance groupB-0)
	check [ "$?" -eq 0 ]
	check_contains "$OUTPUT" "Status: online"
	check_contains "$OUTPUT" "Groups: 2"
	check_contains "$OUTPUT" "groupB-0"
	check_contains "$OUTPUT" " started"
	check_down
	pass
fi
