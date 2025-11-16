# Quick Start: Fixing the 403 Error

## Your Situation

✗ **Problem:** Script terminates with 403 Forbidden
✓ **Works in:** Postman without authentication
→ **Solution:** Extract headers from Postman and use them

## Step 1: Get Postman cURL Command

In Postman (after successful request):

1. Click **`</>`** (Code button) on the right
2. Select **cURL** from dropdown
3. Click **Copy to Clipboard**

You'll get something like:
```bash
curl --location 'https://app.base44.com/api/...' \
--header 'Cookie: session_id=abc123; user_token=xyz789'
```

## Step 2: Extract the Headers

From the cURL command, find any `--header` lines. Common ones:

```bash
--header 'Cookie: session_id=abc123'
--header 'Authorization: Bearer eyJhbGc...'
--header 'X-API-Key: your_key'
```

## Step 3: Use with the Script

### Option A: Just Cookie
```bash
export FETCH_CUSTOM_HEADERS="Cookie: session_id=abc123; user_token=xyz789"
./fetch_json.sh "https://app.base44.com/api/..." 60
```

### Option B: Authorization Token
```bash
export FETCH_AUTH_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
./fetch_json.sh "https://app.base44.com/api/..." 60
```

### Option C: Multiple Headers
```bash
export FETCH_CUSTOM_HEADERS="Cookie: session=abc|Referer: https://app.base44.com"
./fetch_json.sh "https://app.base44.com/api/..." 60
```

## Step 4: Test It

```bash
# Test first with curl to verify
curl -H "Cookie: YOUR_COOKIE_HERE" \
  "https://app.base44.com/api/apps/690b6df8a7c9c8956f17e47c/entities/PeerReview/6919805d0d58cef0bfc9f79d"

# If it works, use with the script
export FETCH_CUSTOM_HEADERS="Cookie: YOUR_COOKIE_HERE"
./fetch_json.sh "https://app.base44.com/api/apps/690b6df8a7c9c8956f17e47c/entities/PeerReview/6919805d0d58cef0bfc9f79d" 60
```

## Example: Complete Working Command

```bash
#!/bin/bash

# Replace with your actual cookie from Postman
export FETCH_CUSTOM_HEADERS="Cookie: connect.sid=s%3Aj8K...; io=xHGt..."

# Run the fetcher
./fetch_json.sh \
  "https://app.base44.com/api/apps/690b6df8a7c9c8956f17e47c/entities/PeerReview/6919805d0d58cef0bfc9f79d" \
  60 \
  ./peer_review_data
```

## Still Not Working?

### Check Postman Console for ALL Headers

1. In Postman: **View → Show Postman Console** (or Ctrl+Alt+C)
2. Make the request again
3. Click on the request in console
4. Expand to see **all** request headers
5. Look for headers like:
   - Cookie
   - Authorization
   - Referer
   - Origin
   - X-Custom headers

### Enable Debug Mode

```bash
DEBUG=true FETCH_CUSTOM_HEADERS="Cookie: your_cookie" \
  ./fetch_json.sh "https://app.base44.com/api/..." 60
```

This shows exactly what curl command is being sent.

## What Changed in the Script

✅ **Fixed**: Script no longer terminates on first error
✅ **Added**: Clear error messages with HTTP status codes
✅ **Added**: Authentication support (Bearer, API Key, Custom headers)
✅ **Added**: Shows what server actually returns
✅ **Added**: Debug mode to see curl commands
✅ **Added**: Better retry logic with exponential backoff

## Need Help Finding Headers?

See `POSTMAN_DEBUG.md` for detailed instructions on extracting headers from Postman.

## Quick Test

```bash
# This should now show clear error message instead of crashing:
./fetch_json.sh "https://app.base44.com/api/..." 60

# Output will show:
# [WARN] No authentication configured
# [WARN] Attempt 1/3 failed (HTTP 403 - Forbidden - check permissions or add authentication)
# [ERROR] Failed to fetch JSON
# Next fetch in 60s...  ← Script continues running!
```
