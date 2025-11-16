# Periodic JSON Fetcher Scripts

Three different approaches to periodically fetch JSON data from URLs.

## Scripts Overview

| Script | Use Case | Pros | Cons |
|--------|----------|------|------|
| `fetch_json.sh` | Simple continuous fetching | Easy to use, no dependencies | Runs continuously |
| `fetch_json_advanced.sh` | Feature-rich monitoring | Config file, webhooks, processing | Requires jq |
| `fetch_json_cron.sh` | Scheduled execution | Cron-based, lightweight | Requires cron setup |

## Quick Start

### Option 1: Simple Script

```bash
# Make executable
chmod +x fetch_json.sh

# Fetch every 60 seconds
./fetch_json.sh "https://api.github.com/repos/torvalds/linux" 60

# Fetch every 5 minutes to custom directory
./fetch_json.sh "https://api.example.com/data" 300 ./my_data
```

### Option 2: Advanced Script

```bash
# Make executable
chmod +x fetch_json_advanced.sh
chmod +x process_json.sh

# Edit configuration
vim fetch_config.json

# Run with config
./fetch_json_advanced.sh fetch_config.json
```

### Option 3: Cron-Based

```bash
# Make executable
chmod +x fetch_json_cron.sh

# Set environment variables
export FETCH_URL="https://api.example.com/data"
export FETCH_OUTPUT_DIR="$HOME/json_data"
export FETCH_AUTH_TOKEN="your_token_here"  # Optional

# Add to crontab (every 5 minutes)
crontab -e
```

Add this line:
```
*/5 * * * * FETCH_URL="https://api.example.com/data" /path/to/fetch_json_cron.sh
```

## Configuration Examples

### Basic Config (`fetch_config.json`)

```json
{
  "url": "https://api.example.com/data",
  "interval": 60,
  "output_dir": "./json_data",
  "max_retries": 3,
  "retry_delay": 5
}
```

### Advanced Config with Authentication

```json
{
  "url": "https://api.example.com/private/data",
  "interval": 300,
  "output_dir": "/var/data/api_snapshots",
  "max_retries": 3,
  "retry_delay": 10,
  "archive_after": 500,
  "compare_changes": true,
  "process_script": "/path/to/process_json.sh",
  "webhook_url": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL",
  "headers": {
    "Authorization": "Bearer YOUR_API_TOKEN",
    "X-API-Key": "your_api_key",
    "Accept": "application/json"
  }
}
```

## Usage Examples

### Example 1: Monitor GitHub Repository

```bash
./fetch_json.sh "https://api.github.com/repos/torvalds/linux" 3600 ./github_data
```

### Example 2: Track Cryptocurrency Prices

```bash
./fetch_json.sh "https://api.coinbase.com/v2/prices/BTC-USD/spot" 30 ./crypto_prices
```

### Example 3: Monitor API Health

```bash
export FETCH_URL="https://status.example.com/api/health"
export FETCH_OUTPUT_DIR="/var/log/api_health"
export FETCH_POST_PROCESS="./alert_on_downtime.sh"

./fetch_json_cron.sh
```

### Example 4: Weather Data Collection

```json
{
  "url": "https://api.openweathermap.org/data/2.5/weather?q=London&appid=YOUR_KEY",
  "interval": 1800,
  "output_dir": "./weather_data",
  "compare_changes": true,
  "process_script": "./weather_processor.sh"
}
```

## Running in Background

### Using systemd (recommended for production)

Create `/etc/systemd/system/json-fetcher.service`:

```ini
[Unit]
Description=JSON Fetcher Service
After=network.target

[Service]
Type=simple
User=youruser
WorkingDirectory=/home/youruser/json-fetcher
ExecStart=/home/youruser/json-fetcher/fetch_json_advanced.sh /home/youruser/json-fetcher/fetch_config.json
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable json-fetcher
sudo systemctl start json-fetcher
sudo systemctl status json-fetcher
```

### Using screen/tmux

```bash
# Using screen
screen -dmS json-fetcher ./fetch_json.sh "https://api.example.com/data" 60
screen -r json-fetcher  # Reattach

# Using tmux
tmux new -d -s json-fetcher './fetch_json.sh "https://api.example.com/data" 60'
tmux attach -t json-fetcher
```

### Using nohup

