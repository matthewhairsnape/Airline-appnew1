# Alternative Cron Job Setup (if pg_cron doesn't work)

If `pg_cron` extension is not available in your Supabase project, you can use external cron services:

## Option 1: External Cron Service (Recommended)

### Using cron-job.org (Free)

1. Go to https://cron-job.org/en/
2. Create a free account
3. Create a new cron job with these settings:
   - **Title**: Flight Status Check
   - **URL**: `https://otidfywfqxyxteixpqre.supabase.co/functions/v1/check-flight-statuses`
   - **Schedule**: Every 5 minutes (`*/5 * * * *`)
   - **Request Method**: POST
   - **Request Headers**:
     - `Authorization`: `Bearer YOUR_SERVICE_ROLE_KEY`
     - `apikey`: `YOUR_SERVICE_ROLE_KEY`
     - `Content-Type`: `application/json`
   - **Request Body**: `{}`

### Using EasyCron (Free)

1. Go to https://www.easycron.com/
2. Create account
3. Add new cron job:
   - **URL**: `https://otidfywfqxyxteixpqre.supabase.co/functions/v1/check-flight-statuses`
   - **Method**: POST
   - **Headers**: Add Authorization and apikey headers
   - **Schedule**: Every 5 minutes

## Option 2: GitHub Actions (Free)

Create `.github/workflows/check-flight-statuses.yml`:

```yaml
name: Check Flight Statuses

on:
  schedule:
    - cron: '*/5 * * * *'  # Every 5 minutes
  workflow_dispatch:  # Manual trigger

jobs:
  check-flights:
    runs-on: ubuntu-latest
    steps:
      - name: Call Flight Status Check
        run: |
          curl -X POST \
            'https://otidfywfqxyxteixpqre.supabase.co/functions/v1/check-flight-statuses' \
            -H 'Authorization: Bearer ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}' \
            -H 'apikey: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}' \
            -H 'Content-Type: application/json' \
            -d '{}'
```

Add `SUPABASE_SERVICE_ROLE_KEY` to GitHub Secrets.

## Option 3: Manual API Call (Testing)

Test the function manually:

```bash
curl -X POST 'https://otidfywfqxyxteixpqre.supabase.co/functions/v1/check-flight-statuses' \
  -H 'Authorization: Bearer YOUR_SERVICE_ROLE_KEY' \
  -H 'apikey: YOUR_SERVICE_ROLE_KEY' \
  -H 'Content-Type: application/json' \
  -d '{}'
```

## Configuration

Before deploying, make sure to set these secrets in Supabase:

1. Go to: Supabase Dashboard → Settings → Edge Functions → Secrets
2. Add:
   - `CIRIUM_APP_ID`: `7f155a19`
   - `CIRIUM_APP_KEY`: `6c5f44eeeb23a68f311a6321a96fcbdf`

## How It Works

1. Cron job calls `check-flight-statuses` Edge Function every 5 minutes
2. Function finds all active journeys (status: active/scheduled/in_progress)
3. For each journey, it:
   - Fetches flight status from Cirium API
   - Compares with current database status
   - Updates database if changed (phase, status, gate, terminal)
4. Database trigger automatically sends notifications when status changes
5. Users receive push notifications on their devices

## Monitoring

Check Edge Function logs:
- Supabase Dashboard → Edge Functions → `check-flight-statuses` → Logs

The function returns:
```json
{
  "success": true,
  "checked": 15,
  "updated": 3,
  "errors": 0,
  "results": [...]
}
```

