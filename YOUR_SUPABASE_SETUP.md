# Your Supabase Setup Guide

## 🎯 **Your Supabase Project**
- **URL**: `https://otidfywfqxyxteixpqre.supabase.co`
- **Dashboard**: https://supabase.com/dashboard/project/otidfywfqxyxteixpqre

## 🔑 **Step 1: Get Your API Keys**

1. **Go to your Supabase Dashboard**: https://supabase.com/dashboard/project/otidfywfqxyxteixpqre/settings/api
2. **Copy these keys**:
   - **anon/public key** (starts with `eyJ...`)
   - **service_role key** (starts with `eyJ...`)

## ⚙️ **Step 2: Set Environment Variables**

Run these commands in your terminal:

```bash
# Set your Supabase keys
export SUPABASE_ANON_KEY='your_anon_key_here'
export SUPABASE_SERVICE_ROLE_KEY='your_service_role_key_here'

# Verify they're set
echo $SUPABASE_ANON_KEY
echo $SUPABASE_SERVICE_ROLE_KEY
```

## 🗄️ **Step 3: Update Your Database Schema**

1. **Go to your Supabase SQL Editor**: https://supabase.com/dashboard/project/otidfywfqxyxteixpqre/sql
2. **Run this SQL**:

```sql
-- Add push token fields to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS push_token TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- Create journey_events table
CREATE TABLE IF NOT EXISTS journey_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  journey_id UUID REFERENCES journeys(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  event_timestamp TIMESTAMPTZ NOT NULL,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create airline_reviews table
CREATE TABLE IF NOT EXISTS airline_reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  journey_id UUID REFERENCES journeys(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  airline_id UUID REFERENCES airlines(id) ON DELETE CASCADE,
  overall_score DECIMAL(3, 2),
  seat_comfort INTEGER,
  cabin_service INTEGER,
  food_beverage INTEGER,
  entertainment INTEGER,
  value_for_money INTEGER,
  comments TEXT,
  would_recommend BOOLEAN,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(journey_id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_journey_events_journey_id ON journey_events(journey_id);
CREATE INDEX IF NOT EXISTS idx_airline_reviews_airline_id ON airline_reviews(airline_id);
```

## 🚀 **Step 4: Deploy Edge Functions**

```bash
# Login to Supabase (if not already logged in)
supabase login

# Deploy the functions
./deploy-functions.sh
```

## 📱 **Step 5: Test Your Flutter App**

```bash
# Run your app
flutter run

# Test on iOS
flutter run -d ios

# Test on Android
flutter run -d android
```

## 📊 **Step 6: Run the Dashboard**

```bash
# Install dependencies
cd dashboard
npm install

# Create environment file
echo "NEXT_PUBLIC_SUPABASE_URL=https://otidfywfqxyxteixpqre.supabase.co" > .env.local
echo "NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key_here" >> .env.local
echo "SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here" >> .env.local

# Run dashboard
npm run dev
```

## 🧪 **Step 7: Test Everything**

1. **Scan a boarding pass** in your app
2. **Check Supabase** - you should see data in the `journeys` table
3. **Check Dashboard** - you should see real-time data updates
4. **Test Push Notifications** - they'll be logged in the console

## 🔧 **Troubleshooting**

### **If Flutter app doesn't connect to Supabase:**
- Check that `SUPABASE_ANON_KEY` is set correctly
- Verify the key in your Supabase dashboard

### **If Edge Functions fail to deploy:**
- Make sure you're logged in: `supabase login`
- Check your `SUPABASE_SERVICE_ROLE_KEY` is correct

### **If Dashboard doesn't load:**
- Check the `.env.local` file has the correct keys
- Make sure your Supabase project is active

## 🎉 **You're All Set!**

Your airline app is now connected to your Supabase project and ready to use! 

- **Flutter App**: ✅ Connected to Supabase
- **Edge Functions**: ✅ Ready to deploy
- **Dashboard**: ✅ Ready to run
- **Database**: ✅ Schema updated

## 📞 **Need Help?**

If you encounter any issues:
1. Check the Supabase logs in your dashboard
2. Check the Flutter console for error messages
3. Verify all environment variables are set correctly
4. Make sure your Supabase project is active and not paused
