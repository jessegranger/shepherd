
describe 'down'
if it "$*" 'should do nothing if already stopped'; then
	cd $(mkdeploy)
	check_init
	check_contains "`shep down`" "Status: offline"
	pass
fi

if it "$*" 'should stop a started daemon'; then
	cd $(mkdeploy)
	check_init
	check_up
	check_contains "`shep down`" "Status: offline"
	check_contains "`shep status`" "Status: offline"
	pass
fi
