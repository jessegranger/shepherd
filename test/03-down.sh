

describe 'down'
it 'should do nothing if already stopped'
	cd $(mkdeploy)
	shep init -q
	check [ "$?" -eq 0 ]
	shep down | grep -q "not running"
	check [ "$?" -eq 0 ]
	pass
