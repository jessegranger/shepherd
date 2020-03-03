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
function check_file_contains() {
	# echo -n check_file_contains $1 $2
	(cat "$1" | grep -q "$2") && pass || (cat $1 && fail "Expected: $2")
}
function check_contains() {
	# echo -n check_contains $2 $3
	(echo "$1" | grep -q "$2") && pass || (echo "Found: $1" && fail "Expected: $2")
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
	P="$(pwd)"
	shep up --verbose | grep -q "Starting"
	check [ "$?" -eq 0 ]
	dotsleep 2
	check [ -e "$P/.shep/socket" ]
	check [ -e "$P/.shep/pid" ]
	check [ -e "$P/.shep/log" ]
	dotsleep 2
}
function check_down() {
	# echo -n "check_down"
	shep down | grep -q "All stopped"
	R=$?
	echo -n "(shep down result: $R)"
	check [ "$R" -eq 0 ]
}
function pass() {
	echo -n " $PASS_MARK"
	return 0
}

function cleanup() {
	P="$(pwd)"
	killall node &> /dev/null || true
	echo
	echo "Cleaning up $P"
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
