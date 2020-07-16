#!/usr/bin/env bash
PATH=$PATH:./node_modules/.bin
START_PATH=$(pwd)
ROOT=$(pwd)/test

PASS_MARK='Pass'
FAIL_MARK="FAIL"
TEST_COUNT=0

function mkdeploy() {
	P=$(mktemp -d)
	if [ -z "$P" ]; then
		die "failed to mktemp -d: empty result"
	fi
	(echo "$P" | grep "^/tmp" || die "mktemp -d is not in /tmp: $P") > /dev/null
	rm -rf "$P/*"
	mkdir "$P/node_modules" \
		&& mkdir "$P/node_modules/.bin" \
		&& ln -sf "$START_PATH" "$P/node_modules/the-shepherd" \
		&& ln -sf ../the-shepherd/bin/shep "$P/node_modules/.bin/shep" \
		&& echo "$P" || die "failed to mkdeploy"
	return 0
}

function dotsleep() {
	echo -n "sleep "
	secs=$1
	while [ "$secs" -gt 0 ]; do
		sleep 1
		echo -n .
		secs=$(( $secs - 1 ))
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
		echo " * $2 "
		cd $(mkdeploy)
		return 0
	else
		return 1
	fi
}
function fail() {
	echo "$FAIL_MARK"
	P="$(pwd)"
	snapshot
	die $*
}
function check() {
	$* && pass || fail "$FAIL_MARK"
}
function check_result() {
	echo -n "check_result $1 "
	[ "$1" -eq 0 ] && pass || fail "Non-zero exit code: $1"
}
function check_exists() {
	echo -n "check_exists $1 "
	[ -e "$1" ] && pass || fail "Expected file to exist: $1"
}
function check_not_exist() {
	echo -n "check_not_exist $1 "
	[ ! -e "$1" ] && pass || fail "Unexpected file: $1"
}
function check_file_contains() {
	echo -n "check_file_contains $1 $2 "
	(cat "$1" | grep -q "$2") && pass || (cat $1 && fail "Expected: $2")
}
function check_dir() {
	echo -n "check_dir $1 "
	[ -d "$1" ] && pass || fail "Expected directory: $1"
}
function check_contains() {
	echo -n "check_contains $2 "
	(echo "$1" | grep -q "$2") && pass || (echo "Found: $1" && fail "Expected: $2")
}
function check_pid() {
	echo -n "check_pid $1 "
	ps "$1" > /dev/null && pass || fail "Expected PID: $1, not found."
}
function check_no_pid() {
	echo -n "check_no_pid $1 "
	ps "$1" && (fail "Unexpected PID: $1, should not be found.") || pass
}
function check_process() {
	echo -n "check_process $* "
	ps -eo pid,ppid,command | grep -v grep | grep -q "$*"
	[ "$?" -eq 0 ] && pass || fail "Expected process: $*, not found."
}
function check_no_process() {
	echo -n "check_no_process $* "
	ps -eo pid,ppid,command | grep -v grep | grep "$*"
	[ "$?" -eq 1 ] && pass || fail "Unexpected process: $*, should not be found."
}
function check_init() {
	echo -n "check_init "
	P="$(pwd)"
	O="`shep init 2>&1`"
	R="$?"
	check_result "$R"
	check_contains "$O", "Initializing .shep/config..."
}
function check_up() {
	check_not_exist "$P/.shep/socket"
	check_not_exist "$P/.shep/pid"
	echo -n "check_up "
	P="$(pwd)"
	shep up
	R=$?
	dotsleep 2
	check_result "$R"
	check_exists "$P/.shep/socket"
	check_exists "$P/.shep/pid"
	check_pid `cat $P/.shep/pid`
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
	echo "$PASS_MARK"
	return 0
}

function sigint() {
	snapshot
	die
}
function snapshot() {
	P="$(pwd)"
	echo $P | grep '^/tmp' || die "Unexpected pwd: $P, failed to snapshot."
	SAVETARGET=/tmp/shepherd-test-$(basename $P)
	echo "Saving snapshot of the test into $SAVETARGET"
	mkdir $SAVETARGET
	cp -arv $P/* $SAVETARGET
	cp -arv $P/.shep $SAVETARGET
	echo "Config:"
	echo "-------"
	cat $P/.shep/config
	echo
	echo "Log:"
	echo "----"
	cat $P/.shep/log
}
function cleanup() {
	P="$(pwd)"
	echo
	echo "cleanup: checking for /tmp..."
	echo $P | grep '^/tmp' > /dev/null
	if [ "$?" -eq 0 ]; then
		echo "cleanup: killall node..."
		killall node &> /dev/null || true
		echo "cleanup: rm -r $P..."
		[ -n "$P" -a -d "$P" ] && /bin/rm -r "$P"
	fi
}
trap cleanup EXIT
trap sigint SIGINT

function die() {
	echo "[$$] die: $*"
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
