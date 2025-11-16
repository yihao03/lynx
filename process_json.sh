#!/bin/bash

# Example data processor script
# This script is called after each successful JSON fetch

set -euo pipefail

JSON_FILE="$1"

if [[ ! -f "$JSON_FILE" ]]; then
    echo "Error: File not found: $JSON_FILE"
    exit 1
fi

echo "Processing: $JSON_FILE"

# Example 1: Extract specific fields
if command -v jq &>/dev/null; then
    echo "Extracting key fields..."

    # Example: Extract and save specific fields
    jq '{
        name: .name,
        description: .description,
        stars: .stargazers_count,
        forks: .forks_count,
        updated: .updated_at
    }' "$JSON_FILE" > "${JSON_FILE%.json}_summary.json"

    # Example: Alert if stars exceed threshold
    STARS=$(jq -r '.stargazers_count // 0' "$JSON_FILE")
    if [[ $STARS -gt 100000 ]]; then
        echo "⭐ Repository has $STARS stars!"
    fi
fi

# Example 2: Send to database (uncomment to use)
# mysql -u user -p database <<< "INSERT INTO json_logs (data, timestamp) VALUES ('$(cat "$JSON_FILE")', NOW())"

# Example 3: Send to analytics
# curl -X POST https://analytics.example.com/ingest -d @"$JSON_FILE"

# Example 4: Convert to CSV
# jq -r '.[] | [.id, .name, .value] | @csv' "$JSON_FILE" > "${JSON_FILE%.json}.csv"

echo "Processing complete"
