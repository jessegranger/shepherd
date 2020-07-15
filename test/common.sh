#!/usr/bin/env bash
PATH=$PATH:./node_modules/.bin
START_PATH=$(pwd)
ROOT=$(pwd)/test

PASS_MARK='Pass'
FAIL_MARK="FAIL"
TEST_COUNT=0

function mkdeploy() {
	P=$(mktemp -d)
	rm -rf "$P/*"
	mkdir "$P/node_modules" \
		&& mkdir "$P/node_modules/.bin" \
		&& ln -sf "$START_PATH" "$P/node_modules/the-shepherd" \
		&& ln -sf ../the-shepherd/bin/shep "$P/node_modules/.bin/shep" \
		&& echo "$P" \
		|| (echo "failed to mkdeploy"; exit 1)
	return 0
}

function dotsleep() {
	echo -n "sleep "
	secs=$1
	while [ "$secs" -gt 0 ]; do
		sleep 1
		echo -n .
		secs=`expr $secs - 1`
	done
	echo -n " "
	return 0
}

function describe() {
	echo
	echo -n $*
}
PORT_COUNTER="/tmp/shep_test_counter"
echo -n 9000 > $PORT_COUNTER
function next_port() {
	NEXT_PORT=`cat $PORT_COUNTER`
	NEXT_PORT=`expr $NEXT_PORT + 1`
	echo -n $NEXT_PORT > $PORT_COUNTER
	echo $NEXT_PORT
}
TEST_COUNT=0
function it() {
	if [ -z "$1" ] || (echo "$2" | grep -q "$1"); then
		TEST_COUNT=$(( $TEST_COUNT + 1 ))
		TEST_NAME="test_$$_case_$TEST_COUNT"
		echo
		echo -n " * $2"
		return 0
	else
		return 1
	fi
}
function fail() {
	P="$(pwd)"
	SAVETARGET=/tmp/shepherd-test-$(basename $P)
	echo " $FAIL_MARK"
	echo "Saving snapshot of the test into $SAVETARGET"
	mkdir $SAVETARGET
	cp -ar $P $SAVETARGET
	echo "Config:"
	echo "-------"
	cat $SAVETARGET/$(basename $P)/.shep/config
	echo "Log:"
	echo "----"
	cat $SAVETARGET/$(basename $P)/.shep/log
	die $*
}
function check() {
	$* && pass || fail " $FAIL_MARK"
}
function check_result() {
	echo "check_result $1 "
	[ "$1" -eq 0 ] && pass || fail "Non-zero exit code: $1"
}
function check_exists() {
	echo "check_exists $1 "
	[ -e "$1" ] && pass || fail "Expected file to exist: $1"
}
function check_file_contains() {
	echo "check_file_contains $1 $2 "
	(cat "$1" | grep -q "$2") && pass || (cat $1 && fail "Expected: $2")
}
function check_contains() {
	echo "check_contains $2 "
	(echo "$1" | grep -q "$2") && pass || (echo "Found: $1" && fail "Expected: $2")
}
function check_process() {
	echo "check_process $* "
	ps -eo pid,ppid,command | grep -v grep | grep -q "$*"
	check [ "$?" -eq 0 ]
}
function check_no_process() {
	echo "check_no_process $* "
	PS=`ps -eo pid,ppid,command | grep -v grep | grep "$*"`
	[ "$?" -eq 1 ] && pass || fail "Unexpected process: $* in: $PS"
}
function check_init() {
	echo "check_init "
	shep init -q
	check_result "$?"
}
function check_up() {
	echo -n "check_up "
	P="$(pwd)"
	O=`shep up 2>&1`
	R=$?
	dotsleep 2
	check_result "$R"
	check_contains "$O", "Starting"
	check_exists "$P/.shep/socket"
	check_exists "$P/.shep/pid"
	check_exists "$P/.shep/log"
	dotsleep 2
}
function check_down() {
	echo -n "check_down "
	P="$(pwd)"
	O="`shep down 2>&1`"
	R="$?"
	check_result "$R"
	check_contains "$O", "Stopped"
	dotsleep 1
	check_not_exist "$P/.shep/socket"
	check_not_exist "$P/.shep/pid"
	check_exists "$P/.shep/log"
}
function pass() {
	echo -n " $PASS_MARK"
	return 0
}

function cleanup() {
	P="$(pwd)"
	echo "cleanup: checking for /tmp..."
	echo $P | grep '^/tmp' || exit 1
	echo "cleanup: killall node..."
	killall node &> /dev/null || true
	echo "cleanup: rm -r $P..."
	[ -n "$P" -a -d "$P" ] && /bin/rm -r "$P"
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
