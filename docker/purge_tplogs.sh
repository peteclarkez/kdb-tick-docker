#!/bin/bash
# Purge old tickerplant log files based on the date in the filename.
# Tplog filenames follow the pattern: <schema><YYYY.MM.DD>  e.g. sym2026.02.14
#
# Usage: purge_tplogs.sh <tplog_dir> <retention_days>

TPLOG_DIR="${1:?Usage: purge_tplogs.sh <tplog_dir> <retention_days>}"
RETENTION_DAYS="${2:?Usage: purge_tplogs.sh <tplog_dir> <retention_days>}"

cutoff=$(date -d "${RETENTION_DAYS} days ago" +%Y%m%d)

deleted=0
for f in "${TPLOG_DIR}"/*; do
    [ -f "$f" ] || continue
    fname=$(basename "$f")

    # Extract the trailing YYYY.MM.DD date from the filename
    if [[ "$fname" =~ ([0-9]{4})\.([0-9]{2})\.([0-9]{2})$ ]]; then
        file_date="${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}"
        if [ "$file_date" -lt "$cutoff" ]; then
            rm -f "$f"
            echo "$(date '+%Y-%m-%d %H:%M:%S') purged tplog: ${fname}"
            ((deleted++))
        fi
    fi
done

if [ "$deleted" -eq 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') tplog purge: no files older than ${RETENTION_DAYS} days"
fi
