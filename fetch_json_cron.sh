#!/bin/bash

# Single-execution JSON fetcher (for use with cron)
# Add to crontab: */5 * * * * /path/to/fetch_json_cron.sh

set -euo pipefail

# Configuration
URL="${FETCH_URL:-https://api.example.com/data}"
OUTPUT_DIR="${FETCH_OUTPUT_DIR:-$HOME/json_data}"
LOG_FILE="${OUTPUT_DIR}/fetch_cron.log"
MAX_FILE_AGE_DAYS=7

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Fetch and save JSON
fetch() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local output_file="${OUTPUT_DIR}/data_${timestamp}.json"
    local temp_file="${output_file}.tmp"

    # Fetch JSON
    if curl -fsSL \
        --max-time 30 \
        --connect-timeout 10 \
        -H "Accept: application/json" \
        "${FETCH_HEADERS[@]}" \
        "$URL" \
        -o "$temp_file" 2>>"$LOG_FILE"; then

        # Validate JSON
        if command -v jq &>/dev/null && jq empty "$temp_file" 2>/dev/null; then
            mv "$temp_file" "$output_file"
            ln -sf "$(basename "$output_file")" "${OUTPUT_DIR}/latest.json"

            local size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file")
            log "SUCCESS: Fetched ${size} bytes -> $output_file"

            # Cleanup old files
            find "$OUTPUT_DIR" -name "data_*.json" -type f -mtime +${MAX_FILE_AGE_DAYS} -delete

            # Optional: Run post-processing
            if [[ -n "${FETCH_POST_PROCESS:-}" ]] && [[ -x "$FETCH_POST_PROCESS" ]]; then
                "$FETCH_POST_PROCESS" "$output_file" >> "$LOG_FILE" 2>&1
            fi

            return 0
        else
            rm -f "$temp_file"
            log "ERROR: Invalid JSON received from $URL"
            return 1
        fi
    else
        rm -f "$temp_file"
        log "ERROR: Failed to fetch from $URL"
        return 1
    fi
}

# Optional custom headers (set via environment)
declare -a FETCH_HEADERS=()
if [[ -n "${FETCH_AUTH_TOKEN:-}" ]]; then
    FETCH_HEADERS+=(-H "Authorization: Bearer $FETCH_AUTH_TOKEN")
fi

# Execute fetch
fetch

# Rotate log file if too large (>10MB)
if [[ -f "$LOG_FILE" ]] && [[ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE") -gt 10485760 ]]; then
    mv "$LOG_FILE" "${LOG_FILE}.old"
    gzip -f "${LOG_FILE}.old"
fi
