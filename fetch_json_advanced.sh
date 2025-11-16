#!/bin/bash

# Advanced Periodic JSON Fetcher with Configuration
# Features: Config file, webhooks, data processing, archiving

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${1:-${SCRIPT_DIR}/fetch_config.json}"

# Default configuration
declare -A CONFIG=(
    [url]=""
    [interval]=60
    [output_dir]="./json_data"
    [max_retries]=3
    [retry_delay]=5
    [archive_after]=100
    [webhook_url]=""
    [process_script]=""
    [compare_changes]=false
)

# Load configuration from JSON file
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Config file not found: $CONFIG_FILE"
        echo "Creating example config..."
        create_example_config
        exit 1
    fi

    # Parse JSON config using jq
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required but not installed"
        exit 1
    fi

    CONFIG[url]=$(jq -r '.url // ""' "$CONFIG_FILE")
    CONFIG[interval]=$(jq -r '.interval // 60' "$CONFIG_FILE")
    CONFIG[output_dir]=$(jq -r '.output_dir // "./json_data"' "$CONFIG_FILE")
    CONFIG[max_retries]=$(jq -r '.max_retries // 3' "$CONFIG_FILE")
    CONFIG[retry_delay]=$(jq -r '.retry_delay // 5' "$CONFIG_FILE")
    CONFIG[archive_after]=$(jq -r '.archive_after // 100' "$CONFIG_FILE")
    CONFIG[webhook_url]=$(jq -r '.webhook_url // ""' "$CONFIG_FILE")
    CONFIG[process_script]=$(jq -r '.process_script // ""' "$CONFIG_FILE")
    CONFIG[compare_changes]=$(jq -r '.compare_changes // false' "$CONFIG_FILE")
}

# Create example configuration file
create_example_config() {
    cat > "$CONFIG_FILE" <<'EOF'
{
  "url": "https://api.example.com/data",
  "interval": 60,
  "output_dir": "./json_data",
  "max_retries": 3,
  "retry_delay": 5,
  "archive_after": 100,
  "webhook_url": "",
  "process_script": "",
  "compare_changes": false,
  "headers": {
    "Authorization": "Bearer YOUR_TOKEN_HERE",
    "X-Custom-Header": "value"
  }
}
EOF
    echo "Created example config at: $CONFIG_FILE"
}

# Logging
log() {
    local level="$1"
    shift
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $*" | tee -a "${CONFIG[output_dir]}/fetch.log"
}

# Fetch JSON with custom headers
fetch_json() {
    local url="$1"
    local output_file="$2"
    local temp_file="${output_file}.tmp"

    # Build curl command with custom headers
    local curl_cmd="curl -fsSL --max-time 30 --connect-timeout 10"

    # Add custom headers from config if present
    if jq -e '.headers' "$CONFIG_FILE" &>/dev/null; then
        while IFS="=" read -r key value; do
            curl_cmd+=" -H \"$key: $value\""
        done < <(jq -r '.headers | to_entries | .[] | "\(.key)=\(.value)"' "$CONFIG_FILE")
    fi

    curl_cmd+=" \"$url\" -o \"$temp_file\""

    # Execute fetch
    if eval "$curl_cmd" 2>/dev/null; then
        if jq empty "$temp_file" 2>/dev/null; then
            mv "$temp_file" "$output_file"
            return 0
        fi
    fi

    rm -f "$temp_file"
    return 1
}

# Compare with previous fetch
compare_with_previous() {
    local new_file="$1"
    local latest_link="${CONFIG[output_dir]}/latest.json"

    if [[ ! -f "$latest_link" ]]; then
        return 0  # No previous file, always different
    fi

    # Compare JSON content (normalized)
    local diff_output
    diff_output=$(jq -S . "$latest_link" | diff - <(jq -S . "$new_file") 2>&1) || true

    if [[ -n "$diff_output" ]]; then
        log "INFO" "Changes detected"
        echo "$diff_output" > "${CONFIG[output_dir]}/last_diff.txt"
        return 0  # Changed
    else
        log "INFO" "No changes detected"
        return 1  # Unchanged
    fi
}

