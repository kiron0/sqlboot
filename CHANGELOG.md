# Changelog

All notable changes to `sqlboot` are tracked here.

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
