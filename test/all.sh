#!/usr/bin/env bash
set -e
ROOT=$(pwd)/test

source $ROOT/common.sh

describe "init"
it "should create a .shepherd folder"
	cd $(mkdeploy)
	check [ "$?" -eq 0 ]
	shep init > /dev/null
	check [ -d "$TEMP_PATH/.shepherd" ]
	pass

it "should copy a .shepherd/defaults file"
	cd $(mkdeploy)
	check [ -n "$TEMP_PATH" -a -d "$TEMP_PATH" ]
	mkdir -p "$TEMP_PATH/.shepherd/"
	echo "xyzzy" > "$TEMP_PATH/.shepherd/defaults"
	shep init > /dev/null
	check [ `cat "$TEMP_PATH/.shepherd/config"` = "xyzzy" ]
	pass


describe 'up'
it 'should start the daemon'
	cd $(mkdeploy)
	check_init
	check_up
	check_down
	pass

it 'can add and start from the config'
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js $$' --count 1 --port 9011" > "$TEMP_PATH/.shepherd/config"
	echo "start" >> "$TEMP_PATH/.shepherd/config"
	check_up
	check_process "echo_server.js $$"
	check_down
	pass


describe 'down'
it 'should do nothing if already stopped'
	cd $(mkdeploy)
	check_init
	shep down | grep -q "Status: offline"
	check [ "$?" -eq 0 ]
	pass

it 'should stop a started daemon'
	cd $(mkdeploy)
	check_init
	check_up
	shep down | grep -q "Status: offline"
	check [ "$?" -eq 0 ]
	shep status | grep -q "Status: offline"
	check [ "$?" -eq 0 ]
	pass


describe 'status'
it 'should do nothing if daemon is stopped'
	cd $(mkdeploy)
	check_init
	shep status | grep -q "Status: offline"
	check [ "$?" -eq 0 ]
	pass

it 'should list - unstarted'
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js $$' --count 1 --port 9011" > "$TEMP_PATH/.shepherd/config"
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

it 'should list - started'
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js $$' --count 1 --port 9011" > "$TEMP_PATH/.shepherd/config"
	echo "start" >> "$TEMP_PATH/.shepherd/config"
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

describe 'stop'
it 'should stop - everything'
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js $$' --count 1 --port 9011" > "$TEMP_PATH/.shepherd/config"
	echo "start" >> "$TEMP_PATH/.shepherd/config"
	check_up
	check_process "echo_server.js $$"
	shep stop | grep -q "Stopping everything"
	check [ "$?" -eq 0 ]
	check_down
	pass

it 'should stop - groups'
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 1 --port 9011" > "$TEMP_PATH/.shepherd/config"
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> "$TEMP_PATH/.shepherd/config"
	echo "start" >> "$TEMP_PATH/.shepherd/config"
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

it 'should stop - instances'
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js $$' --count 2 --port 9011" > "$TEMP_PATH/.shepherd/config"
	echo "start" >> "$TEMP_PATH/.shepherd/config"
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

describe 'start'
it 'should start - everything'
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 1 --port 9011" > "$TEMP_PATH/.shepherd/config"
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> "$TEMP_PATH/.shepherd/config"
	check_up
	shep start | grep -q "Starting everything"
	check [ "$?" -eq 0 ]
	sleep 1
	check_process "echo_server.js A $$"
	check_process "echo_server.js B $$"
	check_down
	pass

it 'should start - groups'
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group testA --exec 'node echo_server.js A $$' --count 1 --port 9011" > "$TEMP_PATH/.shepherd/config"
	echo "add --group testB --exec 'node echo_server.js B $$' --count 1 --port 9021" >> "$TEMP_PATH/.shepherd/config"
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

it 'should start - instances'
	cd $(mkdeploy)
	check_init
	echo "$echo_server" > echo_server.js
	echo "add --group test --exec 'node echo_server.js A $$' --count 3 --port 9011" > "$TEMP_PATH/.shepherd/config"
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
