# How to Extract Headers from Postman

## The Problem
Your URL returns `403 Forbidden` with curl, but works in Postman. This means Postman is sending headers that we're not.

## Step 1: Check Postman Headers

In Postman, after making a successful request:

1. Click on the **Console** button (bottom left) or View → Show Postman Console
2. Find your request in the console
3. Expand it to see **Request Headers**
4. Look for headers like:
   - `Cookie:`
   - `Authorization:`
   - `X-API-Key:`
   - `Referer:`
   - `Origin:`
   - Any custom headers

## Step 2: Export as cURL Command

The easiest way:

1. In Postman, click the **Code** button (`</>`) on the right
2. Select **cURL** from the dropdown
3. Copy the entire curl command
4. Send it to me or run it in terminal to verify it works

Example output:
```bash
curl --location 'https://app.base44.com/api/...' \
--header 'Cookie: session_id=abc123; auth_token=xyz789' \
--header 'Authorization: Bearer eyJhbG...'
```

## Step 3: Test the cURL Command

```bash
# Paste the Postman curl command here and run it
curl --location 'https://app.base44.com/api/...' \
--header 'Cookie: YOUR_COOKIE_HERE'

# If it works, extract the headers
```

## Step 4: Use Headers with fetch_json.sh

Once you identify which header makes it work:

### If it's a Cookie:
```bash
export FETCH_CUSTOM_HEADERS="Cookie: session_id=abc123; auth_token=xyz789"
./fetch_json.sh "https://app.base44.com/api/..." 60
```

### If it's an Authorization header:
```bash
export FETCH_AUTH_TOKEN="your_token_value"
./fetch_json.sh "https://app.base44.com/api/..." 60
```

### If it's multiple headers:
```bash
export FETCH_CUSTOM_HEADERS="Cookie: session=abc|Authorization: Bearer xyz|X-Custom: value"
./fetch_json.sh "https://app.base44.com/api/..." 60
```

## Common Scenarios

### Scenario 1: Postman has saved cookies

If you logged into base44.com before in Postman:

1. In Postman, go to: **View → Show Cookies**
2. Look for `app.base44.com`
3. You'll see cookies like `session_id`, `auth_token`, etc.
4. Copy these cookie values

### Scenario 2: Postman is using environment variables

1. Check if Postman has an environment selected (top right dropdown)
2. Click the eye icon to see environment variables
3. Look for authentication-related variables

### Scenario 3: Collection/Folder auth

1. Check if your request is in a collection
2. Collection might have auth configured at folder/collection level
3. Click on collection → Authorization tab

## Quick Test Script

Save this to test different headers:

```bash
#!/bin/bash

URL="https://app.base44.com/api/apps/690b6df8a7c9c8956f17e47c/entities/PeerReview/6919805d0d58cef0bfc9f79d"

echo "Paste your Postman curl command headers here one by one to test:"
echo ""
echo "Test with Cookie header:"
read -p "Enter cookie value: " COOKIE
if [[ -n "$COOKIE" ]]; then
    curl -sS "$URL" -H "Cookie: $COOKIE" -w "\nHTTP: %{http_code}\n" | head -c 500
fi

echo ""
echo "Test with Authorization header:"
read -p "Enter auth token: " AUTH
if [[ -n "$AUTH" ]]; then
    curl -sS "$URL" -H "Authorization: Bearer $AUTH" -w "\nHTTP: %{http_code}\n" | head -c 500
fi
```

## What to Send Me

Either:

1. **The full cURL command from Postman** (use Code → cURL)
2. **Or the specific headers** that Postman shows in the console

I'll help you configure the script with the correct authentication.

## Security Note

If you're sharing headers:
- **Don't share** actual cookie/token values publicly
- Replace sensitive data with placeholders like `session_id=REDACTED`
- Or just tell me which header names are present (e.g., "has Cookie header with session_id and auth_token")
