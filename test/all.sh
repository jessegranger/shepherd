#!/usr/bin/env bash
set -e
ROOT=$(dirname $0)
source $ROOT/common.sh

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

source $ROOT/01-init.sh

source $ROOT/02-up.sh

source $ROOT/03-down.sh

source $ROOT/04-status.sh
