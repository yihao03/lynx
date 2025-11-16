#!/bin/bash

# Periodic JSON Fetcher
# Usage: ./fetch_json.sh <URL> <interval_seconds> [output_dir]

set -euo pipefail

# Configuration
URL="${1:-}"
INTERVAL="${2:-60}"  # Default: 60 seconds
OUTPUT_DIR="${3:-./json_data}"
LOG_FILE="${OUTPUT_DIR}/fetch.log"
MAX_RETRIES=3
RETRY_DELAY=5

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Validate inputs
if [[ -z "$URL" ]]; then
    echo "Usage: $0 <URL> [interval_seconds] [output_dir]"
    echo "Example: $0 https://api.example.com/data 30 ./output"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Fetch JSON with retry logic
fetch_json() {
    local url="$1"
    local output_file="$2"
    local attempt=1

    while [[ $attempt -le $MAX_RETRIES ]]; do
        if curl -fsSL \
            --max-time 30 \
            --connect-timeout 10 \
            -H "Accept: application/json" \
            -H "User-Agent: JSON-Fetcher/1.0" \
            "$url" \
            -o "$output_file" 2>/dev/null; then

            # Validate JSON
            if jq empty "$output_file" 2>/dev/null; then
                return 0
            else
                log "ERROR" "Invalid JSON received"
                rm -f "$output_file"
                return 1
            fi
        fi

        log "WARN" "Attempt $attempt/$MAX_RETRIES failed, retrying in ${RETRY_DELAY}s..."
        sleep $RETRY_DELAY
        ((attempt++))
    done

    return 1
}

# Cleanup on exit
cleanup() {
    log "INFO" "Stopping JSON fetcher (received signal)"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Main loop
log "INFO" "Starting JSON fetcher"
log "INFO" "URL: $URL"
log "INFO" "Interval: ${INTERVAL}s"
log "INFO" "Output: $OUTPUT_DIR"

iteration=0
while true; do
    ((iteration++))
    timestamp=$(date '+%Y%m%d_%H%M%S')
    output_file="${OUTPUT_DIR}/data_${timestamp}.json"
    latest_link="${OUTPUT_DIR}/latest.json"

    echo -e "${YELLOW}[Iteration $iteration]${NC} Fetching JSON..."

    if fetch_json "$URL" "$output_file"; then
        file_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null)
        echo -e "${GREEN}✓${NC} Success - saved to: $output_file (${file_size} bytes)"
        log "INFO" "Successfully fetched JSON (${file_size} bytes) -> $output_file"

        # Create/update symlink to latest
        ln -sf "$(basename "$output_file")" "$latest_link"

        # Optional: Keep only last N files (uncomment to enable)
        # find "$OUTPUT_DIR" -name "data_*.json" -type f | sort -r | tail -n +11 | xargs rm -f
    else
        echo -e "${RED}✗${NC} Failed to fetch JSON after $MAX_RETRIES attempts"
        log "ERROR" "Failed to fetch JSON from $URL"
    fi

    echo "Next fetch in ${INTERVAL}s... (Press Ctrl+C to stop)"
    sleep "$INTERVAL"
done
