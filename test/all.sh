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
	C="$TEMP_PATH/.shep/config"
	check [ -n "$TEMP_PATH" -a -d "$TEMP_PATH" ]
	mkdir -p "$TEMP_PATH/.shep/"
	echo "xyzzy" > "$TEMP_PATH/.shep/defaults"
	shep init > /dev/null
	check [ `cat $C` = "xyzzy" ]
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
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js $$' --count 1 --port 19011" > $C
	echo "start" >> $C
	check_up
	check_process "echo_server.js $$"
	check_down
	pass
fi

describe 'down'
if it "$*" 'should do nothing if already stopped'; then
	cd $(mkdeploy)
	check_init
	check_contains "`shep down`" "Status: offline"
	pass
fi

if it "$*" 'should stop a started daemon'; then
	cd $(mkdeploy)
	check_init
	check_up
	check_contains "`shep down`" "Status: offline"
	check_contains "`shep status`" "Status: offline"
	pass
fi

describe 'status'
if it "$*" 'should do nothing if daemon is stopped'; then
	cd $(mkdeploy)
	check_init
	check_contains "`shep status`" "Status: offline"
	pass
fi

if it "$*" 'should list - unstarted'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js $$' --count 1 --port 19011" > $C
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
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js $$' --count 1 --port 19011" > $C
	echo "start" >> $C
	check_up
	check_process "echo_server.js $$"
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
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group groupA --exec 'node echo_server.js A $$' --count 1 --port 19011" > $C
	echo "add --group groupB --exec 'node echo_server.js B $$' --count 1 --port 19021" >> $C
	echo "start" >> $C
	check_up
	check_process "echo_server.js A $$"
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
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group groupA --exec 'node echo_server.js A $$' --count 1 --port 19011" > $C
	echo "add --group groupB --exec 'node echo_server.js B $$' --count 1 --port 19021" >> $C
	echo "start" >> $C
	check_up
	check_process "echo_server.js A $$"
	OUTPUT=$(shep status --instance groupB-0)
	check [ "$?" -eq 0 ]
	check_contains "$OUTPUT" "Status: online"
	check_contains "$OUTPUT" "Groups: 2"
	check_contains "$OUTPUT" "groupB-0"
	check_contains "$OUTPUT" " started"
	check_down
	pass
fi

describe 'stop'
if it "$*" 'should stop - everything'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js $$' --count 1 --port 19011" > $C
	echo "start" >> $C
	check_up
	check_process "echo_server.js $$"
	check_contains "`shep stop`" "Stopping everything"
	check_down
	pass
fi

if it "$*" 'should stop - groups'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 1 --port 19011" > $C
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> $C
	echo "start" >> $C
	check_up
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_contains "`shep stop --group testA`" "Stopping group testA"
	check_no_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_contains "`shep stop --group testB`" "Stopping group testB"
	check_no_process "echo_server.js A $$"
	check_no_process "echo_server.js B $$"
	check_down
	pass
fi

if it "$*" 'should stop - instances'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js $$' --count 2 --port 19011" > $C
	echo "start" >> $C
	check_up
	check_process "echo_server.js $$"
	check_contains "`shep stop --instance test-1`" "Stopping instance test-1"
	check_process "echo_server.js $$"
	check_contains "`shep stop --instance test-0`" "Stopping instance test-0"
	check_no_process "echo_server.js $$"
	check_down
	pass
fi

describe 'start'
if it "$*" 'should start - everything'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 1 --port 19011" > $C
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> $C
	check_up
	check_contains "`shep start`" "Starting everything"
	sleep 1
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_down
	pass
fi

if it "$*" 'should start - groups'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 1 --port 19011" > $C
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> $C
	check_up
	check_contains "`shep start --group testA`" "Starting group testA"
	check_process "echo_server.js A $$"
	check_no_process "echo_server.js B $$"
	check_contains "`shep start --group testB`" "Starting group testB"
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_down
	pass
fi

if it "$*" 'should start - instances'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js A $$' --count 3 --port 19011" > $C
	check_up
	check_contains "`shep start --instance test-1`" "Starting instance test-1"
	check_process "echo_server.js A $$"
	check_contains "`shep stop --instance test-1`" "Stopping instance test-1"
	check_no_process "echo_server.js A $$"
	check_contains "`shep start --instance test-2`" "Starting instance test-2"
	check_process "echo_server.js A $$"
	check_down
	pass
fi

