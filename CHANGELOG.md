# Changelog

All notable changes to this project will be documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [5.0.5] - 2025-02-20

### Added
- `TICK_SCHEMA` environment variable to configure the schema filename at runtime (default: `sym`)
- Schema filename shown in startup banner

### Changed
- `tick.sh` validates `${TICK_SCHEMA}.q` rather than hardcoded `sym.q`

## [5.0.4] - 2025-02-13

### Added
- Daily tplog purge job: files older than `TICK_TPLOG_RETENTION_DAYS` (default: 5) are removed at `TICK_TPLOG_PURGE_HOUR` (default: 3am)
- `docker/purge_tplogs.sh` — purge script, parses date from tplog filename
- `purge.log` — dedicated log for purge activity, included in container tail output
- `TICK_TPLOG_PURGE_HOUR` and `TICK_TPLOG_RETENTION_DAYS` environment variables

### Changed
- Updated `DEVELOPMENT.md` and `README.md` to document purge configuration

## [5.0.3] - 2025-01-30

### Added
- Handling for corrupted or incomplete tplog files on startup
- Acknowledgements section in README

### Changed
- Gateway cleanup: generic query functions and improved log messages

## [5.0.2] - 2025-01-27

### Added
- Migrated from kdb+ to KDB-X (latest KX release)
- Multi-stage Dockerfile using BuildKit secrets — credentials never stored in image layers
- Multi-architecture support (`linux/amd64`, `linux/arm64`) via `build.sh` and GitHub Actions
- Runtime license override via `KX_LICENSE_B64` environment variable
- `docker-compose.yml` with volume mounts for data, logs, tplogs, and scripts
- Quote table and HDB persistence utilities
- PyKX installed in virtual environment inside the image
- Gateway process with unified RDB + HDB query interface
- `kdbx.env.example` credential template

## [0.1.2] - 2024-01-01

### Fixed
- Docker automated build pipeline

## [0.1.1] - 2024-01-01

### Added
- Initial Dockerfile and project structure

## [0.1.0] - 2024-01-01

### Added
- Initial release — basic kdb+tick Docker container

[Unreleased]: https://github.com/peteclarkez/kdb-tick-docker/compare/v5.0.5...HEAD
[5.0.5]: https://github.com/peteclarkez/kdb-tick-docker/compare/v5.0.4...v5.0.5
[5.0.4]: https://github.com/peteclarkez/kdb-tick-docker/compare/v5.0.3...v5.0.4
[5.0.3]: https://github.com/peteclarkez/kdb-tick-docker/compare/v5.0.2...v5.0.3
[5.0.2]: https://github.com/peteclarkez/kdb-tick-docker/compare/0.1.2...v5.0.2
[0.1.2]: https://github.com/peteclarkez/kdb-tick-docker/compare/0.1.1...0.1.2
[0.1.1]: https://github.com/peteclarkez/kdb-tick-docker/compare/0.1.0...0.1.1
[0.1.0]: https://github.com/peteclarkez/kdb-tick-docker/releases/tag/0.1.0
