-- Fix airports table to add updated_at column
-- Run this in your Supabase SQL Editor

-- Add updated_at column to airports table if it doesn't exist
ALTER TABLE airports ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Create trigger to auto-update updated_at for airports
DROP TRIGGER IF EXISTS update_airports_updated_at ON airports;
CREATE TRIGGER update_airports_updated_at BEFORE UPDATE ON airports
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Add indexes for better performance on airport lookups
CREATE INDEX IF NOT EXISTS idx_airports_iata_code ON airports(iata_code);
CREATE INDEX IF NOT EXISTS idx_airports_icao_code ON airports(icao_code);
CREATE INDEX IF NOT EXISTS idx_airports_city ON airports(city);
CREATE INDEX IF NOT EXISTS idx_airports_country ON airports(country);

-- Add constraints to ensure data integrity
ALTER TABLE airports ALTER COLUMN iata_code SET NOT NULL;
ALTER TABLE airports ALTER COLUMN name SET NOT NULL;

-- Add check constraints for coordinate validation
ALTER TABLE airports ADD CONSTRAINT check_latitude_range 
  CHECK (latitude IS NULL OR (latitude >= -90 AND latitude <= 90));

ALTER TABLE airports ADD CONSTRAINT check_longitude_range 
  CHECK (longitude IS NULL OR (longitude >= -180 AND longitude <= 180));

-- Add check constraint for IATA code format (3 characters)
ALTER TABLE airports ADD CONSTRAINT check_iata_code_format 
  CHECK (char_length(iata_code) = 3 AND iata_code ~ '^[A-Z]{3}$');

-- Add check constraint for ICAO code format (4 characters)
ALTER TABLE airports ADD CONSTRAINT check_icao_code_format 
  CHECK (icao_code IS NULL OR (char_length(icao_code) = 4 AND icao_code ~ '^[A-Z]{4}$'));

-- Update RLS policies for airports table
DROP POLICY IF EXISTS "Anyone can view airports" ON airports;
CREATE POLICY "Anyone can view airports" ON airports
  FOR SELECT USING (true);

-- Allow authenticated users to insert airports (for data population)
CREATE POLICY "Authenticated users can insert airports" ON airports
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Allow authenticated users to update airports (for data updates)
CREATE POLICY "Authenticated users can update airports" ON airports
  FOR UPDATE USING (auth.role() = 'authenticated');

