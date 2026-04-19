# sqlboot

`sqlboot` sets up a local Oracle SQL*Plus workflow on macOS, Ubuntu-based Linux, and Windows through WSL2 Ubuntu.

It installs the required tools, starts an Oracle XE Docker container, configures SQL*Plus, and gives you one command:

```sh
sqlboot
```

## What It Does

- Installs `curl`, `unzip`, and `rlwrap`.
- Installs Docker Desktop on macOS or `docker.io` on Ubuntu-based Linux.
- Uses Docker Desktop WSL integration on Windows through WSL2.
- Pulls `gvenzl/oracle-xe:21-slim`.
- Creates and starts an `oracle-xe` container on port `1521`.
- Downloads Oracle Instant Client and SQL*Plus.
- Creates `~/oracle/instantclient/network/admin/tnsnames.ora`.
- Adds the `XE` connection alias for `XEPDB1`.
- Adds SQL*Plus environment variables to `~/.zshrc` on macOS or `~/.bashrc` on Linux.
- Enables persistent SQL*Plus command history with `rlwrap`.
- Installs `/usr/local/bin/sqlboot`.

## Install

```sh
npx sqlboot
```

After setup finishes, run:

```sh
sqlboot
```

Inside SQL*Plus:

```sql
conn system/1234@XE
```

## Supported Systems

- macOS with zsh and Homebrew
- Ubuntu-based Linux
- Zorin OS
- Windows through WSL2 Ubuntu

Native Windows PowerShell/CMD is not supported.

## Windows

Use WSL2 with Ubuntu:

```powershell
wsl --install
```

Install Docker Desktop for Windows, then enable WSL integration:

```text
Docker Desktop > Settings > Resources > WSL integration
```

Open Ubuntu/WSL and run:

```sh
npx sqlboot
```

Do not run `sqlboot` from native PowerShell or CMD.

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

Set environment variables before running the installer:

```sh
SQLBOOT_ORACLE_PASSWORD='new-password' npx sqlboot
```

Available options:

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
```

## Real-World Notes

If the `oracle-xe` container already exists, Docker keeps the original database files. Changing `SQLBOOT_ORACLE_PASSWORD` later does not change the existing database password.

To reset the password for an existing container:

```sh
docker exec oracle-xe resetPassword new-password
```

If port `1521` is already in use, choose another host port:

```sh
SQLBOOT_ORACLE_PORT=1522 npx sqlboot
```

Then connect with the generated `XE` alias, or update `tnsnames.ora` if needed.

On Linux, you may need to log out and back in after Docker is installed so your user can access the Docker socket without `sudo`.

On Windows through WSL2, Docker is managed by Docker Desktop. `sqlboot` will not install or start Docker Engine with `systemctl` inside WSL.

On macOS, Docker Desktop may require first-run setup before the installer can continue.

## Troubleshooting

Check the container:

```sh
docker ps -a --filter name=oracle-xe
```

Check recent Oracle logs:

```sh
docker logs --tail 120 oracle-xe
```

Restart the container:

```sh
docker restart oracle-xe
```

If `sqlboot` waits at `Waiting for Oracle XE to be ready`, make sure the container is still running and has enough memory. Oracle XE can be slow on machines with low RAM or heavy swapping.

If `npx sqlboot` keeps using an older version:

```sh
npx sqlboot@latest
```

## Development

```sh
npm run check
npm run pack:dry
```

See [CHANGELOG.md](CHANGELOG.md) for version history.
