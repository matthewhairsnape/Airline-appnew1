-- ===================================================================================
-- Leaderboard Data Tables
-- -----------------------------------------------------------------------------------
-- This migration creates the normalized storage for leaderboard snapshots that drive
-- the Flutter leaderboard screens.  Data is ingested from curated CSV files via the
-- `scripts/leaderboard/ingest_leaderboard_data.py` helper and pushed into Supabase.
--
-- Tables:
--   1. leaderboard_snapshots      - High level snapshot metadata for a reporting run
--   2. leaderboard_rankings       - Per-airline ranking rows, scoped to category/class
--   3. leaderboard_metrics        - Fine grained metric counts backing each ranking
--
-- The Flutter app consumes `leaderboard_rankings` (filtered on `is_active = true`)
-- and hydrates airline details via the existing `airlines` table.
-- ===================================================================================

-- Extension required for UUID generation (safe no-op if already enabled)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ------------------------------------------------------------------------------
-- 1. Snapshot metadata
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.leaderboard_snapshots (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  label TEXT NOT NULL,                                 -- e.g. '2025-11 Business Q1 upload'
  reporting_period_start DATE,
  reporting_period_end DATE,
  source TEXT NOT NULL DEFAULT 'manual_upload',        -- Provides lineage (csv_upload, edge_fn, etc.)
  travel_class TEXT NOT NULL CHECK (travel_class <> ''), -- Business / Premium Economy / Economy / First
  notes TEXT,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.leaderboard_snapshots IS
  'Metadata for each leaderboard ingestion run.  Rank rows reference a snapshot.';

-- ------------------------------------------------------------------------------
-- 2. Rankings (surface data consumed by the Flutter app)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.leaderboard_rankings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  snapshot_id UUID NOT NULL REFERENCES public.leaderboard_snapshots(id) ON DELETE CASCADE,
  airline_id UUID NOT NULL REFERENCES public.airlines(id) ON DELETE CASCADE,
  category TEXT NOT NULL,                               -- Maps to UI tabs (Overall, Wi-Fi, Seat Comfort, etc.)
  travel_class TEXT NOT NULL,                           -- Mirrors snapshot.travel_class for easier querying
  leaderboard_rank INTEGER CHECK (leaderboard_rank IS NULL OR leaderboard_rank > 0),
  leaderboard_score NUMERIC(6,3),
  avg_rating NUMERIC(4,2),
  review_count INTEGER DEFAULT 0 CHECK (review_count >= 0),
  positive_count INTEGER DEFAULT 0 CHECK (positive_count >= 0),
  negative_count INTEGER DEFAULT 0 CHECK (negative_count >= 0),
  positive_ratio NUMERIC(5,2),                          -- Percentage (0-100) for UI display
  is_active BOOLEAN NOT NULL DEFAULT FALSE,             -- Only one active snapshot per category/class
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.leaderboard_rankings IS
  'Stores computed leaderboard scores per airline/category/class.  Active rows feed the UI.';

CREATE INDEX IF NOT EXISTS idx_leaderboard_rankings_category_class
  ON public.leaderboard_rankings (category, travel_class)
  WHERE is_active = true;

CREATE UNIQUE INDEX IF NOT EXISTS uq_leaderboard_rankings_active
  ON public.leaderboard_rankings (category, travel_class, airline_id)
  WHERE is_active = true;

-- Trigger to keep updated_at fresh
CREATE OR REPLACE FUNCTION public.set_leaderboard_rankings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_leaderboard_rankings_updated_at
ON public.leaderboard_rankings;

CREATE TRIGGER trg_leaderboard_rankings_updated_at
BEFORE UPDATE ON public.leaderboard_rankings
FOR EACH ROW
EXECUTE FUNCTION public.set_leaderboard_rankings_updated_at();

-- ------------------------------------------------------------------------------
-- 3. Metric breakdown backing each ranking row
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.leaderboard_metrics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ranking_id UUID NOT NULL REFERENCES public.leaderboard_rankings(id) ON DELETE CASCADE,
  metric_key TEXT NOT NULL,                 -- e.g. 'positive', 'negative', 'net', 'score_pct'
  metric_label TEXT,                        -- Human friendly label for UI export
  metric_value NUMERIC,
  unit TEXT DEFAULT 'count',                -- count | percentage | score | other
  extra JSONB,                              -- Optional payload for future drill-downs
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.leaderboard_metrics IS
  'Holds granular numbers that explain a leaderboard ranking (positive/negative counts, NPS style metrics, etc.).';

CREATE INDEX IF NOT EXISTS idx_leaderboard_metrics_ranking
  ON public.leaderboard_metrics (ranking_id);

-- ------------------------------------------------------------------------------
-- Helper function to activate a snapshot and retire older ones per category/class
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.activate_leaderboard_snapshot(p_snapshot_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_snapshot RECORD;
BEGIN
  SELECT * INTO v_snapshot
  FROM public.leaderboard_snapshots
  WHERE id = p_snapshot_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Snapshot % not found', p_snapshot_id;
  END IF;

  -- Deactivate existing rows for same travel_class
  UPDATE public.leaderboard_rankings
  SET is_active = false
  WHERE travel_class = v_snapshot.travel_class
    AND category IN (
      SELECT DISTINCT category
      FROM public.leaderboard_rankings
      WHERE snapshot_id = p_snapshot_id
    );

  -- Activate rows tied to the snapshot
  UPDATE public.leaderboard_rankings
  SET is_active = true
  WHERE snapshot_id = p_snapshot_id;
END;
$$;

COMMENT ON FUNCTION public.activate_leaderboard_snapshot IS
  'Marks a snapshot as active by enabling its rankings and disabling prior rows for the same travel class/categories.';

-- ------------------------------------------------------------------------------
-- Row Level Security (follow Supabase best practice - disabled by default)
-- ------------------------------------------------------------------------------
ALTER TABLE public.leaderboard_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaderboard_rankings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaderboard_metrics ENABLE ROW LEVEL SECURITY;

-- Allow service role full access (already implied) and authenticated read access
GRANT ALL ON public.leaderboard_snapshots TO service_role;
GRANT ALL ON public.leaderboard_rankings TO service_role;
GRANT ALL ON public.leaderboard_metrics TO service_role;

GRANT SELECT ON public.leaderboard_snapshots TO authenticated;
GRANT SELECT ON public.leaderboard_rankings TO authenticated;
GRANT SELECT ON public.leaderboard_metrics TO authenticated;

-- Simple policies: authenticated users can read, only service role writes via ingestion script
DROP POLICY IF EXISTS "Allow read access to leaderboard snapshots" ON public.leaderboard_snapshots;
CREATE POLICY "Allow read access to leaderboard snapshots"
  ON public.leaderboard_snapshots
  FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow read access to leaderboard rankings" ON public.leaderboard_rankings;
CREATE POLICY "Allow read access to leaderboard rankings"
  ON public.leaderboard_rankings
  FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow read access to leaderboard metrics" ON public.leaderboard_metrics;
CREATE POLICY "Allow read access to leaderboard metrics"
  ON public.leaderboard_metrics
  FOR SELECT
  USING (auth.role() = 'authenticated');

-- ===================================================================================

