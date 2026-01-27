# KDB-X Tick Docker

A dockerized kdb+tick data pipeline using KDB-X, the latest release of kdb+ from KX.

## Overview

This project demonstrates how to deploy a complete kdb+ tick data pipeline in Docker containers using KDB-X. The setup includes:

- **Tickerplant** (Port 5010): Core message broker for real-time data
- **RDB** (Port 5011): Real-time database for current day data
- **HDB** (Port 5012): Historical database for persisted data
- **Gateway** (Port 5013): Unified query interface for RDB + HDB
- **Feed Handler**: Test data publisher

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
              │
              │ subscribe
              ▼
       ┌─────────────┐
       │ Tickerplant │ :5010
       │  (tick.q)   │
       └──────┬──────┘
              │
              │ publish
              ▼
       ┌─────────────┐
       │    Feed     │
       │  (feed.q)   │
       └─────────────┘
```

## Prerequisites

- Docker 20.10+
- KX Developer Portal account for KDB-X access
- Bearer token and base64 license from [KX Developer Portal](https://developer.kx.com/products/kdb-x/install)

## Quick Start

### 1. Configure Environment

Copy the example environment file and add your KX credentials:

```bash
cp kdbx.env.example kdbx.env
```

Edit `kdbx.env` with your credentials:
```
KX_BEARER_TOKEN=your_bearer_token_here
KX_LICENSE_B64=your_base64_license_here
```

### 2. Build the Image

```bash
# Load environment and build
export $(cat kdbx.env | xargs)
docker build \
  --build-arg KX_BEARER_TOKEN="${KX_BEARER_TOKEN}" \
  --build-arg KX_LICENSE_B64="${KX_LICENSE_B64}" \
  -t kdbx-tick \
  -f docker/Dockerfile .
```

### 3. Run the Container

```bash
docker run -d \
  --name kdbx-tick \
  -p 5010:5010 \
  -p 5011:5011 \
  -p 5012:5012 \
  -p 5013:5013 \
  -v $(pwd)/data:/data/tick \
  -v $(pwd)/scripts:/scripts \
  kdbx-tick
```

## Using the Gateway

The gateway provides a unified interface to query both real-time (RDB) and historical (HDB) data.

### Connect to Gateway

```q
// From q
h:hopen `:localhost:5013
```

```python
# From Python
import pykx as kx
gw = kx.SyncQConnection(host='localhost', port=5013)
```

### Query Functions

| Function | Description |
|----------|-------------|
| `getTradeData[sd;ed;ids]` | Get trades between dates for symbols |
| `getQuoteData[sd;ed;ids]` | Get quotes between dates for symbols |
| `getData[tbl;sd;ed;ids]` | Generic table query |
| `getTodayTrades[ids]` | Today's trades for symbols |
| `getTodayQuotes[ids]` | Today's quotes for symbols |
| `getRecentTrades[days;ids]` | Last N days of trades |
| `getRecentQuotes[days;ids]` | Last N days of quotes |
| `getVWAP[sd;ed;ids]` | Volume weighted average price |
| `getOHLC[sd;ed;ids]` | Open/High/Low/Close bars |
| `status[]` | Connection status |
| `reconnect[]` | Reconnect to RDB/HDB |

### Examples

```q
h:hopen `:localhost:5013

// Get all trades for today
h"getTodayTrades[`]"

// Get trades for specific symbols
h"getTodayTrades[`AAPL`MSFT`GOOG]"

// Get trades for date range
h"getTradeData[2024.01.01;.z.D;`AAPL`MSFT]"

// Get VWAP for last 7 days
h"getVWAP[.z.D-7;.z.D;`AAPL`MSFT]"

// Get OHLC (candlestick) data
h"getOHLC[.z.D-30;.z.D;`AAPL]"

// Check connection status
h"status[]"
```

## Ports

| Port | Service | Description |
|------|---------|-------------|
| 5010 | Tickerplant | Message broker, receives and logs all data |
| 5011 | RDB | Real-time database, current day in-memory |
| 5012 | HDB | Historical database, persisted data |
| 5013 | Gateway | Unified query interface |

## Environment Variables

### Build-time (Required)

| Variable | Description |
|----------|-------------|
| `KX_BEARER_TOKEN` | OAuth2 bearer token from KX Developer Portal |
| `KX_LICENSE_B64` | Base64-encoded KDB-X license |

### Runtime (Optional)

| Variable | Default | Description |
|----------|---------|-------------|
| `TICK_PORT` | 5010 | Tickerplant port |
| `RDB_PORT` | 5011 | RDB port |
| `HDB_PORT` | 5012 | HDB port |
| `GW_PORT` | 5013 | Gateway port |
| `TICK_DATA_DIR` | /data/tick | Data storage directory |

## Volume Mounts

| Container Path | Purpose |
|----------------|---------|
| `/data/tick` | Tick data, logs, and HDB partitions |
| `/scripts` | Custom q scripts |

## Health Check

The container includes a health check that verifies the tickerplant port (5010) is listening:

```bash
docker inspect --format='{{.State.Health.Status}}' kdbx-tick
```

## Logs

Logs are stored in `/opt/kx/kdb-tick/logs/`:

| Log File | Process |
|----------|---------|
| `tick.log` | Tickerplant |
| `rdb.log` | RDB |
| `hdb.log` | HDB |
| `gw.log` | Gateway |
| `feed.log` | Feed handler |

View logs:
```bash
docker exec kdbx-tick cat /opt/kx/kdb-tick/logs/gw.log
```

## Docker Image Architecture

The Dockerfile uses a multi-stage build:

### Stage 1: Base Image
- Ubuntu 24.04
- Python 3.13 from deadsnakes PPA
- rlwrap, lsof, unzip, and other utilities

### Stage 2: Builder
- Downloads and installs KDB-X using bearer token authentication
- Installs KDB-X to `~/.kx` directory

### Stage 3: Runtime
- Creates `kdb` user for security
- Copies KDB-X installation from builder
- Sets up Python virtual environment with pykx
- Configures tick system with volume mounts

## Tick System Components

| File | Description |
|------|-------------|
| `tick.q` | Tickerplant - receives data, logs to disk, publishes to subscribers |
| `r.q` | RDB - subscribes to tickerplant, stores today's data in memory |
| `hdb.q` | HDB - loads and serves historical partitioned data |
| `gw.q` | Gateway - routes queries to RDB/HDB, combines results |
| `feed.q` | Feed handler - publishes test trade data |
| `u.q` | Utilities - pub/sub helper functions |
| `sym.q` | Schema - trade and quote table definitions |

## References

- [KDB-X Documentation](https://code.kx.com/kdb-x/)
- [PyKX Documentation](https://code.kx.com/pykx/)
- [Original kdb+tick](https://github.com/KxSystems/kdb-tick)
- [KX Architecture Course](https://github.com/KxSystems/kdb-architecture-course)
