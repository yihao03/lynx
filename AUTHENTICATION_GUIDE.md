# How to Use Authentication with fetch_json.sh

## Problem: 403 Forbidden Error

If you see this error:
```
[WARN] Attempt 1/3 failed: curl: (22) The requested URL returned error: 403 (HTTP 403 - Forbidden)
```

This means the API requires authentication.

## Solution: Add Authentication Headers

### Option 1: Bearer Token (Most Common)

```bash
export FETCH_AUTH_TOKEN="your_api_token_here"
./fetch_json.sh "https://api.example.com/data" 60
```

### Option 2: API Key Header

```bash
export FETCH_API_KEY="your_api_key_here"
./fetch_json.sh "https://api.example.com/data" 60
```

This sends the header: `X-API-Key: your_api_key_here`

### Option 3: Custom Headers

```bash
export FETCH_CUSTOM_HEADERS="Cookie: session=abc123|X-Custom: value"
./fetch_json.sh "https://api.example.com/data" 60
```

Separate multiple headers with `|`

### Option 4: Combine Multiple Methods

```bash
export FETCH_AUTH_TOKEN="your_token"
export FETCH_CUSTOM_HEADERS="X-Request-ID: 12345|X-Client: MyApp"
./fetch_json.sh "https://api.example.com/data" 60
```

## How to Find Your API Token

### For Base44 (your URL)

1. **Open the web app** in your browser
2. **Open Developer Tools** (F12)
3. **Go to Network tab**
4. **Refresh the page** or make a request
5. **Click on any API request** to the same domain
6. **Look at Request Headers** for:
   - `Authorization: Bearer <token>`
   - `Cookie: <session_cookie>`
   - `X-API-Key: <key>`
   - Any other authentication headers

### Example: Extract from Browser

```bash
# In browser console (F12), run:
console.log(document.cookie);

# Or check network tab and copy the Cookie header
```

Then use it:
```bash
export FETCH_CUSTOM_HEADERS="Cookie: your_cookie_value_here"
./fetch_json.sh "https://app.base44.com/api/..." 60
```

## Testing Your Authentication

### Step 1: Test with curl first

```bash
# Test Bearer token
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "https://app.base44.com/api/apps/690b6df8a7c9c8956f17e47c/entities/PeerReview/6919805d0d58cef0bfc9f79d"

# Test with Cookie
curl -H "Cookie: YOUR_COOKIE" \
  "https://app.base44.com/api/apps/690b6df8a7c9c8956f17e47c/entities/PeerReview/6919805d0d58cef0bfc9f79d"

# Test with API Key
curl -H "X-API-Key: YOUR_KEY" \
  "https://app.base44.com/api/apps/690b6df8a7c9c8956f17e47c/entities/PeerReview/6919805d0d58cef0bfc9f79d"
```

### Step 2: Once you find what works, use it with the script

```bash
export FETCH_CUSTOM_HEADERS="Cookie: session_id=abc123; user_token=xyz789"
./fetch_json.sh "https://app.base44.com/api/..." 60
```

## Debug Mode

Enable debug mode to see exactly what curl command is being sent:

```bash
DEBUG=true ./fetch_json.sh "https://api.example.com/data" 60
```

This will show the full curl command including all headers (be careful - this will show your tokens!)

## Complete Example

```bash
#!/bin/bash

# Set your authentication
export FETCH_AUTH_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Or use cookies from browser
export FETCH_CUSTOM_HEADERS="Cookie: session=xyz; auth_token=abc"

# Run the fetcher
./fetch_json.sh \
  "https://app.base44.com/api/apps/690b6df8a7c9c8956f17e47c/entities/PeerReview/6919805d0d58cef0bfc9f79d" \
  300 \
  ./base44_data
```

## Security Best Practices

1. **Never commit tokens to git**
   ```bash
   # Create a separate file for secrets
   cat > .env <<EOF
   FETCH_AUTH_TOKEN="your_secret_token"
   EOF

   # Add to .gitignore
   echo ".env" >> .gitignore

   # Source it before running
   source .env
   ./fetch_json.sh "https://api.example.com/data" 60
   ```

2. **Use environment variables**
   ```bash
   # In your ~/.bashrc or ~/.zshrc
   export FETCH_AUTH_TOKEN="your_token"
   ```

3. **Rotate tokens regularly**
   - Don't use long-lived tokens if possible
   - Use API keys with limited permissions

## Troubleshooting

### Still getting 403?

1. **Check token expiration**: Your token might have expired
2. **Verify token format**: Some APIs expect `Bearer <token>`, others just `<token>`
3. **Check permissions**: Your token might not have access to this resource
4. **Try browser headers**: Copy ALL headers from a working browser request

### Getting 401 Unauthorized?

This usually means:
- Wrong token/credentials
- Token format is incorrect
- Token has expired

### Getting 429 Rate Limited?

You're making too many requests. Increase the interval:
```bash
./fetch_json.sh "https://api.example.com/data" 300  # 5 minutes instead of 1
```

## Quick Reference

| Environment Variable | Header Sent | Example |
|---------------------|-------------|---------|
| `FETCH_AUTH_TOKEN` | `Authorization: Bearer <token>` | OAuth/JWT tokens |
| `FETCH_API_KEY` | `X-API-Key: <key>` | Simple API keys |
| `FETCH_CUSTOM_HEADERS` | Custom headers | Any header(s) |

## Need Help?

Run the script and check the logs:
```bash
./fetch_json.sh "https://api.example.com/data" 60
# Check logs at:
cat ./json_data/fetch.log
```

Enable debug mode:
```bash
DEBUG=true FETCH_AUTH_TOKEN="your_token" ./fetch_json.sh "https://api.example.com/data" 60
```
