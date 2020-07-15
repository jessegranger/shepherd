
describe 'health'
if it "$*" 'should check status code'; then
	C="$(pwd)/.shep/config"
	check_init
	echo "$bad_status_server" > bad_status_server.js
	echo "add --group bad_status --exec 'node bad_status_server.js A $TEST_NAME' --count 1 --port $(next_port)" > $C
	echo "health --group bad_status --path / --status 200 --interval 1" >> $C
	echo "start" >> $C
	check_up
	dotsleep 4
	L="$(pwd)/.shep/log"
	check_file_contains "$L" "Health check failed (bad status: 500)"
	check_down
	pass
fi
