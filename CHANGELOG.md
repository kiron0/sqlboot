# Changelog

All notable changes to `sqlboot` are tracked here.

## 1.0.6

- Added a Windows PowerShell bootstrapper for running `npx sqlboot init` from native Windows.
- Windows bootstrap now prepares WSL2 Ubuntu and Docker Desktop where possible, then runs the existing Linux installer inside WSL.
- Added Windows command forwarding for `start`, `status`, `logs`, `doctor`, `stop`, `reset-pwd`, and `uninstall`.
- Added `sqlboot uninstall --purge` to remove Windows-side sqlboot setup, including Docker Desktop, the sqlboot WSL distro, and Windows WSL optional features.
- Added a SQL*Plus runtime dependency repair for missing `libaio.so.1` on Linux/WSL start.
- Added Windows-side WSL preflight repair for SQL*Plus runtime dependencies before `sqlboot start`.
- Added cleanup for temporary Instant Client ZIP downloads and apt package cache after setup.
- Added stronger Ubuntu 24.04 `libaio` fallback handling for SQL*Plus, including `libaio1t64`, `libaio-dev`, `universe`, and direct package install fallback.
- Added last-resort `libaio.so.1` extraction from the Ubuntu package payload when apt cannot install the runtime package.
- Expanded `libaio.so.1` extraction fallback across multiple Ubuntu and Debian package URLs with visible repair tracing.
- Fixed SQL*Plus `libaio.so.1` validation to test with the Instant Client directory in `LD_LIBRARY_PATH`, matching the real launch environment.
- Expanded Windows purge to remove Ubuntu and WSL app packages where Windows exposes them.
- Improved missing-WSL handling so Windows WSL features are installed by SQLBoot instead of only prompting the user.
- Replaced Docker Desktop WSL integration dependency with a WSL Docker proxy to Windows Docker Desktop.
- Expanded Windows purge to remove installed/provisioned WSL app packages and WSL capabilities where Windows allows it.
- Changed Windows WSL setup to avoid bare `wsl --install` paths and prefer explicit `wsl --install Ubuntu`.
- Fixed Windows purge WSL feature cleanup to also match modern dotted WSL capability names and use Windows optional-feature APIs.
- Improved Windows purge feedback by streaming the WSL uninstall live and warning when Ubuntu may ask for the sudo password.
- Clarified Windows purge completion output so users know SQLBoot cannot remove the Windows-owned `C:\Windows\System32\wsl.exe` system stub.
- Added self-repair for WSL Docker Desktop proxy credential-helper lookup failures during Oracle image pulls.
- Added Instant Client download stall timeouts and retries so Oracle downloads do not hang forever at 0 bytes.
- Fixed Windows purge exit-code handling so normal uninstall output is not mistaken for a failure status.

## 1.0.5

- Added `sqlboot uninstall` to remove sqlboot-managed resources.
- Added strict command validation so invalid commands and extra arguments fail instead of defaulting to install.
- Removed dashed sqlboot compatibility options; use plain commands like `sqlboot init`, `sqlboot start`, and `sqlboot help`.
- Added Vitest coverage for uninstall command forwarding.

## 1.0.4

- Switched CLI build pipeline to `tsup`.
- Added bundled `dist/index.js` output with `terser` minification.
- Expanded npm package metadata with homepage, repository, issue tracker, author, and contributor details.
- Rewrote README for richer npm-facing production documentation.
- Added `help`, `status`, `logs`, `doctor`, `reset-pwd`, and `stop` commands.
- Standardized init flow around `sqlboot init`.

## 1.0.3

- Converted npm CLI entrypoint from JavaScript to TypeScript without changing runtime behavior.
- Reorganized source into `cli`, `constants`, `helpers`, `types`, and `utils`.
- Added Vitest coverage for help, platform checks, installer checks, and spawn behavior.
- Updated published CLI output to `dist/index.js`.

## 1.0.2

- Added explicit WSL detection.
- Supported Windows through WSL2 Ubuntu instead of native Windows.
- In WSL, `sqlboot` now requires Docker Desktop WSL integration and avoids `systemctl`.
- Added this changelog for version tracking.

## 1.0.1

- Improved Oracle XE readiness checks.
- Limited Docker log scanning to recent logs.
- Added a SQL*Plus connection probe before launching SQL*Plus.
- Added troubleshooting notes for containers that appear stuck during startup.

## 1.0.0

- Initial npm CLI release.
- Added macOS and Ubuntu-based Linux setup.
- Added Docker Oracle XE setup with `gvenzl/oracle-xe:21-slim`.
- Added Oracle Instant Client and SQL*Plus installation.
- Added `rlwrap` integration with persistent history.
- Added `tnsnames.ora` generation with the `XE` alias.
- Added `/usr/local/bin/sqlboot` launcher.
