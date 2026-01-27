#!/bin/bash
# KDB-X Tick System Startup Script
# Starts tickerplant, RDB, and feed handler processes

set -e

# Use environment variables with defaults
TICK_HOME="${Q_TICKHOME:-/opt/kx/kdb-tick}"
DATA_DIR="${TICK_DATA_DIR:-/data/tick}"
TICK_PORT="${TICK_PORT:-5010}"
RDB_PORT="${RDB_PORT:-5011}"
HDB_PORT="${HDB_PORT:-5012}"

cd "${TICK_HOME}"

# Create log directory
mkdir -p "${TICK_HOME}/logs"

# Create data directory if it doesn't exist
mkdir -p "${DATA_DIR}"

echo "Starting KDB-X Tick System..."
echo "Tick Home: ${TICK_HOME}"
echo "Data Directory: ${DATA_DIR}"
echo "Tickerplant Port: ${TICK_PORT}"
echo "RDB Port: ${RDB_PORT}"

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
nohup rlwrap q tick/r.q ":${TICK_PORT}" -p "${RDB_PORT}" \
    < /dev/null > "${TICK_HOME}/logs/rdb.log" 2>&1 &

# Uncomment to enable HDB (Historical Database) on port 5012
# echo "Starting HDB on port ${HDB_PORT}..."
# nohup rlwrap q sym -p "${HDB_PORT}" \
#     < /dev/null > "${TICK_HOME}/logs/hdb.log" 2>&1 &

# Start Feed Handler (data publisher)
# Note: feed.q expects "::port" format for localhost connection
echo "Starting Feed Handler..."
nohup rlwrap q tick/feed.q "::${TICK_PORT}" \
    < /dev/null > "${TICK_HOME}/logs/feed.log" 2>&1 &

echo "KDB-X Tick System started successfully"
echo "Tailing tickerplant log..."

# Keep container running and show tick log
tail -f "${TICK_HOME}/logs/tick.log"
