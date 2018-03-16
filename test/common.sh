#!/usr/bin/env bash

PATH=$PATH:./node_modules/.bin
TEST_PATH=`mktemp -d`
START_PATH=`pwd`

# echo TEST_PATH $TEST_PATH

function mkdeploy() {
	rm -rf "$TEST_PATH/node_modules" "$TEST_PATH/.shepherd" "$TEST_PATH/*.js"
	mkdir "$TEST_PATH/node_modules" \
		&& mkdir "$TEST_PATH/node_modules/.bin" \
		&& ln -sf "$START_PATH" "$TEST_PATH/node_modules/the-shepherd" \
		&& ln -sf ../the-shepherd/bin/shep "$TEST_PATH/node_modules/.bin/shep" \
		&& echo "$TEST_PATH" \
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
function pass() {
	echo " Pass"
	return 0
}
function setup() {
	return 0
}

function cleanup() {
	killall node || true &> /dev/null
	[ -d "$TEST_PATH" ] && /bin/rm -r "$TEST_PATH"
}
trap cleanup EXIT
trap cleanup ERR

function die() {
	(echo "die: $*"; exit 1)
}
