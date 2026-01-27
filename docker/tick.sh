#!/bin/bash
# KDB-X Tick System Startup Script
# Starts tickerplant, RDB, HDB, Gateway, and optionally feed handler processes

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
# Core directories
TICK_HOME="${Q_TICKHOME:-/opt/kx/kdb-tick}"

# External mount points
DATA_DIR="${TICK_DATA_DIR:-/data}"           # HDB data (date partitions)
LOG_DIR="${TICK_LOG_DIR:-/logs}"             # Application logs
TPLOG_DIR="${TICK_TPLOG_DIR:-/tplogs}"       # Tickerplant event logs
SCRIPTS_DIR="${TICK_SCRIPTS_DIR:-/scripts}"  # User customization scripts

# Ports
TICK_PORT="${TICK_PORT:-5010}"
RDB_PORT="${RDB_PORT:-5011}"
HDB_PORT="${HDB_PORT:-5012}"
GW_PORT="${GW_PORT:-5013}"

# Export for q processes to use
export TICK_HDB_DIR="${DATA_DIR}"
export TICK_SCRIPTS_DIR="${SCRIPTS_DIR}"

cd "${TICK_HOME}"

# Validate required files
if [[ ! -f "${SCRIPTS_DIR}/sym.q" ]]; then
    echo "============================================="
    echo "ERROR: Required file not found!"
    echo "============================================="
    echo ""
    echo "The file ${SCRIPTS_DIR}/sym.q is required but was not found."
    echo ""
    echo "This file defines the table schemas (trade, quote, etc.) for your"
    echo "tick system. You must mount a scripts directory containing sym.q."
    echo ""
    echo "Example:"
    echo "  docker run -v ./scripts:/scripts ..."
    echo ""
    echo "See scripts/sym.q in the repository for an example."
    echo "============================================="
    exit 1
fi

# Create directories (mount points should exist, but ensure subdirs)
mkdir -p "${LOG_DIR}"
mkdir -p "${DATA_DIR}"
mkdir -p "${TPLOG_DIR}"

echo "============================================="
echo "Starting KDB-X Tick System"
echo "============================================="
echo "Tick Home:    ${TICK_HOME}"
echo ""
echo "Mount Points:"
echo "  Data (HDB):    ${DATA_DIR}"
echo "  Logs:          ${LOG_DIR}"
echo "  TP Logs:       ${TPLOG_DIR}"
echo "  Scripts:       ${SCRIPTS_DIR}"
echo ""
echo "Ports:"
echo "  Tickerplant: ${TICK_PORT}"
echo "  RDB:         ${RDB_PORT}"
echo "  HDB:         ${HDB_PORT}"
echo "  Gateway:     ${GW_PORT}"
echo "============================================="

# Initialize log files
touch "${LOG_DIR}/tick.log"
touch "${LOG_DIR}/rdb.log"
touch "${LOG_DIR}/hdb.log"
touch "${LOG_DIR}/gw.log"

# Start Tickerplant (Port 5010 by default)
# Tickerplant writes event logs to TPLOG_DIR
echo "Starting Tickerplant on port ${TICK_PORT}..."
nohup rlwrap q tick.q sym "${TPLOG_DIR}" -p "${TICK_PORT}" \
    < /dev/null > "${LOG_DIR}/tick.log" 2>&1 &

# Wait for tickerplant to be ready
sleep 2

# Start RDB (Real-time Database) on port 5011 by default
# Note: r.q expects ":port" format - it adds another colon internally for localhost
# RDB uses TICK_HDB_DIR env var to know where to save EOD data
echo "Starting RDB on port ${RDB_PORT}..."
nohup rlwrap q tick/r.q ":${TICK_PORT}" ":${HDB_PORT}" -p "${RDB_PORT}" \
    < /dev/null > "${LOG_DIR}/rdb.log" 2>&1 &

# Wait for RDB to be ready
sleep 1

# Start HDB (Historical Database) on port 5012 by default
# HDB loads data from DATA_DIR
echo "Starting HDB on port ${HDB_PORT}..."
nohup rlwrap q tick/hdb.q "${DATA_DIR}" -p "${HDB_PORT}" \
    < /dev/null > "${LOG_DIR}/hdb.log" 2>&1 &

# Wait for HDB to be ready
sleep 1

# Start Gateway on port 5013 by default
echo "Starting Gateway on port ${GW_PORT}..."
nohup rlwrap q tick/gw.q ":${RDB_PORT}" ":${HDB_PORT}" -p "${GW_PORT}" \
    < /dev/null > "${LOG_DIR}/gw.log" 2>&1 &

# Wait for Gateway to be ready
sleep 1

# Start Feed Handler (data publisher) - only if feed.q exists in scripts
# Note: feed.q expects "::port" format for localhost connection
# The -p flag is required to keep the q process alive for timer events
FEED_PORT="${TICK_FEED_PORT:-5014}"
if [[ -f "${SCRIPTS_DIR}/feed.q" ]]; then
    echo "Starting Feed Handler from ${SCRIPTS_DIR}/feed.q..."
    touch "${LOG_DIR}/feed.log"
    nohup rlwrap q "${SCRIPTS_DIR}/feed.q" "::${TICK_PORT}" -p "${FEED_PORT}" \
        < /dev/null > "${LOG_DIR}/feed.log" 2>&1 &
else
    echo "No feed.q found in ${SCRIPTS_DIR} - skipping feed handler"
fi

echo ""
echo "============================================="
echo "KDB-X Tick System started successfully"
echo "============================================="
echo ""
echo "Process status:"
ps aux | grep -E "q.*(tick|r\.q|hdb|gw|feed)" | grep -v grep || true
echo ""
echo "Tailing logs..."

# Build list of log files to tail (only existing ones)
LOG_FILES="${LOG_DIR}/tick.log ${LOG_DIR}/rdb.log ${LOG_DIR}/hdb.log ${LOG_DIR}/gw.log"
if [[ -f "${LOG_DIR}/feed.log" ]]; then
    LOG_FILES="${LOG_FILES} ${LOG_DIR}/feed.log"
fi

# Keep container running and show all logs
tail -f ${LOG_FILES}
