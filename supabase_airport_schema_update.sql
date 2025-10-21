-- Airport Schema Update for Comprehensive Airport Data
-- Run this in your Supabase SQL Editor to add missing columns and triggers

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

-- Create a function to get airport by IATA code with full details
CREATE OR REPLACE FUNCTION get_airport_by_iata(iata_code_param TEXT)
RETURNS TABLE (
  id UUID,
  iata_code TEXT,
  icao_code TEXT,
  name TEXT,
  city TEXT,
  country TEXT,
  latitude DECIMAL,
  longitude DECIMAL,
  timezone TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    a.id,
    a.iata_code,
    a.icao_code,
    a.name,
    a.city,
    a.country,
    a.latitude,
    a.longitude,
    a.timezone,
    a.created_at,
    a.updated_at
  FROM airports a
  WHERE a.iata_code = iata_code_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a function to search airports by name or city
CREATE OR REPLACE FUNCTION search_airports(search_term TEXT)
RETURNS TABLE (
  id UUID,
  iata_code TEXT,
  icao_code TEXT,
  name TEXT,
  city TEXT,
  country TEXT,
  latitude DECIMAL,
  longitude DECIMAL,
  timezone TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    a.id,
    a.iata_code,
    a.icao_code,
    a.name,
    a.city,
    a.country,
    a.latitude,
    a.longitude,
    a.timezone
  FROM airports a
  WHERE 
    a.name ILIKE '%' || search_term || '%' OR
    a.city ILIKE '%' || search_term || '%' OR
    a.country ILIKE '%' || search_term || '%' OR
    a.iata_code ILIKE '%' || search_term || '%' OR
    a.icao_code ILIKE '%' || search_term || '%'
  ORDER BY 
    CASE 
      WHEN a.iata_code ILIKE search_term || '%' THEN 1
      WHEN a.name ILIKE search_term || '%' THEN 2
      WHEN a.city ILIKE search_term || '%' THEN 3
      ELSE 4
    END,
    a.name
  LIMIT 50;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_airport_by_iata(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION search_airports(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_airport_by_iata(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION search_airports(TEXT) TO anon;

