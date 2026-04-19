# Changelog

All notable changes to `sqlboot` are tracked here.

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
