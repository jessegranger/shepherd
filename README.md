
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
	--path <base-path> - Use `<base-path>/.shep` instead of searching.

Commands:

| Command |                                          | Example                                             |
| ------- | -----------                              | -------                                             |
| init    | Create a `.shep` folder here.            | `shep init`                                         |
| up      | Ensure the daemon is running.            | `shep up`                                           |
| down    | Stop the daemon.                         | `shep down`                                         |
| add     | Add a process group.                     | `shep add echo --exec "node echo.js" --port 8081`   |
| remove  | Remove a process group.                  | `shep remove echo`                                  |
| replace | Replace a group with new settings.       | `shep replace echo --exec "node foo.js"`            |
| start   | Start processes (autostarts the daemon). | `shep start echo-1`                                 |
| stop    | Stop processes.                          | `shep stop echo`                                    |
| restart | Restart processes.                       | `shep restart echo-1`                               |
| disable | Disable an instance or group.            | `shep disable --group foo`                          |
| enable  | Enable an instance or group.             | `shep enable --instance foo-1`                      |
| status  | Report the current status.               | `shep status --verbose`                             |
| config  | Manage the config file.                  | `shep config --list`                                |
| health  | Manage a health-check on a group.        | `shep health --group foo --status 200 --interval 3` |
| log     | Manage the log output.                   | `shep log --tail`                                   |
| nginx   | Configure the nginx integration.         | `shep nginx --file '%/nginx'`                       |
| scale   | Scale a process group to a new size.     | `shep scale echo --count 2`                         |

Files
-----

`shep` reads and writes state from a `.shep` directory. You can specify this directory using `SHEPHERD_PATH` in the environment, or using the `--path` argument to any command.  If unspecified, `shep` will search for a `.shep` directory using the same rule Git uses to search for a `.git` folder: Start in the working directory, and check each parent until you find one. `shep init` is the only command that skips this search.

Files inside the `.shep` directory:

	config - A list of commands to execute at daemon startup.
	defaults - Will be copied to config by 'shep init'. This file should be in source control.
	socket - A unix socket used by the daemon to listen for commands.
	pid - Contains the pid of any currently running daemon.
	log - The (default) location to log output from all managed processes.
	nginx - The (default) location to keep an up-to-date set of nginx upstreams.

When reading the `config` file, any occurrence of "%" will be replaced with the full path to the `.shep` directory.

`> shep init`
-----------

`init` ensures that a `.shep` folder exists in the working directory.

If a `.shep` folder already exists, and has a `defaults` file, but no `config` file, it will copy `defaults` to `config`.

`> shep up`
---------

`up` ensures that a daemon has been spawned to manage the current `.shep` directory.

	--verbose - Launch the daemon with verbose logging.

If `.shep/config` exists, each line will be read in as if it had been given as a command to `shep`, eg:

	log --file "%/log"	
	add echo --cd test/echo --exec "node echo_server.js" --count 4 --port 9001
	nginx --disable
	start

When the daemon starts, it will create `.shep/socket` and `.shep/pid`, and possibly others.

Where indicated below, many commands cause the currently running configuration to be written to the `config` file (overwriting that file).

`> shep down`
---------

`down` stops the current daemon, and all processes it was managing.

`> shep add`
----------

`add` will add a group, it accepts a standard set of options for
specifying a group:

	--group <name> - Required. Process ids will be like <group-name>-1, etc.
	--cd <path> - The working directory for new processes. Optional. Default "."
	--exec <command> - The shell command to launch the process. Required.
	--count <n> - Optional. Default 1
	--port <port> - The starting port. If n > 0 then port will be incremented. Optional.
	--grace <ms> - How long to allow the process to startup. Optional. Default 9000

If `--port` is specified, each new process is given `PORT` in it's environment.  The process is `"started"` once it is listening on it's given `PORT`.  Failure to listen on `PORT` within the `--grace` timeout will cause that process to become `"failed"` and not restarted.

If `--port` is not specified, then the process is `"started"` if it stays up for it's full `--grace` period.  Be careful if you use long `--grace` times, with no `--port`, and high `--count`; this combination will lead to a slow `start` for that group.

This command causes `config` to be re-written.

`> shep remove`
-------------

`remove` will (stop and) remove a current process group.

	--group <name>

This command causes `config` to be re-written.

`> shep replace`
--------------

`replace` will first `remove` then re-`add` a group, using the new options.  Uses the same options as `add`.

All the processes in the group will be stopped (during the remove), and started (after the add).

This command causes `config` to be re-written.

`> shep scale`
------------

`scale` will change just the `--count` option for a group, and will only effect current processes if the new `<n>` is smaller.

	--group <name>
	--count <n>

If the `--group` is started, then processes will be started or stopped immediately.

This command causes `config` to be re-written. The new config will not contain a `--scale` command directly, but instead this scaling will be reflected in the corresponding `add --group` command.

`> shep start`
------------

`start` can start specified groups, or processes.

	--group <name>
	--instance <instance-id>

If no options are given, everything will be started.

If the daemon is not running, `up` will be called automatically.

`> shep stop`
-----------

`stop` can stop specified group, or processes.

	--group <name>
	--instance <instance-id>

If no options are given, everything will be stopped.

`> shep restart`
------------

`restart` can start specified groups, or processes.

	--group <name>
	--instance <instance-id>

If no options are given, everything will be started.

Processes will be restarted serially within a group, but multiple groups will restart in parallel.

`> shep log`

`log` controls the combined output of all managed processes.

	--file <path> - eg, the default is "%/log".
	--disable - Don't write any log file to disk.
	--tail - Stream the log output. Works even when log file is disabled.

When using `--tail`, it will keep the process open until you hit `Ctrl-C`, and behaves like `tail -f api.log`.
The difference is that it streams from inside the daemon, through the `socket` file, and to the `shep` client (no file needed).

`> shep nginx`
------------
`nginx` controls the built-in nginx integration.

	--file <path> - Where to keep an up-to-date set of upstreams.
	--keepalive <n> - How many connections should nginx keep-alive to each pool.
	--reload <command> - How to notify nginx to reload an updated config.
	--disable - Don't write any nginx configuration (default).

The generated upstreams file might look like this:

	upstream group_name {
		server 127.0.0.1:9001 weight=0 down; # disabled
		server 127.0.0.1:9002 weight=1; # started
		server 127.0.0.1:9003 weight=1 down; # enabled, but not started
		
		keepalive 32;
	}

This file is re-generated, and nginx is notified to (gently) check for configuration changes as process statuses change.
