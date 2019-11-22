
describe 'restart'
if it "$*" 'should restart - everything'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	L="$TEMP_PATH/.shep/log"
	check_init
	echo "$echo_server" > echo_server.js
	echo "$simple_worker" > simple_worker.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 1 --port 19011" > $C
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> $C
	echo "add --group testC --exec 'node echo_server.js C $$' --count 1 --port 9022" >> $C
	echo "add --group testD --exec 'node echo_server.js D $$' --count 1 --port 9023" >> $C
	echo "add --group testE --exec 'node echo_server.js E $$' --count 1 --port 9024" >> $C
	echo "disable --group testE" >> $C
	echo "add --group testF --exec 'node simple_worker.js F $$' --count 1" >> $C
	echo "add --group testG --exec 'node simple_worker.js G $$' --count 1" >> $C
	# echo "nginx --enable --reload-cmd 'echo'" >> $C
	check_up
	check_contains "`shep start`" "Starting everything"
	dotsleep 3
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_process "echo_server.js C $$"
	check_process "echo_server.js D $$"
	check_no_process "echo_server.js E $$"
	check_process "simple_worker.js F $$"
	check_process "simple_worker.js G $$"
	dotsleep 3
	check_contains "`shep restart`" "Restarting everything"
	dotsleep 3
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_process "echo_server.js C $$"
	check_process "echo_server.js D $$"
	check_no_process "echo_server.js E $$"
	check_process "simple_worker.js F $$"
	check_process "simple_worker.js G $$"
	check_down
	pass
fi
