#!/usr/bin/env bash
# set -e
ROOT=$(pwd)/test

. $ROOT/common.sh && \
. $ROOT/init.sh && \
. $ROOT/stop.sh && \
. $ROOT/up.sh && \
. $ROOT/down.sh && \
. $ROOT/status.sh && \
. $ROOT/start.sh && \
. $ROOT/disable.sh && \
. $ROOT/enable.sh && \
. $ROOT/restart.sh && \
. $ROOT/nginx.sh && \
. $ROOT/health.sh && \
echo "Done"
