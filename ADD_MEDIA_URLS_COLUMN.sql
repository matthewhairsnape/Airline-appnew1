-- Add media_urls column to feedback-related tables
-- This column will store an array of Supabase Storage URLs for uploaded media files

-- Add to stage_feedback table
ALTER TABLE stage_feedback 
ADD COLUMN IF NOT EXISTS media_urls TEXT[] DEFAULT '{}';

-- Add to airline_reviews table
ALTER TABLE airline_reviews 
ADD COLUMN IF NOT EXISTS media_urls TEXT[] DEFAULT '{}';

-- Add to airport_reviews table
ALTER TABLE airport_reviews 
ADD COLUMN IF NOT EXISTS media_urls TEXT[] DEFAULT '{}';

-- Add comments for documentation
COMMENT ON COLUMN stage_feedback.media_urls IS 'Array of Supabase Storage URLs for uploaded media files (images/videos)';
COMMENT ON COLUMN airline_reviews.media_urls IS 'Array of Supabase Storage URLs for uploaded media files (images/videos)';
COMMENT ON COLUMN airport_reviews.media_urls IS 'Array of Supabase Storage URLs for uploaded media files (images/videos)';

