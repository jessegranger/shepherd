

describe 'down'
it 'should do nothing if already stopped'
	cd $(mkdeploy)
	check_init
	shep down | grep -q "Status: offline"
	check [ "$?" -eq 0 ]
	pass

it 'should stop a started daemon'
	cd $(mkdeploy)
	check_init
	check_up
	check_down
	pass

