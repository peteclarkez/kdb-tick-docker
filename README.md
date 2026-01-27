# KDB-X Tick Docker

A dockerized kdb+tick data pipeline using KDB-X, the latest release of kdb+ from KX.

## Overview

This project provides a generic, customizable kdb+ tick data pipeline in Docker. The core tick system is built into the image, while table schemas and custom functions are provided via mounted volumes.

Components:
- **Tickerplant** (Port 5010): Core message broker for real-time data
- **RDB** (Port 5011): Real-time database for current day data
- **HDB** (Port 5012): Historical database for persisted data
- **Gateway** (Port 5013): Unified query interface for RDB + HDB
- **Feed Handler** (optional): Test data publisher

## Architecture

```
                    ┌─────────────┐
                    │   Gateway   │ :5013
                    │   (gw.q)    │
                    └──────┬──────┘
                           │
              ┌────────────┴────────────┐
              │                         │
              ▼                         ▼
       ┌─────────────┐          ┌─────────────┐
       │     RDB     │          │     HDB     │
       │    (r.q)    │ :5011    │   (hdb.q)   │ :5012
       └──────┬──────┘          └─────────────┘
              │                        ▲
              │ subscribe              │ load
              ▼                        │
       ┌─────────────┐          ┌─────────────┐
       │ Tickerplant │          │   /data     │
       │  (tick.q)   │ :5010    │  (HDB data) │
       └──────┬──────┘          └─────────────┘
              │
              │ publish
              ▼
       ┌─────────────┐
       │    Feed     │
       │  (feed.q)   │  ← from /scripts
       └─────────────┘
```

## Volume Mounts

The system uses four external mount points for separation of concerns:

| Mount Point | Purpose | Contents |
|-------------|---------|----------|
| `/data` | HDB data | Date partitions (2024.01.27/), sym file |
| `/logs` | Application logs | tick.log, rdb.log, hdb.log, gw.log, feed.log |
| `/tplogs` | Tickerplant event logs | Binary event logs (sym2024.01.27) |
| `/scripts` | User customization | sym.q (required), feed.q, *_custom.q (optional) |

## Quick Start

### 1. Configure Environment

```bash
cp kdbx.env.example kdbx.env
# Edit kdbx.env with your KX credentials
```

### 2. Create Mount Directories

```bash
mkdir -p data logs tplogs scripts
```

### 3. Add Required Scripts

The `scripts/sym.q` file is **required** - it defines your table schemas:

```bash
# Copy the example scripts
cp scripts/sym.q scripts/
cp scripts/feed.q scripts/       # Optional: enables test data feed
cp scripts/rdb_custom.q scripts/ # Optional: custom RDB functions
```

### 4. Build and Run

```bash
# Using docker compose (recommended)
docker compose --env-file kdbx.env up -d --build

# View logs
docker compose logs -f

# Stop
docker compose --env-file kdbx.env down
```

## Customization via /scripts

### Required: sym.q

Defines table schemas. Must be mounted at `/scripts/sym.q`:

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
└── feed.log             # Feed handler application log
```

## Environment Variables

### Build-time (Required)

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
| `TICK_SCRIPTS_DIR` | /scripts | User scripts directory |

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

The Dockerfile uses a multi-stage build:

1. **Base**: Ubuntu 24.04 + Python 3.13 + utilities
2. **Builder**: Downloads and installs KDB-X
3. **Runtime**: kdb user, tick system, volume mounts

Core tick scripts (tick.q, r.q, hdb.q, gw.q, u.q) are built into the image.
User customization (sym.q, feed.q, *_custom.q) comes from /scripts mount.

## References

- [KDB-X Documentation](https://code.kx.com/kdb-x/)
- [PyKX Documentation](https://code.kx.com/pykx/)
- [Original kdb+tick](https://github.com/KxSystems/kdb-tick)
- [KX Architecture Course](https://github.com/KxSystems/kdb-architecture-course)
