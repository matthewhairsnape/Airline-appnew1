#!/bin/bash

# Run script for Flutter app with Supabase credentials
# Usage: ./run.sh [device]
# Example: ./run.sh          (runs on default device)
#          ./run.sh iPhone   (runs on iPhone simulator)
#          ./run.sh android  (runs on Android emulator)

SUPABASE_URL="https://otidfywfqxyxteixpqre.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im90aWRmeXdmcXh5eHRlaXhwcXJlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk5MzgzODMsImV4cCI6MjA3NTUxNDM4M30.o4TyfuLawwotXu9kUepuWmBF5QKVxflk7KHJSg6iJqI"

DEVICE_ARG=""
if [ ! -z "$1" ]; then
  DEVICE_ARG="-d $1"
fi

echo "🚀 Starting Flutter app with Supabase connection..."
echo "📱 Device: ${1:-default}"
echo "🔗 Supabase URL: $SUPABASE_URL"
echo ""

flutter run $DEVICE_ARG \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

