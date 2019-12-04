
describe 'up'
if it "$*" 'should start the daemon'; then
	cd $(mkdeploy)
	check_init
	check_up
	check_down
	pass
fi

if it "$*" 'can add and start from the config'; then
	cd $(mkdeploy)
	C="$(pwd)/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js $TEST_NAME' --count 1 --port $(next_port)" > $C
	echo "start" >> $C
	check_up
	check_process "echo_server.js $TEST_NAME"
	check_down
	pass
fi
