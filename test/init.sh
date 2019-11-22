
describe "init"
if it "$*" "should create a .shep folder"; then
	cd $(mkdeploy)
	check [ "$?" -eq 0 ]
	shep init > /dev/null
	check [ -d "$TEMP_PATH/.shep" ]
	pass
fi

if it "$*" "should copy a .shep/defaults file"; then
	cd $(mkdeploy)
	C="$TEMP_PATH/.shep/config"
	check [ -n "$TEMP_PATH" -a -d "$TEMP_PATH" ]
	mkdir -p "$TEMP_PATH/.shep/"
	echo "xyzzy" > "$TEMP_PATH/.shep/defaults"
	shep init > /dev/null
	check [ `cat $C` = "xyzzy" ]
	pass
fi
