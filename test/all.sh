#!/usr/bin/env bash
set -e
ROOT=$(pwd)/test

source $ROOT/common.sh

describe "init"
if it "$*" "should create a .shep folder"; then
	cd $(mkdeploy)
	check [ "$?" -eq 0 ]
	shep init > /dev/null
	check [ -d "$TEMP_PATH/.shep" ]
	pass
fi

if it "$*" "should copy a .shep/defaults file"; then
	cd $(mkdeploy)
	check [ -n "$TEMP_PATH" -a -d "$TEMP_PATH" ]
	mkdir -p "$TEMP_PATH/.shep/"
	echo "xyzzy" > "$TEMP_PATH/.shep/defaults"
	shep init > /dev/null
	check [ `cat "$TEMP_PATH/.shep/config"` = "xyzzy" ]
	pass
fi

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
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js $$' --count 1 --port 19011" > "$TEMP_PATH/.shep/config"
	echo "start" >> "$TEMP_PATH/.shep/config"
	check_up
	check_process "echo_server.js $$"
	check_down
	pass
fi

describe 'down'
if it "$*" 'should do nothing if already stopped'; then
	cd $(mkdeploy)
	check_init
	shep down | grep -q "Status: offline"
	check [ "$?" -eq 0 ]
	pass
fi

if it "$*" 'should stop a started daemon'; then
	cd $(mkdeploy)
	check_init
	check_up
	shep down | grep -q "Status: offline"
	check [ "$?" -eq 0 ]
	shep status | grep -q "Status: offline"
	check [ "$?" -eq 0 ]
	pass
fi

describe 'status'
if it "$*" 'should do nothing if daemon is stopped'; then
	cd $(mkdeploy)
	check_init
	shep status | grep -q "Status: offline"
	check [ "$?" -eq 0 ]
	pass
fi

if it "$*" 'should list - unstarted'; then
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js $$' --count 1 --port 19011" > "$TEMP_PATH/.shep/config"
	check_up
	OUTPUT=$(shep status)
	check [ "$?" -eq 0 ]
	echo "$OUTPUT" | grep -q "Status: online"
	check [ "$?" -eq 0 ]
	echo "$OUTPUT" | grep -q "Groups: 1"
	check [ "$?" -eq 0 ]
	echo "$OUTPUT" | grep -q "test-0"
	check [ "$?" -eq 0 ]
	echo "$OUTPUT" | grep -q " unstarted"
	check [ "$?" -eq 0 ]
	check_down
	pass
fi

if it "$*" 'should list - started'; then
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js $$' --count 1 --port 19011" > "$TEMP_PATH/.shep/config"
	echo "start" >> "$TEMP_PATH/.shep/config"
	check_up
	check_process "echo_server.js $$"
	OUTPUT=$(shep status)
	check [ "$?" -eq 0 ]
	echo "$OUTPUT" | grep -q "Status: online"
	check [ "$?" -eq 0 ]
	echo "$OUTPUT" | grep -q "Groups: 1"
	check [ "$?" -eq 0 ]
	echo "$OUTPUT" | grep -q "test-0"
	check [ "$?" -eq 0 ]
	echo "$OUTPUT" | grep -q " started"
	check [ "$?" -eq 0 ]
	check_down
	pass
fi

describe 'stop'
if it "$*" 'should stop - everything'; then
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js $$' --count 1 --port 19011" > "$TEMP_PATH/.shep/config"
	echo "start" >> "$TEMP_PATH/.shep/config"
	check_up
	check_process "echo_server.js $$"
	shep stop | grep -q "Stopping everything"
	check [ "$?" -eq 0 ]
	check_down
	pass
fi

if it "$*" 'should stop - groups'; then
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 1 --port 19011" > "$TEMP_PATH/.shep/config"
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> "$TEMP_PATH/.shep/config"
	echo "start" >> "$TEMP_PATH/.shep/config"
	check_up
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	shep stop --group testA | grep -q "Stopping group testA"
	check [ "$?" -eq 0 ]
	check_no_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	shep stop --group testB | grep -q "Stopping group testB"
	check [ "$?" -eq 0 ]
	check_no_process "echo_server.js A $$"
	check_no_process "echo_server.js B $$"
	check_down
	pass
