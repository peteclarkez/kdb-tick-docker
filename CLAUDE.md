# KDB-X Tick Docker - Development Progress

## Overview

This document tracks the progress of migrating from the old kxsys/embedpy base image to KDB-X with a multi-stage Docker build.

## Completed Work

### 1. Multi-Stage Dockerfile Created

The Dockerfile has been restructured into 3 stages:

**Stage 1: Base Image**
- Ubuntu 24.04
- Python 3.13 from deadsnakes PPA
- Packages: rlwrap, lsof, unzip, curl, ca-certificates

**Stage 2: Builder**
- Downloads and installs KDB-X using bearer token authentication
- Uses `-y` flag for non-interactive installation
- Requires build args: `KX_BEARER_TOKEN` and `KX_LICENSE_B64`

**Stage 3: Runtime**
- Creates `kdb` user for security
- Copies `.kx` folder from builder
- Sets up Python venv with pykx
- Configures tick system with volume mounts
- Includes healthcheck for tickerplant port

### 2. Environment Configuration

- Created `kdbx.env.example` as template
- Created `kdbx.env` with actual credentials (gitignored)
- Updated `.gitignore` to exclude `*.env` but include `*.env.example`

### 3. Updated Scripts

**tick.sh changes:**
- Configurable ports via environment variables
- Configurable data directory
- Uses rlwrap for better q experience
- Logs moved to `${Q_TICKHOME}/logs/`
- Changed connection strings to use `::${PORT}` format for localhost

**feed.q changes:**
- Now accepts tickerplant port as command line argument
- Removed `hsym` (was incorrectly used for IPC connections)

### 4. Build Commands

```bash
# Source credentials
source kdbx.env

# Build image
docker build \
  --build-arg KX_BEARER_TOKEN="${KX_BEARER_TOKEN}" \
  --build-arg KX_LICENSE_B64="${KX_LICENSE_B64}" \
  -t kdbx-tick \
  -f docker/Dockerfile .

# Run container
docker run -d \
  --name kdbx-tick \
  -p 5010:5010 \
  -p 5011:5011 \
  -v $(pwd)/data:/data/tick \
  -v $(pwd)/scripts:/scripts \
  kdbx-tick
```

## Status: COMPLETE

The tick system is fully functional with all components:
- Tickerplant listening on port 5010
- RDB listening on port 5011, subscribed to tickerplant
- HDB listening on port 5012, serves historical data
- Gateway listening on port 5013, unified query interface
- Feed handler publishing trade AND quote data every 10 seconds
- HDB persistence via end-of-day save (manual trigger available via `triggerEOD[]`)
- Docker Compose for easy deployment
- Runtime license override support
- Healthcheck passing

### Previous Issue: RDB subscription error (RESOLVED)

The RDB was failing with `.u.sub` error. Root cause: the `r.q` script internally prepends a colon to the connection string (line 19: `hopen \`$":",.u.x 0`), so passing `::5010` resulted in `:::5010` which is invalid.

**Fix:** Pass `:5010` format to r.q (single colon), which becomes `::5010` after r.q adds its colon.

## Files Changed

| File | Status |
|------|--------|
| docker/Dockerfile | Rewritten - 3-stage build |
| docker/tick.sh | Updated - starts all 5 processes, tails all logs |
| docker/kx-license.sh | New - runtime license override |
| docker-compose.yml | New - easy deployment |
| kdb-tick/tick/feed.q | Rewritten - publishes trade AND quote data |
| kdb-tick/tick/r.q | Updated - selectFunc, triggerEOD, rdbStats |
| kdb-tick/tick/hdb.q | New - historical database loader |
| kdb-tick/tick/gw.q | New - gateway with unified query functions |
| README.md | Rewritten - comprehensive documentation |
| .gitignore | Updated - added patterns |
| kdbx.env.example | New - credential template |

## Git Status

- Branch: `kdbx`
- Last commit: `74e396c` - "Update to KDB-X with multi-stage Docker build"
- Author: Peter Clarke <pete@clarkez.co.uk>

## Next Steps

1. ~~Debug the RDB subscription error in r.q~~ DONE
2. ~~Verify feed handler is publishing data correctly~~ DONE
3. ~~Test end-to-end data flow: feed → tickerplant → RDB~~ DONE
4. ~~Enable HDB for historical data persistence~~ DONE
5. ~~Add docker-compose for easier deployment~~ DONE
6. ~~Consider adding more feed data types (quotes)~~ DONE

All next steps completed!
