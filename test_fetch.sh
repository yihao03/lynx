#!/bin/bash

# Quick test script - fetches 3 times then stops

echo "Testing JSON fetcher with GitHub API..."
echo "Will fetch 3 times, 10 seconds apart"
echo ""

# Create test directory
TEST_DIR="./test_json_output"
mkdir -p "$TEST_DIR"

# Test URL - GitHub's public API (no auth needed)
TEST_URL="https://api.github.com/repos/torvalds/linux"

echo "📡 Fetching from: $TEST_URL"
echo "📁 Saving to: $TEST_DIR"
echo ""

for i in {1..3}; do
    echo "=== Fetch $i/3 ==="

    timestamp=$(date '+%Y%m%d_%H%M%S')
    output_file="${TEST_DIR}/data_${timestamp}.json"

    if curl -fsSL \
        --max-time 30 \
        -H "Accept: application/json" \
        "$TEST_URL" \
        -o "$output_file" 2>/dev/null; then

        # Validate JSON
        if command -v jq &>/dev/null; then
            if jq empty "$output_file" 2>/dev/null; then
                size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file")
                echo "✓ Success - ${size} bytes"

                # Show some data
                echo "  Repository: $(jq -r '.full_name' "$output_file")"
                echo "  Stars: $(jq -r '.stargazers_count' "$output_file")"
                echo "  Language: $(jq -r '.language' "$output_file")"

                # Create latest symlink
                ln -sf "$(basename "$output_file")" "${TEST_DIR}/latest.json"
            else
                echo "✗ Invalid JSON"
            fi
        else
            echo "✓ Success (install jq for validation)"
        fi
    else
        echo "✗ Failed to fetch"
    fi

    if [[ $i -lt 3 ]]; then
        echo "Waiting 10 seconds..."
        sleep 10
    fi
    echo ""
done

echo "=== Test Complete ==="
echo "Files created in: $TEST_DIR"
ls -lh "$TEST_DIR"
