#!/bin/bash

# Periodic JSON Fetcher
# Usage: ./fetch_json.sh <URL> <interval_seconds> [output_dir]
#
# Environment variables:
#   FETCH_AUTH_TOKEN - Bearer token for authentication
#   FETCH_API_KEY - API key header
#   FETCH_CUSTOM_HEADERS - Additional headers (format: "Header1: Value1|Header2: Value2")

set -uo pipefail  # Removed -e to handle errors gracefully

# Configuration
URL="${1:-}"
INTERVAL="${2:-60}"  # Default: 60 seconds
OUTPUT_DIR="${3:-./json_data}"
LOG_FILE="${OUTPUT_DIR}/fetch.log"
MAX_RETRIES=3
RETRY_DELAY=5
DEBUG="${DEBUG:-false}"  # Set DEBUG=true for verbose output

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
    local error_file="${output_file}.error"

    while [[ $attempt -le $MAX_RETRIES ]]; do
        # Build curl command with headers
        local curl_cmd=(curl -fsSL --max-time 30 --connect-timeout 10)
        curl_cmd+=(-H "Accept: application/json")
        curl_cmd+=(-H "User-Agent: JSON-Fetcher/1.0")

        # Add authentication if provided
        if [[ -n "${FETCH_AUTH_TOKEN:-}" ]]; then
            curl_cmd+=(-H "Authorization: Bearer $FETCH_AUTH_TOKEN")
        fi

        if [[ -n "${FETCH_API_KEY:-}" ]]; then
            curl_cmd+=(-H "X-API-Key: $FETCH_API_KEY")
        fi

        # Add custom headers
        if [[ -n "${FETCH_CUSTOM_HEADERS:-}" ]]; then
            IFS='|' read -ra HEADERS <<< "$FETCH_CUSTOM_HEADERS"
            for header in "${HEADERS[@]}"; do
                curl_cmd+=(-H "$header")
            done
        fi

        curl_cmd+=("$url" -o "$output_file")

        # Show curl command in debug mode
        if [[ "$DEBUG" == "true" ]]; then
            echo "DEBUG: ${curl_cmd[*]}" >&2
        fi

        # Execute curl and capture both stdout and stderr
        local curl_exit_code=0
        "${curl_cmd[@]}" 2>"$error_file" || curl_exit_code=$?

        # Check if curl succeeded
        if [[ $curl_exit_code -eq 0 ]]; then
            # Validate JSON
            if command -v jq &>/dev/null; then
                if jq empty "$output_file" 2>/dev/null; then
                    rm -f "$error_file"
                    return 0
                else
                    log "ERROR" "Invalid JSON received - server returned:"
                    echo "--- Server Response (first 500 chars) ---" >&2
                    head -c 500 "$output_file" >&2
                    echo "" >&2
                    echo "--- End Response ---" >&2
                    rm -f "$output_file" "$error_file"
                    return 1
                fi
            else
                # No jq available, assume it's valid
                rm -f "$error_file"
                return 0
            fi
        fi

        # Show detailed error
        local error_msg="Attempt $attempt/$MAX_RETRIES failed"
        if [[ -s "$error_file" ]]; then
            error_msg+=": $(cat "$error_file")"
        fi

        # Try to get HTTP status code
        local http_code="000"
        http_code=$(curl -sSL --max-time 10 --connect-timeout 5 \
            -o /dev/null -w "%{http_code}" \
            -H "Accept: application/json" \
            -H "User-Agent: JSON-Fetcher/1.0" \
            "$url" 2>/dev/null || echo "000")

        if [[ "$http_code" =~ ^[0-9]{3}$ ]] && [[ "$http_code" != "000" ]] && [[ "$http_code" != "200" ]]; then
            error_msg+=" (HTTP $http_code"
            case $http_code in
                401) error_msg+=" - Unauthorized - check authentication" ;;
                403) error_msg+=" - Forbidden - check permissions or add authentication" ;;
                404) error_msg+=" - Not Found" ;;
                429) error_msg+=" - Rate Limited" ;;
                500|502|503|504) error_msg+=" - Server Error" ;;
            esac
            error_msg+=")"
        fi

        log "WARN" "$error_msg"

        if [[ $attempt -lt $MAX_RETRIES ]]; then
            sleep $RETRY_DELAY
        fi
        ((attempt++))
    done

    rm -f "$error_file"
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

# Show authentication status
if [[ -n "${FETCH_AUTH_TOKEN:-}" ]]; then
    log "INFO" "Authentication: Bearer token configured"
elif [[ -n "${FETCH_API_KEY:-}" ]]; then
    log "INFO" "Authentication: API key configured"
elif [[ -n "${FETCH_CUSTOM_HEADERS:-}" ]]; then
    log "INFO" "Authentication: Custom headers configured"
else
    log "WARN" "No authentication configured (set FETCH_AUTH_TOKEN, FETCH_API_KEY, or FETCH_CUSTOM_HEADERS if needed)"
fi

iteration=0
while true; do
    ((iteration++))
    timestamp=$(date '+%Y%m%d_%H%M%S')
    output_file="${OUTPUT_DIR}/data_${timestamp}.json"
    latest_link="${OUTPUT_DIR}/latest.json"

    echo -e "${YELLOW}[Iteration $iteration]${NC} Fetching JSON..."

    if fetch_json "$URL" "$output_file"; then
        # Get file size (compatible with both macOS and Linux)
        if file_size=$(stat -f%z "$output_file" 2>/dev/null); then
            : # macOS
        elif file_size=$(stat -c%s "$output_file" 2>/dev/null); then
            : # Linux
        else
            file_size="unknown"
        fi
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
