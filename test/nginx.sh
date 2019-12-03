
describe 'nginx'
if it "$*" 'should be able to --disable'; then
	cd $(mkdeploy)
	C="$(pwd)/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js A $TEST_NAME' --count 1 --port $(next_port)" > $C
	check_up
	check_contains "`shep nginx --disable`" "nginx configuration updated"
	check_file_contains "$C" "nginx --disable"
	check_down
	pass
fi

if it "$*" 'should be able to --enable'; then
	cd $(mkdeploy)
	C="$(pwd)/.shep/config"
	check_init
	echo "add --group test --exec 'node echo_server.js A $TEST_NAME' --count 1 --port $(next_port)" > $C
	check_up
	check_contains "`shep nginx --enable`" "nginx configuration updated"
	check_file_contains "$C" "nginx --enable"
	check [ -e "$(pwd)/.shep/nginx.template" ]
	check_down
	pass
fi

if it "$*" 'should use nginx.template to write nginx'; then
	cd $(mkdeploy)
	C="$(pwd)/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	C="$(pwd)/.shep/config"
	PORT_ONE=$(next_port)
	echo "add --group test --exec 'node echo_server.js A $TEST_NAME' --count 1 --port $PORT_ONE" > $C
	echo "nginx --group test --port 8881 --name www.example.com --ssl_cert some_cert --ssl_key some_key" >> $C
	echo "nginx --enable --reload-cmd echo" >> $C
	echo "start" >> $C
	T="$(pwd)/.shep/nginx.template"
	echo "{{name}}:{{public_name}}:{{public_port}}:{{ssl_cert}}:{{ssl_key}}:{{#each group}}{{ this.port }}{{/each}}" > $T
	check_up
	dotsleep 2
	N="$(pwd)/.shep/nginx"
	check [ -e "$N" ]
	check_file_contains "$N" "test:www.example.com:8881:some_cert:some_key:$PORT_ONE"
	check_down
	pass
fi

if it "$*" 'should write nginx on status change'; then
	cd $(mkdeploy)
	C="$(pwd)/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	C="$(pwd)/.shep/config"
	PORT_ONE=$(next_port)
	PORT_TWO=$(next_port)
	echo "add --group test --exec 'node echo_server.js A $TEST_NAME' --count 2 --port $PORT_ONE" > $C
	echo "nginx --group test --port 8881 --name www.example.com --ssl_cert some_cert --ssl_key some_key" >> $C
	echo "nginx --enable --reload-cmd echo" >> $C
	echo "start" >> $C
	T="$(pwd)/.shep/nginx.template"
	echo "{{name}}:{{public_name}}:{{public_port}}:{{ssl_cert}}:{{ssl_key}}:{{#each group}} {{ this.port }}{{/each}}" > $T
	check_up
	dotsleep 2
	# cat "$(pwd)/.shep/log"
	N="$(pwd)/.shep/nginx"
	check [ -e $N ]
	check_file_contains "$N" "test:www.example.com:8881:some_cert:some_key: $PORT_ONE $PORT_TWO"
	check_contains "`shep stop test-1`" "Stopping instance test-1"
	dotsleep 2
	check_file_contains "$N" "test:www.example.com:8881:some_cert:some_key: $PORT_ONE"
	check_contains "`shep start test-1`" "Starting instance test-1"
	dotsleep 2
	check_file_contains "$N" "test:www.example.com:8881:some_cert:some_key: $PORT_ONE $PORT_TWO"
	check_down
	pass
fi

if it "$*" 'should handle multiple groups'; then
	cd $(mkdeploy)
	C="$(pwd)/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	PORT_ONE=$(next_port)
	PORT_TWO=$(next_port)
	PORT_THREE=$(next_port)
	PORT_FOUR=$(next_port)
	echo "add --group test --exec 'node echo_server.js A $TEST_NAME' --count 2 --port $PORT_ONE" > $C
	echo "add --group twice --exec 'node echo_server.js B $TEST_NAME' --count 2 --port $PORT_THREE" >> $C
	echo "nginx --group test --port 8881 --name www.example.com --ssl_cert some_cert --ssl_key some_key" >> $C
	echo "nginx --group twice --port 8882 --name app.example.com --ssl_cert some_cert2 --ssl_key some_key2" >> $C
	echo "nginx --enable --reload-cmd echo" >> $C
	echo "start" >> $C
	T="$(pwd)/.shep/nginx.template"
	echo "{{name}}:{{public_name}}:{{public_port}}:{{ssl_cert}}:{{ssl_key}}:{{#each group}} {{ this.port }}{{/each}}" > $T
	check_up
	dotsleep 2
	# cat "$(pwd)/.shep/log"
	N="$(pwd)/.shep/nginx"
	check [ -e $N ]
	check_file_contains "$N" "test:www.example.com:8881:some_cert:some_key: $PORT_ONE $PORT_TWO"
	check_file_contains "$N" "twice:app.example.com:8882:some_cert2:some_key2: $PORT_THREE $PORT_FOUR"
	check_contains "`shep stop test-1`" "Stopping instance test-1"
	check_contains "`shep stop twice-1`" "Stopping instance twice-1"
	dotsleep 2
	check_file_contains "$N" "test:www.example.com:8881:some_cert:some_key: $PORT_ONE"
	check_file_contains "$N" "twice:app.example.com:8882:some_cert2:some_key2: $PORT_THREE"
	check_contains "`shep start test-1`" "Starting instance test-1"
	check_contains "`shep start twice-1`" "Starting instance twice-1"
	dotsleep 2
	check_file_contains "$N" "test:www.example.com:8881:some_cert:some_key: $PORT_ONE $PORT_TWO"
	check_file_contains "$N" "twice:app.example.com:8882:some_cert2:some_key2: $PORT_THREE $PORT_FOUR"
	check_down
	pass
fi
