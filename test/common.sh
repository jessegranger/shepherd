#!/usr/bin/env bash

PATH=$PATH:./node_modules/.bin
TEMP_PATH=$(mktemp -d)
START_PATH=$(pwd)
ROOT=$(pwd)/test

PASS_MARK="Pass"
FAIL_MARK="Fail"

echo TEMP_PATH $TEMP_PATH

function mkdeploy() {
	rm -rf "$TEMP_PATH/node_modules" "$TEMP_PATH/.shep" "$TEMP_PATH/*.js"
	mkdir "$TEMP_PATH/node_modules" \
		&& mkdir "$TEMP_PATH/node_modules/.bin" \
		&& ln -sf "$START_PATH" "$TEMP_PATH/node_modules/the-shepherd" \
		&& ln -sf ../the-shepherd/bin/shep "$TEMP_PATH/node_modules/.bin/shep" \
		&& echo "$TEMP_PATH" \
		|| (echo "failed to mkdeploy"; exit 1)
	return 0
}

function dotsleep() {
	ms=$1
	if [ "$ms" -gt 0 ]; then
		sleep 1
		echo -n .
		dotsleep `expr $ms - 1`
	fi
	return 0
}

function describe() {
	echo
	echo -n $*
}
function it() {
	if [ -z "$1" ] || (echo "$2" | grep -q "$1"); then
		echo
		echo -n " * $2"
		return 0
	else
		return 1
	fi
}
function fail() {
	SAVETARGET=/tmp/save-$(basename $TEMP_PATH)
	echo " $FAIL_MARK"
	echo "Saving snapshot of the test into $SAVETARGET"
	mkdir $SAVETARGET
	cp -ar $TEMP_PATH $SAVETARGET
	die $*
}
function check() {
	$* && pass || fail " $FAIL_MARK"
}
function check_file_contains() {
	# echo -n check_file_contains $1 $2
	(cat "$1" | grep -q "$2") && pass || (cat $1 && fail "Expected: $2")
}
function check_contains() {
	# echo -n check_contains $2 $3
	(echo "$1" | grep -q "$2") && pass || (echo $1 && fail "Expected: $2")
}
function check_process() {
	# echo -n check_process $*
	ps -eo pid,ppid,command | grep -v grep | grep -q "$*"
	check [ "$?" -eq 0 ]
}
function check_no_process() {
	# echo -n "check_no_process: $* "
	PS=`ps -eo pid,ppid,command | grep -v grep | grep "$*"`
	[ "$?" -eq 1 ] && pass || fail "Unexpected process: $* in: $PS"
}
function check_init() {
	# echo -n "check_init"
	shep init -q
	check [ "$?" -eq 0 ]
}
function check_up() {
	# echo -n "check_up"
	shep up --verbose | grep -q "Starting"
	check [ "$?" -eq 0 -a -e "$TEMP_PATH/.shep/socket" -a -e "$TEMP_PATH/.shep/pid" -a -e "$TEMP_PATH/.shep/log" ]
	sleep 3
}
function check_down() {
	# echo -n "check_down"
	shep down | grep -q "Stopping"
	check [ "$?" -eq 0 ]
}
function pass() {
	echo -n " $PASS_MARK"
	return 0
}

function cleanup() {
	killall node &> /dev/null || true
	echo "Cleaning up $TEMP_PATH"
	[ -d "$TEMP_PATH" ] && /bin/rm -r "$TEMP_PATH"
}
trap cleanup EXIT
# trap cleanup ERR

function die() {
	echo "die: $*"
	exit 1
}

echo_server=$(cat <<EOF
s= require('net').Server().listen({port: parseInt(process.env.PORT)});
s.on('error', (err) => { console.error(err); process.exit(1) });
s.on('connection', (client) => { client.on('data', (msg) => { client.write(process.argv[2] + " " + String(data)) }) });
EOF
)

crash_server="throw new Error('tis but a scratch')"

simple_worker=$(cat <<EOF
setInterval(()=>{ console.log("simple_worker is Working..."); }, 3000)
setTimeout(()=>{ process.exit(0); }, 300000)
EOF
)

bad_status_server=$(cat <<EOF
n = 0; require('http').createServer((req, res) => {
	res.statusCode = (++n % 2 == 0 ? 500 : 200);
	res.end()
}).listen({port: parseInt(process.env.PORT)});
EOF
)

bad_text_server=$(cat <<EOF
n = 0; require('http').createServer((req, res) => {
	res.statusCode = 200;
	res.end( (++n % 2 == 0 ? "Fail" : "OK") )
}).listen({port: parseInt(process.env.PORT)});
EOF
)
