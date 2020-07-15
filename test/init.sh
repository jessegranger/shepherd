
describe "init"
if it "$*" "should create a .shep folder"; then
	cd $(mkdeploy)
	check_init
	check_dir "$(pwd)/.shep"
fi

if it "$*" "should copy a .shep/defaults file"; then
	cd $(mkdeploy)
	P="$(pwd)"
	mkdir -p "$P/.shep/"
	echo "xyzzy" > "$P/.shep/defaults"
	check_init
	check_file_contains "$P/.shep/config" "xyzzy"
fi