fi

if it "$*" 'should stop - instances'; then
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js $$' --count 2 --port 19011" > "$TEMP_PATH/.shep/config"
	echo "start" >> "$TEMP_PATH/.shep/config"
	check_up
	check_process "echo_server.js $$"
	shep stop --instance test-1 | grep -q "Stopping instance test-1"
	check [ "$?" -eq 0 ]
	check_process "echo_server.js $$"
	shep stop --instance test-0 | grep -q "Stopping instance test-0"
	check [ "$?" -eq 0 ]
	check_no_process "echo_server.js $$"
	check_down
	pass
fi

describe 'start'
if it "$*" 'should start - everything'; then
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 1 --port 19011" > "$TEMP_PATH/.shep/config"
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> "$TEMP_PATH/.shep/config"
	check_up
	shep start | grep -q "Starting everything"
	check [ "$?" -eq 0 ]
	sleep 1
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_down
	pass
fi

if it "$*" 'should start - groups'; then
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 1 --port 19011" > "$TEMP_PATH/.shep/config"
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> "$TEMP_PATH/.shep/config"
	check_up
	shep start --group testA | grep -q "Starting group testA"
	check [ "$?" -eq 0 ]
	check_process "echo_server.js A $$"
	check_no_process "echo_server.js B $$"
	shep start --group testB | grep -q "Starting group testB"
	check [ "$?" -eq 0 ]
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_down
	pass
fi

if it "$*" 'should start - instances'; then
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js A $$' --count 3 --port 19011" > "$TEMP_PATH/.shep/config"
	check_up
	shep start --instance test-1 | grep -q "Starting instance test-1"
	check [ "$?" -eq 0 ]
	check_process "echo_server.js A $$"
	shep stop --instance test-1 | grep -q "Stopping instance test-1"
	check [ "$?" -eq 0 ]
	check_no_process "echo_server.js A $$"
	shep start --instance test-2 | grep -q "Starting instance test-2"
	check [ "$?" -eq 0 ]
	check_process "echo_server.js A $$"
	check_down
	pass
fi

if it "$*" 'should keep instance up if it dies'; then
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js A $$' --count 3 --port 19011" > "$TEMP_PATH/.shep/config"
	check_up
	shep start --instance test-1 | grep -q "Starting instance test-1"
	check [ "$?" -eq 0 ]
	shep status | grep "test-1" | grep -q " started"
	check [ "$?" -eq 0 ]
	kill `shep status | grep "test-1" | awk '{print $2}'`
	check [ "$?" -eq 0 ]
	sleep 4
	shep status | grep "test-1" | grep -q " started"
	check [ "$?" -eq 0 ]
	shep status | grep "test-1" | grep -q " [0-9]*s"
	check [ "$?" -eq 0 ]
	check_down
	pass
fi

if it "$*" 'should handle an instant crashing process'; then
	cd $(mkdeploy)
	check_init
	echo "process.exit(1)" > server.js
	echo "$echo_server" > echo_server.js
	echo "add --group crash --exec 'node server.js $$' --count 1" > "$TEMP_PATH/.shep/config"
	echo "add --group echo --exec 'node echo_server.js $$' --count 2 --port 19011" >> "$TEMP_PATH/.shep/config"
	check_up
	shep start --instance crash-0 | grep -q "Starting instance crash-0"
	check [ "$?" -eq 0 ]
	sleep 1
	shep status | grep "crash-0" | grep -q " waiting 400"
	check [ "$?" -eq 0 ]
	shep start --instance echo-0 | grep -q "Starting instance echo-0"
	check [ "$?" -eq 0 ]
	sleep 1
	shep status | grep "crash-0" | grep -q " waiting 400"
	check [ "$?" -eq 0 ]
	shep status | grep "echo-0" | grep -q " started"
	check [ "$?" -eq 0 ]
	check_down
	pass
fi

