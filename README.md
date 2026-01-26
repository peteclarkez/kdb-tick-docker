# KDB-X Tick Docker

A dockerized kdb+tick data pipeline using KDB-X, the latest release of kdb+ from KX.

## Overview

This project demonstrates how to deploy a kdb+ tick data pipeline in Docker containers using KDB-X. The setup includes:
- **Tickerplant** (Port 5010): Core message broker for real-time data
- **RDB** (Port 5011): Real-time database for current day data
- **HDB** (Port 5012): Historical database (optional, disabled by default)
- **Feed Handler**: Test data publisher

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
# Using environment file
source kdbx.env
docker build \
  --build-arg KX_BEARER_TOKEN="${KX_BEARER_TOKEN}" \
  --build-arg KX_LICENSE_B64="${KX_LICENSE_B64}" \
  -t kdbx-tick \
  -f docker/Dockerfile .
```

Or pass arguments directly:

```bash
docker build \
  --build-arg KX_BEARER_TOKEN="your_token" \
  --build-arg KX_LICENSE_B64="your_license" \
  -t kdbx-tick \
  -f docker/Dockerfile .
```

### 3. Run the Container

```bash
docker run -d \
  --name kdbx-tick \
  -p 5010:5010 \
  -p 5011:5011 \
  -v $(pwd)/data:/data/tick \
  -v $(pwd)/scripts:/scripts \
  kdbx-tick
```

Or interactively:

```bash
docker run -it \
  -p 5010:5010 \
  -p 5011:5011 \
  -v $(pwd)/data:/data/tick \
  -v $(pwd)/scripts:/scripts \
  kdbx-tick
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
| `TICK_DATA_DIR` | /data/tick | Data storage directory |

## Volume Mounts

| Container Path | Purpose |
|----------------|---------|
| `/data/tick` | Tick data and log files |
| `/scripts` | Custom q scripts |

## Ports

| Port | Service |
|------|---------|
| 5010 | Tickerplant |
| 5011 | Real-time Database (RDB) |
| 5012 | Historical Database (HDB) |

## Health Check

The container includes a health check that verifies the tickerplant port (5010) is listening:

```bash
docker inspect --format='{{.State.Health.Status}}' kdbx-tick
```

## Connecting to the System

### From q/kdb+
```q
// Connect to tickerplant
h:hopen `:localhost:5010

// Connect to RDB
r:hopen `:localhost:5011
```

### From Python (pykx)
```python
import pykx as kx

# Connect to RDB
conn = kx.SyncQConnection(host='localhost', port=5011)
result = conn('select from trade')
```

## Tick System Changes

Based on the standard kdb+tick with the following modifications:
- Time column uses `timestamp` type (nanosecond precision) instead of `timespan`
- Added `sym.q` with trade and quote table schemas
- Added `feed.q` for test data generation
- Feed handler now accepts tickerplant port as command line argument

## Development

### Logs

Logs are stored in `/opt/kx/kdb-tick/logs/`:
- `tick.log` - Tickerplant logs
- `rdb.log` - RDB logs
- `feed.log` - Feed handler logs

### Custom Scripts

Mount custom scripts to `/scripts` and load them from your q session:
```q
\l /scripts/myscript.q
```

## TODO

- Enable HDB process by default
- Add gateway processes for single entry point
- Add docker-compose for multi-container deployment

## References

- [KDB-X Documentation](https://code.kx.com/kdb-x/)
- [PyKX Documentation](https://code.kx.com/pykx/)
- [Original kdb+tick](https://github.com/KxSystems/kdb-tick)
