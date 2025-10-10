#!/bin/bash

# Deploy Supabase Edge Functions
# Make sure you have the Supabase CLI installed and are logged in

echo "🚀 Deploying Supabase Edge Functions..."

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI is not installed. Please install it first:"
    echo "   npm install -g supabase"
    exit 1
fi

# Check if user is logged in
if ! supabase status &> /dev/null; then
    echo "❌ Not logged in to Supabase. Please run:"
    echo "   supabase login"
    exit 1
fi

# Deploy individual functions
echo "📦 Deploying send-push-notification function..."
supabase functions deploy send-push-notification

echo "📦 Deploying send-batch-notifications function..."
supabase functions deploy send-batch-notifications

echo "📦 Deploying flight-phase-notification function..."
supabase functions deploy flight-phase-notification

echo "✅ All Edge Functions deployed successfully!"

echo ""
echo "🔧 Next steps:"
echo "1. Update your Supabase project settings with the function URLs"
echo "2. Test the functions using the Supabase dashboard"
echo "3. Update your Flutter app to use the new push notification service"
echo ""
echo "📱 Function URLs:"
echo "- send-push-notification: https://your-project.supabase.co/functions/v1/send-push-notification"
echo "- send-batch-notifications: https://your-project.supabase.co/functions/v1/send-batch-notifications"
echo "- flight-phase-notification: https://your-project.supabase.co/functions/v1/flight-phase-notification"