# Send webhook notification
send_webhook() {
    local message="$1"
    local webhook_url="${CONFIG[webhook_url]}"

    if [[ -z "$webhook_url" ]]; then
        return 0
    fi

    curl -fsSL -X POST "$webhook_url" \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"$message\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
        &>/dev/null || log "WARN" "Failed to send webhook"
}

# Process data with custom script
process_data() {
    local data_file="$1"
    local process_script="${CONFIG[process_script]}"

    if [[ -z "$process_script" ]] || [[ ! -x "$process_script" ]]; then
        return 0
    fi

    log "INFO" "Processing data with: $process_script"
    "$process_script" "$data_file" || log "WARN" "Processing script failed"
}

# Archive old files
archive_old_files() {
    local archive_after="${CONFIG[archive_after]}"
    local output_dir="${CONFIG[output_dir]}"
    local file_count

    file_count=$(find "$output_dir" -name "data_*.json" -type f | wc -l)

    if [[ $file_count -gt $archive_after ]]; then
        log "INFO" "Archiving old files (count: $file_count)"

        local archive_dir="${output_dir}/archive"
        mkdir -p "$archive_dir"

        find "$output_dir" -name "data_*.json" -type f \
            | sort \
            | head -n -"$archive_after" \
            | xargs -I{} mv {} "$archive_dir/"

        # Compress archive
        tar -czf "${archive_dir}/archive_$(date +%Y%m%d_%H%M%S).tar.gz" \
            -C "$archive_dir" . \
            --remove-files 2>/dev/null || true
    fi
}

# Main function
main() {
    load_config

    if [[ -z "${CONFIG[url]}" ]]; then
        log "ERROR" "URL not configured"
        exit 1
    fi

    mkdir -p "${CONFIG[output_dir]}"

    log "INFO" "Starting JSON fetcher"
    log "INFO" "URL: ${CONFIG[url]}"
    log "INFO" "Interval: ${CONFIG[interval]}s"

    local iteration=0
    while true; do
        ((iteration++))
        local timestamp=$(date '+%Y%m%d_%H%M%S')
        local output_file="${CONFIG[output_dir]}/data_${timestamp}.json"
        local latest_link="${CONFIG[output_dir]}/latest.json"

        log "INFO" "Iteration $iteration - Fetching..."

        local attempt=1
        local success=false

        while [[ $attempt -le ${CONFIG[max_retries]} ]] && [[ "$success" == "false" ]]; do
            if fetch_json "${CONFIG[url]}" "$output_file"; then
                success=true
                local file_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file")
                log "INFO" "Success (${file_size} bytes)"

                # Check for changes if enabled
                if [[ "${CONFIG[compare_changes]}" == "true" ]]; then
                    if compare_with_previous "$output_file"; then
                        send_webhook "JSON data changed at $(date)"
                    else
                        # Remove unchanged file to save space
                        rm -f "$output_file"
                        log "INFO" "Skipped saving unchanged data"
                        sleep "${CONFIG[interval]}"
                        continue
                    fi
                fi

                # Update latest symlink
                ln -sf "$(basename "$output_file")" "$latest_link"

                # Process data
                process_data "$output_file"

                # Archive old files
                archive_old_files
            else
                log "WARN" "Attempt $attempt/${CONFIG[max_retries]} failed"
                ((attempt++))
                [[ $attempt -le ${CONFIG[max_retries]} ]] && sleep "${CONFIG[retry_delay]}"
            fi
        done

        if [[ "$success" == "false" ]]; then
            log "ERROR" "Failed after ${CONFIG[max_retries]} attempts"
            send_webhook "Failed to fetch JSON from ${CONFIG[url]}"
        fi

        sleep "${CONFIG[interval]}"
    done
}

# Cleanup
cleanup() {
    log "INFO" "Shutting down"
    exit 0
}

trap cleanup SIGINT SIGTERM

main
