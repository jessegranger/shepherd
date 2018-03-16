#!/usr/bin/env bash
set -e
ROOT=$(pwd)/test

source $ROOT/common.sh

source $ROOT/01-init.sh

source $ROOT/02-up.sh

source $ROOT/03-down.sh

source $ROOT/04-status.sh
