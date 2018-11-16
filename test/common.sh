#!/usr/bin/env bash

PATH=$PATH:./node_modules/.bin
TEMP_PATH=$(mktemp -d)
START_PATH=$(pwd)
ROOT=$(pwd)/test

# echo TEMP_PATH $TEMP_PATH

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
	echo $*
}
function it() {
	if [ -z "$1" -o "$1" = "$2" ]; then
		echo -n " * $2 -"
		return 0
	else
		return 1
	fi
}
function check() {
	$* && printf " \u2713" || die " fail"
}
function check_file_contains() {
	(cat "$1" | grep -q "$2") && printf " \u2713" || (cat $1 && die "Expected: $2")
}
function check_contains() {
	(echo "$1" | grep -q "$2") && printf " \u2713" || die "Expected: $2 Got: $1"
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
	shep up --verbose | grep -q "Starting"
	check [ "$?" -eq 0 -a -e "$TEMP_PATH/.shep/socket" -a -e "$TEMP_PATH/.shep/pid" -a -e "$TEMP_PATH/.shep/log" ]
	sleep .3
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
