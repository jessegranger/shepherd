

describe "init"
it "should create a .shepherd folder"
	cd $(mkdeploy)
	check [ "$?" -eq 0 ]
	shep init > /dev/null
	check [ -d "$TEMP_PATH/.shepherd" ]
	pass

it "should copy a .shepherd/defaults file"
	cd $(mkdeploy)
	check [ -n "$TEMP_PATH" -a -d "$TEMP_PATH" ]
	mkdir -p "$TEMP_PATH/.shepherd/"
	echo "xyzzy" > "$TEMP_PATH/.shepherd/defaults"
	shep init > /dev/null
	check [ `cat "$TEMP_PATH/.shepherd/config"` = "xyzzy" ]
	pass
