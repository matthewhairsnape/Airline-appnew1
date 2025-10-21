-- Add columns for media and detailed comments to the feedback table
-- This script safely adds new columns without affecting existing data

-- Add media columns
ALTER TABLE feedback
ADD COLUMN IF NOT EXISTS images JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS videos JSONB DEFAULT '[]'::jsonb;

-- Add detailed comment columns
ALTER TABLE feedback
ADD COLUMN IF NOT EXISTS likes_comment TEXT,
ADD COLUMN IF NOT EXISTS dislikes_comment TEXT;

-- Add selection tracking columns
ALTER TABLE feedback
ADD COLUMN IF NOT EXISTS likes_selections JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS dislikes_selections JSONB DEFAULT '[]'::jsonb;

-- Add indexes for new columns (optional, but good for performance if querying these often)
CREATE INDEX IF NOT EXISTS idx_feedback_images ON feedback USING GIN (images);
CREATE INDEX IF NOT EXISTS idx_feedback_videos ON feedback USING GIN (videos);
CREATE INDEX IF NOT EXISTS idx_feedback_likes_selections ON feedback USING GIN (likes_selections);
CREATE INDEX IF NOT EXISTS idx_feedback_dislikes_selections ON feedback USING GIN (dislikes_selections);

-- Add comments for documentation
COMMENT ON COLUMN feedback.images IS 'Array of image file paths for this feedback entry';
COMMENT ON COLUMN feedback.videos IS 'Array of video file paths for this feedback entry';
COMMENT ON COLUMN feedback.likes_comment IS 'Detailed comment about what the user liked';
COMMENT ON COLUMN feedback.dislikes_comment IS 'Detailed comment about what the user disliked';
COMMENT ON COLUMN feedback.likes_selections IS 'Array of selected positive feedback options';
COMMENT ON COLUMN feedback.dislikes_selections IS 'Array of selected negative feedback options';

SELECT 'Media and detailed comment columns added to feedback table successfully!' AS result;
