# Supabase Security Setup Guide

## Issue: "Low Level Security" Error

This error occurs when Supabase Row Level Security (RLS) is enabled but proper policies are not configured.

## Solution: Configure Supabase Security Policies

### 1. Disable RLS for Testing (Quick Fix)

Go to your Supabase Dashboard → Authentication → Policies and disable RLS for the `users` table temporarily:

```sql
-- Disable RLS for users table (TEMPORARY - for testing only)
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
```

### 2. Proper RLS Policies (Recommended)

Instead of disabling RLS, set up proper policies:

```sql
-- Enable RLS on users table
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Policy: Users can insert their own data
CREATE POLICY "Users can insert their own data" ON public.users
    FOR INSERT WITH CHECK (auth.uid()::text = id::text);

-- Policy: Users can view their own data
CREATE POLICY "Users can view their own data" ON public.users
    FOR SELECT USING (auth.uid()::text = id::text);

-- Policy: Users can update their own data
CREATE POLICY "Users can update their own data" ON public.users
    FOR UPDATE USING (auth.uid()::text = id::text);

-- Policy: Users can delete their own data
CREATE POLICY "Users can delete their own data" ON public.users
    FOR DELETE USING (auth.uid()::text = id::text);
```

### 3. Alternative: Use Service Role Key

If you want to bypass RLS for your app, you can use the service role key instead of the anon key:

1. Go to Supabase Dashboard → Settings → API
2. Copy the `service_role` key (not the `anon` key)
3. Update your app to use the service role key

**⚠️ WARNING: Service role key bypasses all RLS policies. Only use this for development/testing.**

### 4. Update App Configuration

If using service role key, update `lib/services/supabase_service.dart`:

```dart
const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY', 
  defaultValue: 'YOUR_SERVICE_ROLE_KEY_HERE' // Replace with service role key
);
```

## Testing Steps

1. **Apply the RLS policies above** in your Supabase dashboard
2. **Test the app** - authentication should work now
3. **Check the debug console** for success messages

## Debugging

If you still get errors, check:

1. **Supabase Dashboard → Logs** - Look for authentication errors
2. **App Debug Console** - Look for detailed error messages
3. **Network Tab** - Check if requests are reaching Supabase

## Security Best Practices

1. **Never use service role key in production**
2. **Always use proper RLS policies**
3. **Test with anon key and RLS enabled**
4. **Monitor your Supabase logs regularly**

## Quick Test

1. Go to Supabase Dashboard → SQL Editor
2. Run the RLS policies above
3. Test your app authentication
4. Check debug console for success messages