if it "$*" 'should keep instance up if it dies'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js A $$' --count 3 --port 19011" > $C
	check_up
	check_contains "`shep start --instance test-1`" "Starting instance test-1"
	check_contains "`shep status test-1`" " started"
	kill `shep status test-1 | awk '{print $2}'`
	check [ "$?" -eq 0 ]
	sleep 4
	O=$(shep status test-1)
	check_contains "$O" " started"
	check_contains "$O" " [0-9]*s"
	check_down
	pass
fi

if it "$*" 'should handle an instant crashing process'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	L="$TEMP_PATH/.shep/log"
	check_init
	echo "process.exit(1)" > server.js
	echo "$echo_server" > echo_server.js
	echo "add --group crash --exec 'node server.js $$' --count 1" > $C
	echo "add --group echo --exec 'node echo_server.js $$' --count 2 --port 19011" >> $C
	check_up
	check_contains "`shep start --instance crash-0`" "Starting instance crash-0"
	sleep 1
	check_file_contains "$L" "Process exited immediately"
	check_file_contains "$L" "Exit was not expected, restarting"
	check_contains "`shep start --instance echo-0`" "Starting instance echo-0"
	sleep 1
	check_contains "`shep status echo-0`" " started"
	check_down
	pass
fi

describe 'disable'
if it "$*" 'should disable - everything'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 1 --port 19011" > $C
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> $C
	echo "start" >> $C
	check_up
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_contains "`shep disable`" "Disabling everything"
	check_contains "`shep status testA-0`" " disabled"
	check_contains "`shep status testB-0`" " disabled"
	check_no_process "echo_server.js A $$"
	check_no_process "echo_server.js B $$"
	check_down
	pass
fi

if it "$*" 'should disable - groups'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 1 --port 19011" > $C
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> $C
	echo "start" >> $C
	check_up
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_contains "`shep disable --group testA`" "Disabling group testA"
	check_contains "`shep status testA-0`" " disabled"
	check_contains "`shep status testB-0`" " started"
	check_contains "`shep disable --group testB`" "Disabling group testB"
	check_contains "`shep status testB-0`" " disabled"
	check_no_process "echo_server.js A $$"
	check_no_process "echo_server.js B $$"
	check_down
	pass
fi

if it "$*" 'should disable - instances'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 3 --port 19011" > $C
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> $C
	echo "start" >> $C
	check_up
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_contains "`shep disable --instance testA-1`" "Disabling instance testA-1"
	check_contains "`shep status testA-0`" " started"
	check_contains "`shep status testA-1`" " disabled"
	check_contains "`shep status testA-2`" " started"
	check_contains "`shep disable --instance testA-2`" "Disabling instance testA-2"
	check_contains "`shep status testA-2`" " disabled"
	check_contains "`shep disable --instance testA-0`" "Disabling instance testA-0"
	check_contains "`shep status testA-0`" " disabled"
	check_no_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_down
	pass
fi

if it "$*" 'start on a disabled instance does nothing'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 1 --port 19011" > $C
	echo "disable --group testA" >> $C
	echo "start" >> $C
	check_up
	check_contains "`shep status testA-0`" " disabled"
	check_contains "`shep start --instance testA-0`" "Starting instance testA-0"
	check_contains "`shep status testA-0`" " disabled"
	check_no_process "echo_server.js A $$"
	check_down
	pass
fi

describe 'enable'
if it "$*" 'should enable - everything'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 1 --port 19011" > $C
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> $C
	echo "disable" >> $C
	echo "start" >> $C
	check_up
	check_contains "`shep status testA-0`" " disabled"
	check_contains "`shep status testB-0`" " disabled"
	check_contains "`shep enable`" "Enabling everything"
	sleep 1
	check_contains "`shep status testA-0`" " started"
	check_contains "`shep status testB-0`" " started"
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_down
	pass
fi

if it "$*" 'should enable - groups'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 1 --port 19011" > $C
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> $C
	echo "disable" >> $C
	echo "start" >> $C
	check_up
	check_contains "`shep enable --group testA`" "Enabling group testA"
	check_contains "`shep status testA-0`" " started"
	check_contains "`shep status testB-0`" " disabled"
	check_contains "`shep enable --group testB`" "Enabling group testB"
	check_contains "`shep status testB-0`" " started"
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_down
	pass
fi

