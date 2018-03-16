

describe "init"
it "should create a .shepherd folder"
	cd $(mkdeploy)
	shep init > /dev/null
	check [ -d "$TEST_PATH/.shepherd" ]
	pass

it "should copy a .shepherd/defaults file"
	cd $(mkdeploy)
	check [ -n "$TEST_PATH" -a -d "$TEST_PATH" ]
	mkdir -p "$TEST_PATH/.shepherd/"
	echo "xyzzy" > "$TEST_PATH/.shepherd/defaults"
	shep init > /dev/null
	check [ `cat "$TEST_PATH/.shepherd/config"` = "xyzzy" ]
	pass