describe 'disable'
if it "$*" 'should disable - everything'; then
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 1 --port 19011" > "$TEMP_PATH/.shep/config"
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> "$TEMP_PATH/.shep/config"
	echo "start" >> "$TEMP_PATH/.shep/config"
	check_up
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	shep disable | grep -q "Disabling everything"
	check [ "$?" -eq 0 ]
	shep status | grep "testA-0" | grep -q " disabled"
	check [ "$?" -eq 0 ]
	shep status | grep "testB-0" | grep -q " disabled"
	check [ "$?" -eq 0 ]
	check_no_process "echo_server.js A $$"
	check_no_process "echo_server.js B $$"
	check_down
	pass
fi

if it "$*" 'should disable - groups'; then
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 1 --port 19011" > "$TEMP_PATH/.shep/config"
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> "$TEMP_PATH/.shep/config"
	echo "start" >> "$TEMP_PATH/.shep/config"
	check_up
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	shep disable --group testA | grep -q "Disabling group testA"
	check [ "$?" -eq 0 ]
	shep status | grep "testA-0" | grep -q " disabled"
	check [ "$?" -eq 0 ]
	shep status | grep "testB-0" | grep -q " started"
	check [ "$?" -eq 0 ]
	shep disable --group testB | grep -q "Disabling group testB"
	check [ "$?" -eq 0 ]
	shep status | grep "testB-0" | grep -q " disabled"
	check [ "$?" -eq 0 ]
	check_no_process "echo_server.js A $$"
	check_no_process "echo_server.js B $$"
	check_down
	pass
fi

if it "$*" 'should disable - instances'; then
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 3 --port 19011" > "$TEMP_PATH/.shep/config"
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> "$TEMP_PATH/.shep/config"
	echo "start" >> "$TEMP_PATH/.shep/config"
	check_up
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	shep disable --instance testA-1 | grep -q "Disabling instance testA-1"
	check [ "$?" -eq 0 ]
	shep status | grep "testA-0" | grep -q " started"
	check [ "$?" -eq 0 ]
	shep status | grep "testA-1" | grep -q " disabled"
	check [ "$?" -eq 0 ]
	shep status | grep "testA-2" | grep -q " started"
	check [ "$?" -eq 0 ]
	shep disable --instance testA-2 | grep -q "Disabling instance testA-2"
	check [ "$?" -eq 0 ]
	shep status | grep "testA-2" | grep -q " disabled"
	check [ "$?" -eq 0 ]
	shep disable --instance testA-0 | grep -q "Disabling instance testA-0"
	check [ "$?" -eq 0 ]
	shep status | grep "testA-0" | grep -q " disabled"
	check [ "$?" -eq 0 ]
	check_no_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_down
	pass
fi

if it "$*" 'start on a disabled instance does nothing'; then
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 1 --port 19011" > "$TEMP_PATH/.shep/config"
	echo "disable --group testA" >> "$TEMP_PATH/.shep/config"
	echo "start" >> "$TEMP_PATH/.shep/config"
	check_up
	shep status | grep "testA-0" | grep -q " disabled"
	check [ "$?" -eq 0 ]
	shep start --instance testA-0 | grep -q "Starting instance testA-0"
	check [ "$?" -eq 0 ]
	shep status | grep "testA-0" | grep -q " disabled"
	check [ "$?" -eq 0 ]
	check_no_process "echo_server.js A $$"
	check_down
	pass
fi

describe 'enable'
if it "$*" 'should enable - everything'; then
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 1 --port 19011" > "$TEMP_PATH/.shep/config"
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> "$TEMP_PATH/.shep/config"
	echo "disable" >> "$TEMP_PATH/.shep/config"
	echo "start" >> "$TEMP_PATH/.shep/config"
	check_up
	shep status | grep "testA-0" | grep -q " disabled"
	check [ "$?" -eq 0 ]
	shep status | grep "testB-0" | grep -q " disabled"
	check [ "$?" -eq 0 ]
	shep enable | grep -q "Enabling everything"
	check [ "$?" -eq 0 ]
	sleep 1
	shep status | grep "testA-0" | grep -q " started"
	check [ "$?" -eq 0 ]
	shep status | grep "testB-0" | grep -q " started"
	check [ "$?" -eq 0 ]
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_down
	pass
