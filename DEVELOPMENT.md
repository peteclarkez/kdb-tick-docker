# Development Guide

## Customization via /scripts

### Required: Schema file (default: sym.q)

Defines table schemas. Must be mounted at `/scripts/<schema>.q` (default `/scripts/sym.q`).

To use a different schema filename, set the `TICK_SCHEMA` environment variable:

```bash
TICK_SCHEMA=myschema  # will load /scripts/myschema.q
```

```q
/ Table schemas
trade:([]time:`timestamp$();sym:`symbol$();price:`float$();size:`int$())
quote:([]time:`timestamp$();sym:`symbol$();bid:`float$();ask:`float$();bsize:`int$();asize:`int$())
```

### Optional: feed.q

If present, the feed handler will start automatically and publish test data:

```q
/ Custom feed handler
/ See scripts/feed.q for example
```

### Optional: Custom Functions

Add custom analytics by creating these files:

| File | Loaded By | Purpose |
|------|-----------|---------|
| `rdb_custom.q` | RDB | Real-time analytics |
| `hdb_custom.q` | HDB | Historical analytics |
| `gw_custom.q` | Gateway | Cross-database analytics |

Example `rdb_custom.q`:
```q
/ Get last trade for each symbol
lastTrades:{select last time, last price, last size by sym from trade};
```

## Using the Gateway

### HTTP API (curl)

```bash
# Check status
curl "http://localhost:5013?status[]"

# Get trade count
curl "http://localhost:5013?count%20getTodayTrades[\`]"

# Get recent trades
curl "http://localhost:5013?-5%23getTodayTrades[\`]"
```

### IPC Connection

```q
// From q
h:hopen `:localhost:5013
h"getTodayTrades[`AAPL`MSFT]"
```

```python
# From Python
import pykx as kx
gw = kx.SyncQConnection(host='localhost', port=5013)
gw('getTodayTrades[`AAPL`MSFT]')
```

### Query Functions

| Function | Description |
|----------|-------------|
| `getTradeData[sd;ed;ids]` | Get trades between dates for symbols |
| `getQuoteData[sd;ed;ids]` | Get quotes between dates for symbols |
| `getData[tbl;sd;ed;ids]` | Generic table query |
| `getTodayTrades[ids]` | Today's trades for symbols |
| `getTodayQuotes[ids]` | Today's quotes for symbols |
| `getVWAP[sd;ed;ids]` | Volume weighted average price |
| `getOHLC[sd;ed;ids]` | Open/High/Low/Close bars |
| `status[]` | Connection status |
| `rdbStats[]` | RDB record counts and HDB directory |
| `triggerEOD[]` | Manual end-of-day save |

## HDB Persistence

At end-of-day (midnight), the RDB automatically saves data to `/data` and signals the HDB to reload.

### Manual EOD Save

```q
h:hopen `:localhost:5013
h"rdbStats[]"      // Check current state
h"triggerEOD[]"    // Save to HDB (clears RDB!)
```

### Data Directory Structure

```
/data/
├── 2024.01.27/          # Date partition
│   ├── trade/           # Trade table columns
│   └── quote/           # Quote table columns
└── sym                  # Symbol enumeration file

/tplogs/
└── sym2024.01.27        # Tickerplant binary event log

/logs/
├── tick.log             # Tickerplant application log
├── rdb.log              # RDB application log
├── hdb.log              # HDB application log
├── gw.log               # Gateway application log
├── feed.log             # Feed handler application log
└── purge.log            # Tplog purge job log
```

## Environment Variables

### Build-time (Required)

These are passed as BuildKit secrets (not build args) so they don't appear in image layer metadata:

| Variable | Description |
|----------|-------------|
| `KX_BEARER_TOKEN` | OAuth2 bearer token from KX Developer Portal |
| `KX_LICENSE_B64` | Base64-encoded KDB-X license |

### Runtime (Optional)

| Variable | Default | Description |
|----------|---------|-------------|
| `KX_LICENSE_B64` | (build-time) | Override license at runtime |
| `TICK_PORT` | 5010 | Tickerplant port |
| `RDB_PORT` | 5011 | RDB port |
| `HDB_PORT` | 5012 | HDB port |
| `GW_PORT` | 5013 | Gateway port |
| `TICK_DATA_DIR` | /data | HDB data directory |
| `TICK_LOG_DIR` | /logs | Application logs directory |
| `TICK_TPLOG_DIR` | /tplogs | Tickerplant event logs |
| `TICK_SCHEMA` | sym | Schema filename (without .q extension) |
| `TICK_SCRIPTS_DIR` | /scripts | User scripts directory |
| `TICK_TPLOG_PURGE_HOUR` | 3 | Hour of day (0-23) to run tplog purge |
| `TICK_TPLOG_RETENTION_DAYS` | 5 | Number of days to retain tplog files |

## Ports

| Port | Service | Description |
|------|---------|-------------|
| 5010 | Tickerplant | Message broker, receives and logs all data |
| 5011 | RDB | Real-time database, current day in-memory |
| 5012 | HDB | Historical database, persisted data |
| 5013 | Gateway | Unified query interface |

## Health Check

```bash
docker inspect --format='{{.State.Health.Status}}' kdbx-tick
```

## Docker Image Architecture

The Dockerfile uses a multi-stage build supporting `linux/amd64` and `linux/arm64`:

1. **Base**: Ubuntu 24.04 + Python 3.13 + utilities
2. **Builder**: Downloads and installs KDB-X (uses BuildKit secrets for credentials)
3. **Runtime**: kdb user, tick system, volume mounts

Core tick scripts (tick.q, r.q, hdb.q, gw.q, u.q) are built into the image.
User customization (sym.q, feed.q, *_custom.q) comes from /scripts mount.

## Multi-Architecture Builds

The image supports `linux/amd64` and `linux/arm64`. Pre-built images are available on Docker Hub.

### Pulling Pre-Built Images

```bash
docker pull peteclarkez/kdbx-tick:latest
```

Then deploy with docker compose (no `--build` flag):

```bash
source kdbx.env
docker compose --env-file kdbx.env up -d
```

### Building Multi-Arch Images

One-time host setup:

```bash
# Register QEMU handlers for cross-platform emulation
docker run --privileged --rm tonistiigi/binfmt --install all

# Create a buildx builder with multi-platform support
docker buildx create --name multiarch --driver docker-container --bootstrap --use

# Log in to Docker Hub
docker login
```

Build and push (`kdbx.env` is auto-sourced):

```bash
./build.sh              # pushes with tag 'latest'
./build.sh v1.0.0       # pushes with tag 'v1.0.0'
```

The `DOCKER_REPO`, `PLATFORMS`, and `BUILDER_NAME` environment variables can be set to override defaults.

### Automated Builds (GitHub Actions)

Images are automatically built and pushed to Docker Hub when a version tag is pushed:

```bash
git tag v1.0.0
git push origin v1.0.0
```

This triggers a GitHub Actions workflow that builds for `linux/amd64` and `linux/arm64` and pushes to `peteclarkez/kdbx-tick` with semver tags (`1.0.0`, `1.0`, `1`, `latest`).

Required GitHub secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `KX_BEARER_TOKEN`, `KX_LICENSE_B64`.