
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
		--path <base-path> - Force use of `<base-path>/.shepherd` instead of searching.

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

Files:

The `shep` command will search for a `.shepherd` folder using the same rule Git uses to search for a `.git` folder: Start in the working directory, and keep checking each parent until you find one.