fi

if it "$*" 'should enable - groups'; then
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 1 --port 19011" > "$TEMP_PATH/.shep/config"
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> "$TEMP_PATH/.shep/config"
	echo "disable" >> "$TEMP_PATH/.shep/config"
	echo "start" >> "$TEMP_PATH/.shep/config"
	check_up
	shep enable --group testA | grep -q "Enabling group testA"
	check [ "$?" -eq 0 ]
	shep status | grep "testA-0" | grep -q " started"
	check [ "$?" -eq 0 ]
	shep status | grep "testB-0" | grep -q " disabled"
	check [ "$?" -eq 0 ]
	shep enable --group testB | grep -q "Enabling group testB"
	check [ "$?" -eq 0 ]
	shep status | grep "testB-0" | grep -q " started"
	check [ "$?" -eq 0 ]
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_down
	pass
fi

if it "$*" 'should enable - instances'; then
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 3 --port 19011" > "$TEMP_PATH/.shep/config"
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> "$TEMP_PATH/.shep/config"
	echo "disable --group testA" >> "$TEMP_PATH/.shep/config"
	echo "start" >> "$TEMP_PATH/.shep/config"
	check_up
	shep enable --instance testA-1 | grep -q "Enabling instance testA-1"
	check [ "$?" -eq 0 ]
	shep status | grep "testA-0" | grep -q " disabled"
	check [ "$?" -eq 0 ]
	shep status | grep "testA-1" | grep -q " started"
	check [ "$?" -eq 0 ]
	shep status | grep "testA-2" | grep -q " disabled"
	check [ "$?" -eq 0 ]
	shep enable --instance testA-2 | grep -q "Enabling instance testA-2"
	check [ "$?" -eq 0 ]
	shep status | grep "testA-2" | grep -q " started"
	check [ "$?" -eq 0 ]
	shep enable --instance testA-0 | grep -q "Enabling instance testA-0"
	check [ "$?" -eq 0 ]
	shep status | grep "testA-0" | grep -q " started"
	check [ "$?" -eq 0 ]
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_down
	pass
fi

describe 'nginx'
if it "$*" 'should be able to --disable'; then
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js A $$' --count 1 --port 19011" > "$TEMP_PATH/.shep/config"
	check_up
	shep nginx --disable | grep -q "nginx configuration updated"
	check [ "$?" -eq 0 ]
	grep -q "nginx --disable" "$TEMP_PATH/.shep/config"
	check [ "$?" -eq 0 ]
	check_down
	pass
fi

if it "$*" 'should be able to --enable'; then
	cd $(mkdeploy)
	check_init
	echo "add --group test --exec 'node echo_server.js A $$' --count 1 --port 19011" > "$TEMP_PATH/.shep/config"
	check_up
	shep nginx --enable| grep -q "nginx configuration updated"
	check [ "$?" -eq 0 ]
	grep -q "nginx --enable" "$TEMP_PATH/.shep/config"
	check [ "$?" -eq 0 ]
	check [ -e "$TEMP_PATH/.shep/nginx.template" ]
	check_down
	pass
fi

if it "$*" 'should use nginx.template to write nginx'; then
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	C="$TEMP_PATH/.shep/config"
	echo "add --group test --exec 'node echo_server.js A $$' --count 1 --port 19011" > $C
	echo "nginx --group test --port 8881 --name www.example.com --ssl_cert some_cert --ssl_key some_key" >> $C
	echo "nginx --enable --reload-cmd echo" >> $C
	echo "start" >> $C
	T="$TEMP_PATH/.shep/nginx.template"
	echo "{{name}}:{{public_name}}:{{public_port}}:{{ssl_cert}}:{{ssl_key}}:{{#each group}}{{ this.port }}{{/each}}" > $T
	check_up
	sleep 2
	# cat "$TEMP_PATH/.shep/log"
	check [ -e "$TEMP_PATH/.shep/nginx" ]
	check [ "`cat "$TEMP_PATH/.shep/nginx"`" = "test:www.example.com:8881:::19011" ]
	check_down
	pass
