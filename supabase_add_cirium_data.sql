-- Add cirium_data column to journeys table
-- Run this in your Supabase SQL Editor

-- Add cirium_data column to store Cirium flight data
ALTER TABLE journeys ADD COLUMN IF NOT EXISTS cirium_data JSONB;

-- Add index for better performance on cirium_data queries
CREATE INDEX IF NOT EXISTS idx_journeys_cirium_data ON journeys USING GIN (cirium_data);

-- Add comment to document the column
COMMENT ON COLUMN journeys.cirium_data IS 'Stores Cirium flight tracking data as JSONB for real-time flight information';
