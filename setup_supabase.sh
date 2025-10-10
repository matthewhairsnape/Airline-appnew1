#!/bin/bash

# Supabase Setup Script for Airline App
# This script helps you set up your Supabase project

echo "🚀 Setting up Supabase for Airline App"
echo "======================================"

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI is not installed. Please install it first:"
    echo "   brew install supabase/tap/supabase"
    exit 1
fi

echo "✅ Supabase CLI found"

# Set your Supabase URL
export SUPABASE_URL="https://otidfywfqxyxteixpqre.supabase.co"
echo "✅ Supabase URL set: $SUPABASE_URL"

echo ""
echo "📋 Next Steps:"
echo "1. Get your Supabase keys from: https://supabase.com/dashboard/project/otidfywfqxyxteixpqre/settings/api"
echo "2. Set your environment variables:"
echo "   export SUPABASE_ANON_KEY='your_anon_key_here'"
echo "   export SUPABASE_SERVICE_ROLE_KEY='your_service_role_key_here'"
echo ""
echo "3. Update your Supabase schema by running the SQL in supabase_final_schema.sql"
echo ""
echo "4. Deploy Edge Functions:"
echo "   ./deploy-functions.sh"
echo ""
echo "5. Run your Flutter app:"
echo "   flutter run"
echo ""
echo "6. Run the dashboard:"
echo "   cd dashboard && npm install && npm run dev"
echo ""

# Check if user is logged in to Supabase
if supabase status &> /dev/null; then
    echo "✅ You're logged in to Supabase"
    echo "🔗 Your project: https://supabase.com/dashboard/project/otidfywfqxyxteixpqre"
else
    echo "⚠️  You need to log in to Supabase:"
    echo "   supabase login"
fi

echo ""
echo "🎉 Setup instructions complete!"
echo "   Your Supabase URL: https://otidfywfqxyxteixpqre.supabase.co"
