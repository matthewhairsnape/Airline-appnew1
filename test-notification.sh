#!/bin/bash

# ============================================================================
# TEST FLIGHT STATUS NOTIFICATION
# ============================================================================
# This script tests the flight-status-notification Edge Function directly
# bypassing any pg_net issues
# ============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Testing Flight Status Notification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Configuration
SUPABASE_URL="https://otidfywfqxyxteixpqre.supabase.co"
JOURNEY_ID="974ebeb1-29f8-4876-817f-ab098ddaa54e"  # Replace with your journey ID
USER_ID="0da7f390-aa01-4286-a847-265185d8e8ce"     # Replace with your user ID

# ⚠️ IMPORTANT: Replace with your SERVICE ROLE KEY (not anon key)
# Find it in: Supabase Dashboard → Settings → API → service_role key (secret)
SERVICE_ROLE_KEY="YOUR_SERVICE_ROLE_KEY_HERE"

if [ "$SERVICE_ROLE_KEY" = "YOUR_SERVICE_ROLE_KEY_HERE" ]; then
  echo "❌ ERROR: Please edit this script and add your SERVICE_ROLE_KEY"
  echo ""
  echo "📍 Find it in: Supabase Dashboard → Settings → API"
  echo "   Look for: service_role key (secret) - NOT the anon key"
  echo ""
  exit 1
fi

echo "📋 Test Configuration:"
echo "   Journey ID: $JOURNEY_ID"
echo "   User ID: $USER_ID"
echo "   Supabase URL: $SUPABASE_URL"
echo ""

echo "📤 Sending test notification..."
echo ""

# Send the request
response=$(curl -X POST "$SUPABASE_URL/functions/v1/flight-status-notification" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"journeyId\": \"$JOURNEY_ID\",
    \"userId\": \"$USER_ID\",
    \"oldStatus\": \"active\",
    \"newStatus\": \"active\",
    \"oldPhase\": \"at_airport\",
    \"newPhase\": \"boarding\",
    \"flightNumber\": \"912\",
    \"carrier\": \"VA\"
  }" \
  -w "\n\nHTTP Status: %{http_code}" \
  -s)

echo "$response"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if successful
if echo "$response" | grep -q '"success":true'; then
  echo "✅ SUCCESS! Notification sent"
  echo ""
  echo "📱 Check your device for the notification:"
  echo "   Title: 🎫 Boarding Started"
  echo "   Body: VA912 is now boarding. Please proceed to your gate."
  echo ""
  echo "📊 Also check:"
  echo "   1. Supabase Dashboard → Functions → flight-status-notification → Logs"
  echo "   2. notification_logs table in database"
  echo ""
elif echo "$response" | grep -q "404"; then
  echo "❌ ERROR: Edge Function not found (404)"
  echo ""
  echo "💡 Deploy the Edge Function:"
  echo "   supabase functions deploy flight-status-notification --no-verify-jwt"
  echo ""
elif echo "$response" | grep -q "No FCM token"; then
  echo "⚠️  User has no FCM token"
  echo ""
  echo "💡 The user needs to:"
  echo "   1. Log into the app"
  echo "   2. Grant notification permissions"
  echo "   3. The app will automatically save the FCM token"
  echo ""
elif echo "$response" | grep -q "Firebase credentials"; then
  echo "❌ ERROR: Firebase credentials not configured"
  echo ""
  echo "💡 Add these secrets in Supabase Dashboard → Settings → Edge Functions → Secrets:"
  echo "   - FIREBASE_PROJECT_ID"
  echo "   - FIREBASE_CLIENT_EMAIL"
  echo "   - FIREBASE_PRIVATE_KEY"
  echo ""
else
  echo "❌ Request failed - check the response above for details"
  echo ""
  echo "📊 Check Edge Function logs:"
  echo "   https://supabase.com/dashboard/project/otidfywfqxyxteixpqre/functions/flight-status-notification/logs"
  echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

