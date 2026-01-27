#!/bin/bash
# KDB-X Tick System Startup Script
# Starts tickerplant, RDB, HDB, Gateway, and feed handler processes

set -e

# Source the license setup script to handle runtime license override
# This allows KX_LICENSE_B64 env var to override the build-time license
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/kx-license.sh" ]]; then
    source "${SCRIPT_DIR}/kx-license.sh"
elif [[ -f "/etc/profile.d/kx-license.sh" ]]; then
    source "/etc/profile.d/kx-license.sh"
fi

# Use environment variables with defaults
TICK_HOME="${Q_TICKHOME:-/opt/kx/kdb-tick}"
DATA_DIR="${TICK_DATA_DIR:-/data/tick}"
TICK_PORT="${TICK_PORT:-5010}"
RDB_PORT="${RDB_PORT:-5011}"
HDB_PORT="${HDB_PORT:-5012}"
GW_PORT="${GW_PORT:-5013}"

cd "${TICK_HOME}"

# Create directories
mkdir -p "${TICK_HOME}/logs"
mkdir -p "${DATA_DIR}"

echo "============================================="
echo "Starting KDB-X Tick System"
echo "============================================="
echo "Tick Home: ${TICK_HOME}"
echo "Data Directory: ${DATA_DIR}"
echo ""
echo "Ports:"
echo "  Tickerplant: ${TICK_PORT}"
echo "  RDB:         ${RDB_PORT}"
echo "  HDB:         ${HDB_PORT}"
echo "  Gateway:     ${GW_PORT}"
echo "============================================="

# Initialize log files
touch "${TICK_HOME}/logs/tick.log"

# Start Tickerplant (Port 5010 by default)
echo "Starting Tickerplant on port ${TICK_PORT}..."
nohup rlwrap q tick.q sym "${DATA_DIR}" -p "${TICK_PORT}" \
    < /dev/null > "${TICK_HOME}/logs/tick.log" 2>&1 &

# Wait for tickerplant to be ready
sleep 2

# Start RDB (Real-time Database) on port 5011 by default
# Note: r.q expects ":port" format - it adds another colon internally for localhost
echo "Starting RDB on port ${RDB_PORT}..."
nohup rlwrap q tick/r.q ":${TICK_PORT}" ":${HDB_PORT}" -p "${RDB_PORT}" \
    < /dev/null > "${TICK_HOME}/logs/rdb.log" 2>&1 &

# Wait for RDB to be ready
sleep 1

# Start HDB (Historical Database) on port 5012 by default
echo "Starting HDB on port ${HDB_PORT}..."
nohup rlwrap q tick/hdb.q "${DATA_DIR}" -p "${HDB_PORT}" \
    < /dev/null > "${TICK_HOME}/logs/hdb.log" 2>&1 &

# Wait for HDB to be ready
sleep 1

# Start Gateway on port 5013 by default
echo "Starting Gateway on port ${GW_PORT}..."
nohup rlwrap q tick/gw.q ":${RDB_PORT}" ":${HDB_PORT}" -p "${GW_PORT}" \
    < /dev/null > "${TICK_HOME}/logs/gw.log" 2>&1 &

# Wait for Gateway to be ready
sleep 1

# Start Feed Handler (data publisher)
# Note: feed.q expects "::port" format for localhost connection
echo "Starting Feed Handler..."
nohup rlwrap q tick/feed.q "::${TICK_PORT}" \
    < /dev/null > "${TICK_HOME}/logs/feed.log" 2>&1 &

echo ""
echo "============================================="
echo "KDB-X Tick System started successfully"
echo "============================================="
echo ""
echo "Process status:"
ps aux | grep -E "q (tick|feed)" | grep -v grep || true
echo ""
echo "Tailing all logs..."

# Keep container running and show all logs
tail -f "${TICK_HOME}/logs/tick.log" \
       "${TICK_HOME}/logs/rdb.log" \
       "${TICK_HOME}/logs/hdb.log" \
       "${TICK_HOME}/logs/gw.log" \
       "${TICK_HOME}/logs/feed.log"