if it "$*" 'should enable - instances'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 3 --port 19011" > $C
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> $C
	echo "disable --group testA" >> $C
	echo "start" >> $C
	check_up
	check_contains "`shep enable --instance testA-1`" "Enabling instance testA-1"
	check_contains "`shep status testA-0`" " disabled"
	check_contains "`shep status testA-1`" " started"
	check_contains "`shep status testA-2`" " disabled"
	check_contains "`shep enable --instance testA-2`" "Enabling instance testA-2"
	check_contains "`shep status testA-2`" " started"
	check_contains "`shep enable --instance testA-0`" "Enabling instance testA-0"
	check_contains "`shep status testA-0`" " started"
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_down
	pass
fi

describe 'nginx'
if it "$*" 'should be able to --disable'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js A $$' --count 1 --port 19011" > $C
	check_up
	check_contains "`shep nginx --disable`" "nginx configuration updated"
	check_file_contains "$C" "nginx --disable"
	check_down
	pass
fi

if it "$*" 'should be able to --enable'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "add --group test --exec 'node echo_server.js A $$' --count 1 --port 19011" > $C
	check_up
	check_contains "`shep nginx --enable`" "nginx configuration updated"
	check_file_contains "$C" "nginx --enable"
	check [ -e "$TEMP_PATH/.shep/nginx.template" ]
	check_down
	pass
fi

if it "$*" 'should use nginx.template to write nginx'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
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
	N="$TEMP_PATH/.shep/nginx"
	check [ -e "$N" ]
	check_file_contains "$N" "test:www.example.com:8881:some_cert:some_key:19011"
	check_down
	pass
fi

if it "$*" 'should write nginx on status change'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
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
	sleep 2
	# cat "$TEMP_PATH/.shep/log"
	N="$TEMP_PATH/.shep/nginx"
	check [ -e $N ]
	check_file_contains "$N" 'test:www.example.com:8881:some_cert:some_key: 19011 19012'
	check_contains "`shep stop test-1`" "Stopping instance test-1"
	sleep 1
	check_file_contains "$N" 'test:www.example.com:8881:some_cert:some_key: 19011'
	check_contains "`shep start test-1`" "Starting instance test-1"
	sleep 1
	check_file_contains "$N" 'test:www.example.com:8881:some_cert:some_key: 19011 19012'
	check_down
	pass
fi

if it "$*" 'should handle multiple groups'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js A $$' --count 2 --port 19011" > $C
	echo "add --group twice --exec 'node echo_server.js B $$' --count 2 --port 19021" >> $C
	echo "nginx --group test --port 8881 --name www.example.com --ssl_cert some_cert --ssl_key some_key" >> $C
	echo "nginx --group twice --port 8882 --name app.example.com --ssl_cert some_cert2 --ssl_key some_key2" >> $C
	echo "nginx --enable --reload-cmd echo" >> $C
	echo "start" >> $C
	T="$TEMP_PATH/.shep/nginx.template"
	echo "{{name}}:{{public_name}}:{{public_port}}:{{ssl_cert}}:{{ssl_key}}:{{#each group}} {{ this.port }}{{/each}}" > $T
	check_up
	sleep 2
	# cat "$TEMP_PATH/.shep/log"
	N="$TEMP_PATH/.shep/nginx"
	check [ -e $N ]
	check_file_contains "$N" 'test:www.example.com:8881:some_cert:some_key: 19011 19012'
	check_file_contains "$N" 'twice:app.example.com:8882:some_cert2:some_key2: 19021 19022'
	check_contains "`shep stop test-1`" "Stopping instance test-1"
	check_contains "`shep stop twice-1`" "Stopping instance twice-1"
	sleep 1
	check_file_contains "$N" 'test:www.example.com:8881:some_cert:some_key: 19011'
	check_file_contains "$N" 'twice:app.example.com:8882:some_cert2:some_key2: 19021'
	check_contains "`shep start test-1`" "Starting instance test-1"
	check_contains "`shep start twice-1`" "Starting instance twice-1"
	sleep 1
	check_file_contains "$N" 'test:www.example.com:8881:some_cert:some_key: 19011 19012'
	check_file_contains "$N" 'twice:app.example.com:8882:some_cert2:some_key2: 19021 19022'
	check_down
	pass
fi

describe 'health'
if it "$*" 'should check status code'; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check_init
	echo "$bad_status_server" > bad_status_server.js
	echo "add --group bad_status --exec 'node bad_status_server.js A $$' --count 1 --port 19011" > $C
	echo "health --group bad_status --status 200 --interval 1" >> $C
	echo "start" >> $C
	check_up
	sleep 4
	L="$TEMP_PATH/.shep/log"
	cat $L
	check_file_contains "$L" "Health check failed (bad status: 500)"
	check_down
	pass
fi

exit 0