fi

if it "$*" 'should write nginx on status change'; then
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	C="$TEMP_PATH/.shep/config"
	echo "add --group test --exec 'node echo_server.js A $$' --count 2 --port 19011" > $C
	echo "nginx --group test --port 8881 --name www.example.com --ssl_cert some_cert --ssl_key some_key" >> $C
	echo "nginx --enable --reload-cmd echo" >> $C
	echo "start" >> $C
	T="$TEMP_PATH/.shep/nginx.template"
	echo "{{name}}:{{public_name}}:{{public_port}}:{{ssl_cert}}:{{ssl_key}}:{{#each group}} {{ this.port }}{{/each}}" > $T
	check_up
	sleep 1
	# cat "$TEMP_PATH/.shep/log"
	N="$TEMP_PATH/.shep/nginx"
	check [ -e $N ]
	grep -q 'test:www.example.com:8881:some_cert:some_key: 19011 19012' $N || cat $N
	check [ "$?" -eq 0 ]
	shep stop test-1 | grep -q "Stopping instance test-1"
	check [ "$?" -eq 0 ]
	sleep 1
	grep -q 'test:www.example.com:8881:some_cert:some_key: 19011' $N
	check [ "$?" -eq 0 ]
	shep start test-1 | grep -q "Starting instance test-1"
	check [ "$?" -eq 0 ]
	sleep 1
	grep -q 'test:www.example.com:8881:some_cert:some_key: 19011 19012' $N
	check [ "$?" -eq 0 ]
	check_down
	pass
fi

if it "$*" 'should handle multiple groups'; then
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	C="$TEMP_PATH/.shep/config"
	echo "add --group test --exec 'node echo_server.js A $$' --count 2 --port 19011" > $C
	echo "add --group twice --exec 'node echo_server.js B $$' --count 2 --port 19021" >> $C
	echo "nginx --group test --port 8881 --name www.example.com --ssl_cert some_cert --ssl_key some_key" >> $C
	echo "nginx --group twice --port 8882 --name app.example.com --ssl_cert some_cert2 --ssl_key some_key2" >> $C
	echo "nginx --enable --reload-cmd echo" >> $C
	echo "start" >> $C
	T="$TEMP_PATH/.shep/nginx.template"
	echo "{{name}}:{{public_name}}:{{public_port}}:{{ssl_cert}}:{{ssl_key}}:{{#each group}} {{ this.port }}{{/each}}" > $T
	check_up
	sleep 1
	# cat "$TEMP_PATH/.shep/log"
	N="$TEMP_PATH/.shep/nginx"
	check [ -e $N ]
	grep -q 'test:www.example.com:8881:some_cert:some_key: 19011 19012' $N
	check [ "$?" -eq 0 ]
	grep -q 'twice:app.example.com:8882:some_cert2:some_key2: 19021 19022' $N
	check [ "$?" -eq 0 ]
	shep stop test-1 | grep -q "Stopping instance test-1"
	check [ "$?" -eq 0 ]
	shep stop twice-1 | grep -q "Stopping instance twice-1"
	check [ "$?" -eq 0 ]
	sleep 1
	grep -q 'test:www.example.com:8881:some_cert:some_key: 19011' $N
	check [ "$?" -eq 0 ]
	grep -q 'twice:app.example.com:8882:some_cert2:some_key2: 19021' $N
	check [ "$?" -eq 0 ]
	shep start test-1 | grep -q "Starting instance test-1"
	check [ "$?" -eq 0 ]
	shep start twice-1 | grep -q "Starting instance twice-1"
	check [ "$?" -eq 0 ]
	sleep 1
	grep -q 'test:www.example.com:8881:some_cert:some_key: 19011 19012' $N
	check [ "$?" -eq 0 ]
	grep -q 'twice:app.example.com:8882:some_cert2:some_key2: 19021 19022' $N
	check [ "$?" -eq 0 ]
	check_down
	pass
fi

exit 0
