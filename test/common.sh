#!/usr/bin/env bash

PATH=$PATH:./node_modules/.bin
TEMP_PATH=$(mktemp -d)
START_PATH=$(pwd)
ROOT=$(pwd)/test

# echo TEMP_PATH $TEMP_PATH

function mkdeploy() {
	rm -rf "$TEMP_PATH/node_modules" "$TEMP_PATH/.shepherd" "$TEMP_PATH/*.js"
	mkdir "$TEMP_PATH/node_modules" \
		&& mkdir "$TEMP_PATH/node_modules/.bin" \
		&& ln -sf "$START_PATH" "$TEMP_PATH/node_modules/the-shepherd" \
		&& ln -sf ../the-shepherd/bin/shep "$TEMP_PATH/node_modules/.bin/shep" \
		&& echo "$TEMP_PATH" \
		|| (echo "failed to mkdeploy"; exit 1)
	return 0
}

function describe() {
	echo $*
}
function it() {
	echo -n " * $* -"
}
function check() {
	$* && printf " \u2713" || die " fail"
}
function check_process() {
	ps -eo pid,ppid,command | grep -v grep | grep -q "$*"
	check [ "$?" -eq 0 ]
}
function check_no_process() {
	(ps -eo pid,ppid,command | grep -v grep | grep -q "$*" && false) || true
}
function check_init() {
	shep init -q
	check [ "$?" -eq 0 ]
}
function check_up() {
	printf ' up('
	check [ ! -e "$TEMP_PATH/.shepherd/socket" ]
	check [ ! -e "$TEMP_PATH/.shepherd/pid" ]
	check [ ! -e "$TEMP_PATH/.shepherd/log" ]
	shep up | grep -q "Starting"
	check [ "$?" -eq 0 ]
	sleep 1
	check [ -e "$TEMP_PATH/.shepherd/socket" ]
	check [ -e "$TEMP_PATH/.shepherd/pid" ]
	check [ -e "$TEMP_PATH/.shepherd/log" ]
	printf ' )'
}
function check_down() {
	shep down | grep -q "Stopping"
	check [ "$?" -eq 0 ]
}
function pass() {
	echo " Pass"
	return 0
}
function setup() {
	return 0
}

function cleanup() {
	killall node &> /dev/null || true
	[ -d "$TEMP_PATH" ] && /bin/rm -r "$TEMP_PATH"
}
trap cleanup EXIT
trap cleanup ERR

function die() {
	(echo "die: $*"; exit 1)
}

echo_server=$(cat <<EOF
s= require('net').Server().listen({port: parseInt(process.env.PORT)});
s.on('error', (err) => { console.error(err); process.exit(1) });
s.on('connection', (client) => { client.on('data', (msg) => { client.write(process.argv[2] + " " + String(data)) }) });
EOF
)

simple_worker=$(cat <<EOF
setInterval(()=>{ console.log("Working..."); }, 3000)
setTimeout(()=>{ process.exit(0); }, 300000)
EOF
)
