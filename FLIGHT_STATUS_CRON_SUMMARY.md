# Flight Status Cron Job - Complete Setup

## ✅ What's Been Created

1. **Edge Function**: `check-flight-statuses`
   - Finds all active journeys
   - Checks flight status from Cirium API
   - Compares with database status
   - Updates database if changed
   - Database trigger automatically sends notifications

2. **Database Trigger**: `journey_status_notification_trigger`
   - Automatically fires when status/phase/gate/terminal changes
   - Calls `flight-update-notification` Edge Function
   - Sends push notifications to users

## 🔄 How It Works

```
┌─────────────────────────────────────────────────────────┐
│  Cron Job (every 5 minutes)                            │
│  ↓                                                       │
│  Calls: check-flight-statuses Edge Function            │
│  ↓                                                       │
│  Finds active journeys                                  │
│  ↓                                                       │
│  For each journey:                                      │
│    1. Fetch from Cirium API                            │
│    2. Parse status/phase/gate/terminal                  │
│    3. Compare with database                             │
│    4. If changed → Update database                      │
│  ↓                                                       │
│  Database UPDATE triggers journey_status_notification_  │
│  trigger                                                │
│  ↓                                                       │
│  Trigger calls: flight-update-notification              │
│  ↓                                                       │
│  Function calls: send-push-notification                 │
│  ↓                                                       │
│  User receives push notification on device              │
└─────────────────────────────────────────────────────────┘
```

## 🚀 Setup Steps

### Step 1: Configure Secrets

Go to **Supabase Dashboard → Settings → Edge Functions → Secrets** and add:

- `CIRIUM_APP_ID`: `7f155a19`
- `CIRIUM_APP_KEY`: `6c5f44eeeb23a68f311a6321a96fcbdf`

### Step 2: Choose Cron Method

#### Option A: Use pg_cron (if available in Supabase)

1. Run `SETUP_CRON_JOB.sql` in Supabase SQL Editor
2. This will schedule the job to run every 5 minutes automatically

#### Option B: Use External Cron Service (Recommended)

1. Use a service like **cron-job.org** (free)
2. Set up POST request:
   - **URL**: `https://otidfywfqxyxteixpqre.supabase.co/functions/v1/check-flight-statuses`
   - **Headers**:
     - `Authorization`: `Bearer YOUR_SERVICE_ROLE_KEY`
     - `apikey`: `YOUR_SERVICE_ROLE_KEY`
   - **Schedule**: Every 5 minutes (`*/5 * * * *`)
   - **Body**: `{}`

See `SETUP_CRON_ALTERNATIVE.md` for detailed instructions.

### Step 3: Test Manually

Test the Edge Function manually:

```bash
curl -X POST 'https://otidfywfqxyxteixpqre.supabase.co/functions/v1/check-flight-statuses' \
  -H 'Authorization: Bearer YOUR_SERVICE_ROLE_KEY' \
  -H 'apikey: YOUR_SERVICE_ROLE_KEY' \
  -H 'Content-Type: application/json' \
  -d '{}'
```

Expected response:
```json
{
  "success": true,
  "checked": 15,
  "updated": 3,
  "errors": 0,
  "results": [...]
}
```

## 📋 What Gets Checked

The cron job checks journeys where:
- `status` is one of: `active`, `scheduled`, `in_progress`
- `current_phase` is NOT: `arrived`, `cancelled`, `completed`
- Maximum 100 journeys per run (to avoid timeout)

## 🔍 What Gets Updated

For each journey:
1. **Phase** (from Cirium status) → Updates `current_phase`
2. **Status** (mapped from phase) → Updates `status`
3. **Gate** (from Cirium) → Updates `gate`
4. **Terminal** (from Cirium) → Updates `terminal`

When any of these change:
- Database is updated
- Trigger fires automatically
- Notification is sent to user

## 📊 Monitoring

### Check Logs

1. **Edge Function Logs**:
   - Supabase Dashboard → Edge Functions → `check-flight-statuses` → Logs
   - See execution history and results

2. **Notification Logs**:
   ```sql
   SELECT * FROM notification_logs 
   ORDER BY sent_at DESC 
   LIMIT 10;
   ```

### Cron Job Status (if using pg_cron)

```sql
-- View scheduled jobs
SELECT * FROM cron.job;

-- View execution history
SELECT * FROM cron.job_run_details 
ORDER BY start_time DESC 
LIMIT 10;
```

## ⚙️ Configuration

### Change Check Frequency

**If using pg_cron:**
```sql
-- Change to every 10 minutes
SELECT cron.unschedule('check-flight-statuses-every-5min');
SELECT cron.schedule(
  'check-flight-statuses-every-10min',
  '*/10 * * * *',
  $$SELECT call_check_flight_statuses();$$
);
```

**If using external cron:**
Update the schedule in your cron service (cron-job.org, EasyCron, etc.)

### Change Maximum Journeys Per Run

Edit `supabase/functions/check-flight-statuses/index.ts`:
```typescript
.limit(100) // Change this number
```

## 🎯 Expected Behavior

1. **Every 5 minutes**: Cron job runs
2. **Active journeys**: Found and checked
3. **Cirium API**: Called for each flight
4. **Status compared**: New vs current
5. **If changed**: Database updated
6. **Trigger fires**: Notification sent automatically
7. **User notified**: Receives push notification

## ✅ Done!

Your system is now set up to:
- ✅ Automatically check flight statuses every 5 minutes
- ✅ Update database when status changes
- ✅ Send push notifications automatically via trigger
- ✅ Handle gate/terminal changes
- ✅ Send phase/status updates

No manual intervention needed - it all happens automatically!

