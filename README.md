
The Shepherd
--------

Manage groups of processes.

Install:
`npm install the-shepherd`


Usage:
`shep <command> [options]`

Global options:

	--quiet or -q
	--verbose or -v
	--force or -f
	--path <base-path> - Use `<base-path>/.shepherd` instead of searching.

Commands:

	init - Create a `.shepherd` folder here.
	up - Ensure the manager daemon is running.
	down - Stop the daemon.
	start - Start processes (autostarts the daemon).
	stop - Stop processes.
	restart - Restart processes.
	add - Add a process group to be managed by the daemon.
	remove - Remove a process group.
	replace - Replace a process group with new settings.
	scale - Scale a process group to a new size.
	nginx - Configure the nginx integration.
	log - Control the log output.

Files
-----

`shep` reads and writes state from a `.shepherd` directory. You can specify this directory using `SHEPHERD_PATH` in the environment, or using the `--path` argument to any command.  If unspecified, `shep` will search for a `.shepherd` directory using the same rule Git uses to search for a `.git` folder: Start in the working directory, and check each parent until you find one. `shep init` is the only command that skips this search (without `--path` or `SHEPHERD_PATH`).

Files inside the `.shepherd` directory:

	config - A list of commands to execute at daemon startup.
	defaults - Will be copied to config by 'shep init'.
	socket - A unix socket used by the daemon to listen for commands.
	pid - Contains the pid of any currently running daemon.
	log - The (default) location to log output from all managed processes.
	nginx - The (default) location to keep an up-to-date set of nginx upstreams.


`shep init`
-----------

`init` ensures that a `.shepherd` folder exists in the working directory.

If a `.shepherd` folder already exists, and has a `defaults` file, but no `config` file, it will copy `defaults` to `config`.

`shep up`
---------

`up` ensures that a daemon has been spawned to manage the current `.shepherd` directory.

If `.shepherd/config` exists, each line will be read in as if it had been given as a command to `shep`, eg:

	add --group echo --cd test/echo --exec "node echo_server.js" --count 4 --port 9001
	start

When the daemon starts, it will create `.shepherd/socket` and `.shepherd/pid`, and possibly others.