```bash
nohup ./fetch_json.sh "https://api.example.com/data" 60 > fetcher.log 2>&1 &
echo $! > fetcher.pid  # Save PID

# Stop later
kill $(cat fetcher.pid)
```

## Data Processing

### Example Processor: Extract and Alert

```bash
#!/bin/bash
JSON_FILE="$1"

# Extract temperature and alert if high
TEMP=$(jq -r '.main.temp' "$JSON_FILE")
if (( $(echo "$TEMP > 30" | bc -l) )); then
    curl -X POST "https://api.telegram.org/botTOKEN/sendMessage" \
        -d "chat_id=YOUR_CHAT_ID" \
        -d "text=High temperature alert: ${TEMP}°C"
fi
```

### Example: Save to Database

```bash
#!/bin/bash
JSON_FILE="$1"

# Insert into PostgreSQL
psql -U user -d database <<EOF
INSERT INTO api_snapshots (data, fetched_at)
VALUES ('$(cat "$JSON_FILE")', NOW());
EOF
```

## Monitoring and Alerts

### Check if fetcher is running

```bash
# For loop-based scripts
pgrep -f fetch_json.sh || echo "Fetcher not running!"

# For systemd
systemctl is-active json-fetcher || echo "Service down!"
```

### Monitor data freshness

```bash
# Alert if data is older than 10 minutes
LATEST="./json_data/latest.json"
if [[ -f "$LATEST" ]]; then
    AGE=$(($(date +%s) - $(stat -f%m "$LATEST" 2>/dev/null || stat -c%Y "$LATEST")))
    if [[ $AGE -gt 600 ]]; then
        echo "WARNING: Data is $AGE seconds old"
    fi
fi
```

### Log analysis

```bash
# Count successes vs failures today
grep "$(date +%Y-%m-%d)" ./json_data/fetch.log | grep -c SUCCESS
grep "$(date +%Y-%m-%d)" ./json_data/fetch.log | grep -c ERROR

# Show recent errors
tail -100 ./json_data/fetch.log | grep ERROR
```

## Troubleshooting

### Issue: "jq: command not found"

```bash
# Install jq
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq

# RHEL/CentOS
sudo yum install jq
```

### Issue: Permission denied

```bash
chmod +x fetch_json.sh
chmod +x fetch_json_advanced.sh
chmod +x fetch_json_cron.sh
chmod +x process_json.sh
```

### Issue: curl SSL certificate errors

```bash
# Add -k flag to curl (not recommended for production)
# Or install proper certificates
sudo apt-get install ca-certificates
```

### Issue: Script stops unexpectedly

```bash
# Run with debugging
bash -x ./fetch_json.sh "https://api.example.com/data" 60

# Check system logs
journalctl -u json-fetcher -n 100
```

## Performance Tips

1. **Reduce file count**: Enable archiving in advanced script
2. **Disk space**: Monitor output directory size
   ```bash
   du -sh ./json_data
   ```
3. **Network**: Use `compare_changes: true` to skip saving identical data
4. **Memory**: For large JSON files, process in streaming mode:
   ```bash
   curl -s "$URL" | jq -c '.[]' | while read -r line; do
       echo "$line" >> output.jsonl
   done
   ```

## Security Best Practices

1. **Never commit API tokens**: Use environment variables or secret management
2. **Validate SSL**: Don't use `-k` flag with curl in production
3. **Limit permissions**: Run as non-root user
4. **Sanitize output**: Be careful when processing untrusted JSON
5. **Rate limiting**: Respect API rate limits

## Advanced Features

### Conditional Fetching (only fetch if API is up)

```bash
if curl -fsSL --head "$URL" >/dev/null 2>&1; then
    ./fetch_json.sh "$URL" 60
else
    echo "API is down, skipping fetch"
fi
```

### Multiple URLs

```bash
URLS=(
    "https://api.example.com/endpoint1"
    "https://api.example.com/endpoint2"
    "https://api.example.com/endpoint3"
)

for url in "${URLS[@]}"; do
    ./fetch_json_cron.sh "$url" &
done
wait
```

### Diff-based notifications

```bash
# In process_json.sh
if diff ./json_data/previous.json "$1" > /dev/null; then
    echo "No changes"
else
    diff -u ./json_data/previous.json "$1" | mail -s "API Data Changed" admin@example.com
fi
cp "$1" ./json_data/previous.json
```

## License

These scripts are provided as-is for educational and commercial use.
