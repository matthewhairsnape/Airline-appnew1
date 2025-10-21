-- Fix passenger_id foreign key constraint to allow direct user ID references
-- Run this in your Supabase SQL Editor

-- First, check if passengers table exists and has data
-- If it has data, we need to migrate it
-- If not, we can safely drop the constraint

-- Check if passengers table has any data
DO $$
DECLARE
    passenger_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO passenger_count FROM passengers;
    
    IF passenger_count > 0 THEN
        RAISE NOTICE 'Passengers table has % records. Migration needed.', passenger_count;
        
        -- Update journeys to use user_id from passengers table
        UPDATE journeys 
        SET passenger_id = p.user_id::text
        FROM passengers p 
        WHERE journeys.passenger_id = p.id::text;
        
        RAISE NOTICE 'Migrated % journey records to use user_id directly.', passenger_count;
    ELSE
        RAISE NOTICE 'Passengers table is empty. Safe to drop constraint.';
    END IF;
END $$;

-- Drop the foreign key constraint
ALTER TABLE journeys DROP CONSTRAINT IF EXISTS journeys_passenger_id_fkey;

-- Optionally, drop the passengers table if it's no longer needed
-- (Only do this if you're sure it's not used elsewhere)
-- DROP TABLE IF EXISTS passengers CASCADE;

-- Verify the constraint was removed
SELECT 
    tc.table_name, 
    tc.constraint_name, 
    tc.constraint_type
FROM information_schema.table_constraints tc
WHERE tc.table_name = 'journeys' 
  AND tc.constraint_type = 'FOREIGN KEY'
  AND tc.constraint_name LIKE '%passenger%';
