
describe "init"
if it "$*" "should create a .shep folder"; then
	cd $(mkdeploy)
	check [ "$?" -eq 0 ]
	shep init > /dev/null
	check [ -d "$(pwd)/.shep" ]
	pass
fi

if it "$*" "should copy a .shep/defaults file"; then
	cd $(mkdeploy)
	C="$(pwd)/.shep/config"
	mkdir -p "$(pwd)/.shep/"
	echo "xyzzy" > "$(pwd)/.shep/defaults"
	shep init > /dev/null
	check [ `cat $C` = "xyzzy" ]
	pass
fi
