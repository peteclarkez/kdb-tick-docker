# Contributing

Contributions are welcome — bug reports, documentation improvements, and pull requests all help.

## Reporting Bugs

Open an issue and include:
- What you did
- What you expected to happen
- What actually happened
- Output of `docker compose logs` if relevant
- Your platform (`uname -a`, Docker version)

## Suggesting Features

Open an issue describing the use case and the behaviour you'd like to see.

## Pull Requests

1. Fork the repository and create a branch from `master`
2. Make your changes
3. Update `CHANGELOG.md` under `[Unreleased]`
4. Open a pull request — describe what the change does and why

Keep PRs focused. One feature or fix per PR makes review easier.

## Development Setup

### Prerequisites

- Docker with BuildKit support
- A KDB-X license and bearer token from the [KX Developer Portal](https://developer.kx.com/products/kdb-x/install)
- For multi-arch builds: QEMU + Docker buildx (see [DEVELOPMENT.md](DEVELOPMENT.md))

### Local Build

```bash
cp kdbx.env.example kdbx.env
# Fill in KX_BEARER_TOKEN and KX_LICENSE_B64

mkdir -p data logs tplogs
cp scripts/sym.q scripts/sym.q   # already present in the repo

docker compose --env-file kdbx.env up --build
```

### Running Against a Pre-Built Image

```bash
docker pull peteclarkez/kdbx-tick:latest
docker compose --env-file kdbx.env up
```

## Notes

- `kdbx.env` is gitignored — never commit credentials
- `data/`, `logs/`, and `tplogs/` are gitignored — never commit runtime state
- The core tick scripts (`kdb-tick/`) are vendored from [KxSystems/kdb-tick](https://github.com/KxSystems/kdb-tick) and are subject to the KX licence terms

## Licence

By contributing you agree that your changes will be released under the [MIT Licence](LICENSE).
