# sqlboot

`sqlboot` bootstraps Oracle SQL*Plus on local machine with one command.

Live site: https://sqlboot.js.org

It installs required OS packages, prepares Oracle Instant Client, starts Oracle XE in Docker, writes `tnsnames.ora`, enables `rlwrap` history, then installs global `sqlboot` launcher.

## Why sqlboot

- One-step Oracle SQL*Plus setup for macOS, Ubuntu-based Linux, Zorin OS, WSL2 Ubuntu, and Windows hosts through WSL2 Ubuntu
- Docker Oracle XE container with sane defaults
- Oracle Instant Client + SQL*Plus download and shell wiring
- Persistent SQL*Plus history through `rlwrap`
- Generated `XE` alias for fast local connect flow
- Repeatable local setup without manual Oracle client docs chase

## Install

Run installer directly from npm:

```sh
npx sqlboot init
npx sqlboot help
```

After setup completes:

```sh
sqlboot start
```

Inside SQL*Plus:

```sql
conn system/1234@XE
```

## What sqlboot sets up

`sqlboot` handles all of this:

- installs `curl`, `unzip`, `rlwrap`
- installs Docker Desktop on macOS or `docker.io` on Ubuntu-based Linux
- uses Docker Desktop WSL integration on WSL2 Ubuntu
- pulls `gvenzl/oracle-xe:21-slim`
- creates and starts `oracle-xe` container
- downloads Oracle Instant Client and SQL*Plus
- writes `~/oracle/instantclient/network/admin/tnsnames.ora`
- exports SQL*Plus env vars in shell profile
- enables persistent SQL history with `rlwrap`
- installs `/usr/local/bin/sqlboot`

## Uninstall

Remove sqlboot-managed resources:

```sh
sqlboot uninstall
```

This removes the Oracle XE container and image, Oracle Instant Client files, generated shell environment block, SQL*Plus history file, and `/usr/local/bin/sqlboot`.

Shared system dependencies are left installed because they may be used outside sqlboot: Docker, Homebrew, `curl`, `unzip`, `rlwrap`, and apt packages.

On Windows, remove the sqlboot-managed Windows setup too:

```powershell
sqlboot uninstall --purge
```

Purge first runs the normal WSL uninstall, then removes Docker Desktop, unregisters the Ubuntu WSL distro used by sqlboot, removes Ubuntu/WSL app packages where Windows exposes them, cleans sqlboot's Docker Desktop WSL integration setting, removes the current Windows user from `docker-users`, and disables the Windows WSL optional features. Windows may require a restart afterward.

## Supported platforms

- macOS
- Ubuntu-based Linux
- Zorin OS
- Windows through WSL2 Ubuntu

On Windows, run the npm CLI from PowerShell, Windows Terminal, or CMD:

```powershell
npx sqlboot init
```

The Windows bootstrapper installs or starts WSL2 Ubuntu and Docker Desktop when possible, then runs the Linux setup inside WSL. Windows may ask for administrator approval, Ubuntu may ask you to create the first Linux user, and Docker Desktop may ask for first-run confirmation.

## Defaults

| Setting | Value |
| --- | --- |
| Docker image | `gvenzl/oracle-xe:21-slim` |
| Container name | `oracle-xe` |
| Host port | `1521` |
| Oracle password | `1234` |
| Service name | `XEPDB1` |
| TNS alias | `XE` |
| Instant Client path | `~/oracle/instantclient` |
| SQL history file | `~/.sqlplus_history` |

## Configuration

Override defaults with env vars before install:

```sh
SQLBOOT_ORACLE_PASSWORD='new-password' npx sqlboot init
```

Available env vars:

```sh
SQLBOOT_ORACLE_PASSWORD
SQLBOOT_ORACLE_IMAGE
SQLBOOT_ORACLE_CONTAINER
SQLBOOT_ORACLE_PORT
SQLBOOT_ORACLE_SERVICE
SQLBOOT_IC_BASIC_URL
SQLBOOT_IC_SQLPLUS_URL
SQLBOOT_READY_TIMEOUT_SECONDS
SQLBOOT_DOCKER_READY_TIMEOUT_SECONDS
SQLBOOT_ORACLE_BASE_DIR
SQLBOOT_INSTANTCLIENT_PARENT
SQLBOOT_SQLPLUS_HISTORY
```

## Common workflows

Use different port:

```sh
SQLBOOT_ORACLE_PORT=1522 npx sqlboot init
```

Use different password:

```sh
SQLBOOT_ORACLE_PASSWORD='super-secret' npx sqlboot init
```

Use different Oracle image:

```sh
SQLBOOT_ORACLE_IMAGE='gvenzl/oracle-xe:21-full' npx sqlboot init
```

Launch SQL*Plus later:

```sh
sqlboot start
```

Useful commands:

```sh
sqlboot help
sqlboot status
sqlboot logs
sqlboot doctor
sqlboot stop
sqlboot reset-pwd <new-password>
sqlboot uninstall
```

## Windows with WSL2

From Windows:

```powershell
npx sqlboot init
```

If Docker Desktop asks for WSL integration, enable:

```text
Settings > Resources > WSL integration
```

After setup completes, you can launch from Windows:

```powershell
npx sqlboot start
```

Or from Ubuntu/WSL:

```sh
sqlboot start
```

## Troubleshooting

Check container:

```sh
docker ps -a --filter name=oracle-xe
```

Check recent Oracle logs:

```sh
docker logs --tail 120 oracle-xe
```

Restart container:

```sh
docker restart oracle-xe
```

Reset existing Oracle password:

```sh
docker exec oracle-xe resetPassword new-password
```

If `sqlboot` waits too long for Oracle XE:

- confirm container still running
- confirm Docker has enough memory
- check logs for startup or disk errors

If Docker was newly installed on Linux, log out and back in before retrying so user can access Docker socket without `sudo`.

If `npx` keeps resolving older release:

```sh
npx sqlboot@latest init
```
