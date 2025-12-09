-- ============================================================================
-- BUILD PEEK - Complete Supabase Database Schema
-- ============================================================================
-- Full database schema with all tables, RLS policies, functions, triggers,
-- storage buckets, and edge function hooks for the BUILD PEEK app
-- ============================================================================
-- Run this AFTER the initial schema (20241206_initial_schema.sql)
-- ============================================================================

-- ============================================================================
-- SCHEMA UPDATES - Add missing columns to existing tables
-- ============================================================================

-- Add missing columns to estimate_results if not exists
DO $$
BEGIN
    -- Add overhead_cost if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'estimate_results' AND column_name = 'overhead_cost') THEN
        ALTER TABLE estimate_results ADD COLUMN overhead_cost DECIMAL(12, 2) DEFAULT 0;
    END IF;

    -- Add api_version if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'estimate_results' AND column_name = 'api_version') THEN
        ALTER TABLE estimate_results ADD COLUMN api_version TEXT;
    END IF;
END $$;

-- Add missing columns to generated_images if not exists
DO $$
BEGIN
    -- Add local_path for cached images
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'generated_images' AND column_name = 'local_path') THEN
        ALTER TABLE generated_images ADD COLUMN local_path TEXT;
    END IF;

    -- Add generation_model
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'generated_images' AND column_name = 'generation_model') THEN
        ALTER TABLE generated_images ADD COLUMN generation_model TEXT DEFAULT 'nano-banana-pro';
    END IF;
END $$;

-- Add missing columns to profiles if not exists
DO $$
BEGIN
    -- Add stripe_customer_id for payment integration
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'profiles' AND column_name = 'stripe_customer_id') THEN
        ALTER TABLE profiles ADD COLUMN stripe_customer_id TEXT;
    END IF;

    -- Add notification preferences
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'profiles' AND column_name = 'email_notifications') THEN
        ALTER TABLE profiles ADD COLUMN email_notifications BOOLEAN DEFAULT TRUE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'profiles' AND column_name = 'push_notifications') THEN
        ALTER TABLE profiles ADD COLUMN push_notifications BOOLEAN DEFAULT TRUE;
    END IF;

    -- Add referral tracking
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'profiles' AND column_name = 'referral_code') THEN
        ALTER TABLE profiles ADD COLUMN referral_code TEXT UNIQUE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'profiles' AND column_name = 'referred_by') THEN
        ALTER TABLE profiles ADD COLUMN referred_by UUID REFERENCES profiles(id);
    END IF;
END $$;

-- ============================================================================
-- LOCAL SELLERS TABLE (for material price lookups)
-- ============================================================================

CREATE TABLE IF NOT EXISTS local_sellers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    address TEXT,
    city TEXT,
    state TEXT,
    zip_code TEXT,
    phone TEXT,
    website TEXT,
    email TEXT,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    rating DECIMAL(2, 1),
    review_count INTEGER DEFAULT 0,
    price_level INTEGER CHECK (price_level BETWEEN 1 AND 4),
    specialties TEXT[] DEFAULT '{}',
    hours_of_operation JSONB DEFAULT '{}',
    is_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Create indexes for local sellers
CREATE INDEX IF NOT EXISTS idx_local_sellers_location ON local_sellers(state, city);
CREATE INDEX IF NOT EXISTS idx_local_sellers_zip ON local_sellers(zip_code);
CREATE INDEX IF NOT EXISTS idx_local_sellers_category ON local_sellers(category);
-- Note: Geo index requires earthdistance extension. Using simple lat/lng index instead.
CREATE INDEX IF NOT EXISTS idx_local_sellers_lat ON local_sellers(latitude) WHERE latitude IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_local_sellers_lng ON local_sellers(longitude) WHERE longitude IS NOT NULL;

-- ============================================================================
-- PRICE QUOTES TABLE (user-specific price lookups)
-- ============================================================================

CREATE TABLE IF NOT EXISTS price_quotes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    project_id UUID REFERENCES renovation_projects(id) ON DELETE SET NULL,
    seller_id UUID REFERENCES local_sellers(id) ON DELETE SET NULL,
    material_name TEXT NOT NULL,
    material_category TEXT,
    quantity DECIMAL(10, 2) DEFAULT 1,
    unit TEXT,
    quoted_price DECIMAL(12, 2),
    original_price DECIMAL(12, 2),
    discount_percentage DECIMAL(5, 2),
    valid_until TIMESTAMPTZ,
    notes TEXT,
    source TEXT, -- 'manual', 'api', 'web_scrape'
    source_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_price_quotes_user ON price_quotes(user_id);
CREATE INDEX IF NOT EXISTS idx_price_quotes_project ON price_quotes(project_id);
CREATE INDEX IF NOT EXISTS idx_price_quotes_material ON price_quotes(material_name);

-- Enable RLS
ALTER TABLE local_sellers ENABLE ROW LEVEL SECURITY;
ALTER TABLE price_quotes ENABLE ROW LEVEL SECURITY;

-- Local sellers are readable by all authenticated users
CREATE POLICY "Authenticated users can view local sellers"
    ON local_sellers FOR SELECT
    TO authenticated
    USING (is_active = TRUE);

-- Price quotes are user-specific
CREATE POLICY "Users can view own price quotes"
    ON price_quotes FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create own price quotes"
    ON price_quotes FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own price quotes"
    ON price_quotes FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================================
-- PROJECT PHOTOS TABLE (uploaded reference photos)
-- ============================================================================

CREATE TABLE IF NOT EXISTS project_photos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES renovation_projects(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    storage_path TEXT NOT NULL,
    thumbnail_path TEXT,
    original_filename TEXT,
    file_size_bytes INTEGER,
    width INTEGER,
    height INTEGER,
    mime_type TEXT DEFAULT 'image/jpeg',
    description TEXT,
    photo_type TEXT DEFAULT 'before', -- 'before', 'during', 'after', 'reference'
    taken_at TIMESTAMPTZ,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_project_photos_project ON project_photos(project_id);
CREATE INDEX IF NOT EXISTS idx_project_photos_user ON project_photos(user_id);

ALTER TABLE project_photos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own project photos"
    ON project_photos FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can upload own project photos"
    ON project_photos FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own project photos"
    ON project_photos FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own project photos"
    ON project_photos FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================================
-- FEEDBACK TABLE (user feedback and ratings)
-- ============================================================================

CREATE TABLE IF NOT EXISTS user_feedback (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    estimate_id UUID REFERENCES estimate_results(id) ON DELETE SET NULL,
    image_id UUID REFERENCES generated_images(id) ON DELETE SET NULL,
    feedback_type TEXT NOT NULL, -- 'estimate_accuracy', 'image_quality', 'app_feature', 'bug_report'
    rating INTEGER CHECK (rating BETWEEN 1 AND 5),
    actual_cost DECIMAL(12, 2), -- For estimate accuracy feedback
    comments TEXT,
    metadata JSONB DEFAULT '{}',
    is_resolved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_feedback_user ON user_feedback(user_id);
CREATE INDEX IF NOT EXISTS idx_feedback_type ON user_feedback(feedback_type);

ALTER TABLE user_feedback ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own feedback"
    ON user_feedback FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create feedback"
    ON user_feedback FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- SHARED PROJECTS TABLE (for sharing projects with clients/contractors)
-- ============================================================================

CREATE TABLE IF NOT EXISTS shared_projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES renovation_projects(id) ON DELETE CASCADE,
    owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    share_token TEXT UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(32), 'hex'),
    recipient_email TEXT,
    recipient_name TEXT,
    permissions TEXT[] DEFAULT ARRAY['view'], -- 'view', 'comment', 'edit'
    message TEXT,
    expires_at TIMESTAMPTZ,
    accessed_at TIMESTAMPTZ,
    access_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_shared_projects_token ON shared_projects(share_token);
CREATE INDEX IF NOT EXISTS idx_shared_projects_owner ON shared_projects(owner_id);
CREATE INDEX IF NOT EXISTS idx_shared_projects_project ON shared_projects(project_id);

ALTER TABLE shared_projects ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owners can manage shared projects"
    ON shared_projects FOR ALL
    USING (auth.uid() = owner_id);

-- ============================================================================
-- ADDITIONAL FUNCTIONS
-- ============================================================================

-- Function to generate unique referral code
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS TEXT AS $$
DECLARE
    chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    result TEXT := '';
    i INTEGER;
BEGIN
    FOR i IN 1..8 LOOP
        result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
    END LOOP;
    RETURN 'BP-' || result;
END;
$$ LANGUAGE plpgsql;

-- Function to set referral code on profile creation
CREATE OR REPLACE FUNCTION set_referral_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.referral_code IS NULL THEN
        NEW.referral_code := generate_referral_code();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-generate referral codes
DROP TRIGGER IF EXISTS set_profile_referral_code ON profiles;
CREATE TRIGGER set_profile_referral_code
    BEFORE INSERT ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION set_referral_code();

-- Function to get usage stats for dashboard
CREATE OR REPLACE FUNCTION get_user_stats(p_user_id UUID)
RETURNS TABLE (
    total_projects BIGINT,
    total_estimates BIGINT,
    total_images BIGINT,
    total_estimated_value DECIMAL,
    estimates_this_month INTEGER,
    images_this_month INTEGER,
    estimate_limit INTEGER,
    image_limit INTEGER
) AS $$
DECLARE
    v_tier subscription_tier;
BEGIN
    SELECT subscription_tier INTO v_tier FROM profiles WHERE id = p_user_id;

    RETURN QUERY
    SELECT
        (SELECT COUNT(*) FROM renovation_projects WHERE user_id = p_user_id AND NOT is_archived),
        (SELECT COUNT(*) FROM estimate_results WHERE user_id = p_user_id),
        (SELECT COUNT(*) FROM generated_images WHERE user_id = p_user_id),
        COALESCE((SELECT SUM((total_cost_low + total_cost_high) / 2) FROM estimate_results WHERE user_id = p_user_id), 0),
        (SELECT estimates_generated_this_month FROM profiles WHERE id = p_user_id),
        (SELECT images_generated_this_month FROM profiles WHERE id = p_user_id),
        CASE v_tier
            WHEN 'free' THEN 5
            WHEN 'professional' THEN 100
            WHEN 'enterprise' THEN 999999
        END,
        CASE v_tier
            WHEN 'free' THEN 3
            WHEN 'professional' THEN 50
            WHEN 'enterprise' THEN 999999
        END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to search materials catalog
CREATE OR REPLACE FUNCTION search_materials(
    p_query TEXT,
    p_category TEXT DEFAULT NULL,
    p_quality_tier quality_tier DEFAULT NULL,
    p_room_type room_type DEFAULT NULL,
    p_limit INTEGER DEFAULT 20
)
RETURNS SETOF materials_catalog AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM materials_catalog
    WHERE is_active = TRUE
      AND (p_query IS NULL OR
           to_tsvector('english', name || ' ' || COALESCE(description, '')) @@ plainto_tsquery('english', p_query))
      AND (p_category IS NULL OR category = p_category)
      AND (p_quality_tier IS NULL OR quality_tier = p_quality_tier)
      AND (p_room_type IS NULL OR p_room_type = ANY(applicable_room_types))
    ORDER BY
        CASE WHEN p_query IS NOT NULL
             THEN ts_rank(to_tsvector('english', name || ' ' || COALESCE(description, '')), plainto_tsquery('english', p_query))
             ELSE 0
        END DESC,
        name
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to record API usage
CREATE OR REPLACE FUNCTION log_api_usage(
    p_user_id UUID,
    p_endpoint TEXT,
    p_request_type TEXT,
    p_tokens_used INTEGER DEFAULT 0,
    p_cost_cents INTEGER DEFAULT 0,
    p_duration_ms INTEGER DEFAULT NULL,
    p_status_code INTEGER DEFAULT 200,
    p_error_message TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_log_id UUID;
BEGIN
    INSERT INTO api_usage_logs (
        user_id, endpoint, request_type, tokens_used,
        cost_cents, duration_ms, status_code, error_message
    ) VALUES (
        p_user_id, p_endpoint, p_request_type, p_tokens_used,
        p_cost_cents, p_duration_ms, p_status_code, p_error_message
    )
    RETURNING id INTO v_log_id;

    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions on new functions
GRANT EXECUTE ON FUNCTION get_user_stats(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION search_materials(TEXT, TEXT, quality_tier, room_type, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION log_api_usage(UUID, TEXT, TEXT, INTEGER, INTEGER, INTEGER, INTEGER, TEXT) TO authenticated;

-- ============================================================================
-- REALTIME SUBSCRIPTIONS (enable for specific tables)
-- ============================================================================

-- Enable realtime for projects (for live updates)
ALTER PUBLICATION supabase_realtime ADD TABLE renovation_projects;
ALTER PUBLICATION supabase_realtime ADD TABLE estimate_results;
ALTER PUBLICATION supabase_realtime ADD TABLE generated_images;

-- ============================================================================
-- CRON JOBS (via pg_cron extension if available)
-- ============================================================================

-- Note: These require pg_cron extension to be enabled
-- Run monthly usage reset on the 1st of each month at midnight UTC

-- SELECT cron.schedule(
--     'reset-monthly-usage',
--     '0 0 1 * *',
--     $$SELECT reset_monthly_usage()$$
-- );

-- Clean up expired shared project links daily
-- SELECT cron.schedule(
--     'cleanup-expired-shares',
--     '0 3 * * *',
--     $$UPDATE shared_projects SET is_active = FALSE WHERE expires_at < NOW() AND is_active = TRUE$$
-- );

-- ============================================================================
-- ADDITIONAL SEED DATA - More materials
-- ============================================================================

INSERT INTO materials_catalog (category, name, description, unit, cost_low, cost_high, quality_tier, applicable_room_types, tags) VALUES
-- HVAC
('HVAC', 'Central AC Unit', 'Central air conditioning unit', 'unit', 3000, 7000, 'standard', ARRAY['wholehouse']::room_type[], ARRAY['cooling', 'energy-efficient']),
('HVAC', 'Furnace', 'Gas or electric furnace', 'unit', 2500, 6000, 'standard', ARRAY['wholehouse', 'basement']::room_type[], ARRAY['heating', 'gas', 'electric']),
('HVAC', 'Mini-Split System', 'Ductless mini-split AC/heat', 'unit', 1500, 4000, 'standard', ARRAY['bedroom', 'living_room', 'addition']::room_type[], ARRAY['ductless', 'efficient', 'zone-control']),
('HVAC', 'Smart Thermostat', 'WiFi-enabled smart thermostat', 'each', 150, 400, 'standard', ARRAY['wholehouse']::room_type[], ARRAY['smart-home', 'energy-saving']),

-- Electrical
('Electrical', 'Panel Upgrade', '200A electrical panel upgrade', 'job', 1500, 3500, 'standard', ARRAY['wholehouse', 'electrical']::room_type[], ARRAY['safety', 'capacity']),
('Electrical', 'Outlet Installation', 'Standard electrical outlet', 'each', 100, 250, 'standard', ARRAY['kitchen', 'bathroom', 'bedroom', 'living_room']::room_type[], ARRAY['power', 'convenience']),
('Electrical', 'EV Charger Installation', 'Level 2 EV charger', 'job', 1000, 2500, 'premium', ARRAY['garage']::room_type[], ARRAY['electric-vehicle', 'green']),

-- Plumbing
('Plumbing', 'Water Heater - Tank', 'Traditional tank water heater', 'unit', 800, 2000, 'standard', ARRAY['basement', 'plumbing']::room_type[], ARRAY['hot-water', 'tank']),
('Plumbing', 'Water Heater - Tankless', 'On-demand tankless water heater', 'unit', 1500, 4000, 'premium', ARRAY['basement', 'plumbing']::room_type[], ARRAY['hot-water', 'energy-efficient', 'space-saving']),
('Plumbing', 'Garbage Disposal', 'Kitchen garbage disposal', 'unit', 150, 500, 'standard', ARRAY['kitchen']::room_type[], ARRAY['convenience', 'kitchen']),
('Plumbing', 'Sump Pump', 'Basement sump pump system', 'unit', 500, 1500, 'standard', ARRAY['basement']::room_type[], ARRAY['flood-prevention', 'basement']),

-- Roofing
('Roofing', 'Asphalt Shingles', 'Standard 3-tab asphalt shingles', 'sq ft', 3, 7, 'economy', ARRAY['roof']::room_type[], ARRAY['budget', 'common']),
('Roofing', 'Architectural Shingles', 'Dimensional asphalt shingles', 'sq ft', 4, 10, 'standard', ARRAY['roof']::room_type[], ARRAY['dimensional', 'durable']),
('Roofing', 'Metal Roofing', 'Standing seam metal roof', 'sq ft', 8, 18, 'premium', ARRAY['roof']::room_type[], ARRAY['durable', 'modern', 'long-lasting']),
('Roofing', 'Solar Tiles', 'Integrated solar roof tiles', 'sq ft', 20, 35, 'luxury', ARRAY['roof']::room_type[], ARRAY['solar', 'green', 'tech']),

-- Deck/Exterior
('Decking', 'Pressure-Treated Lumber', 'Standard PT deck boards', 'sq ft', 15, 25, 'economy', ARRAY['deck', 'exterior']::room_type[], ARRAY['budget', 'traditional']),
('Decking', 'Composite Decking', 'Low-maintenance composite boards', 'sq ft', 25, 45, 'standard', ARRAY['deck', 'exterior']::room_type[], ARRAY['low-maintenance', 'durable']),
('Decking', 'IPE Hardwood', 'Brazilian hardwood decking', 'sq ft', 40, 70, 'luxury', ARRAY['deck', 'exterior']::room_type[], ARRAY['hardwood', 'premium', 'natural']),

-- Windows/Doors
('Windows', 'Vinyl Windows', 'Double-pane vinyl windows', 'each', 300, 700, 'standard', ARRAY['wholehouse', 'bedroom', 'living_room']::room_type[], ARRAY['energy-efficient', 'low-maintenance']),
('Windows', 'Wood Windows', 'Solid wood frame windows', 'each', 600, 1500, 'premium', ARRAY['wholehouse', 'bedroom', 'living_room']::room_type[], ARRAY['natural', 'classic', 'premium']),
('Doors', 'Interior Door', 'Hollow-core interior door', 'each', 50, 200, 'economy', ARRAY['bedroom', 'bathroom']::room_type[], ARRAY['budget', 'basic']),
('Doors', 'Solid Core Door', 'Solid core interior door', 'each', 150, 400, 'standard', ARRAY['bedroom', 'bathroom']::room_type[], ARRAY['soundproof', 'quality']),
('Doors', 'Entry Door', 'Exterior entry door', 'each', 500, 2000, 'standard', ARRAY['exterior']::room_type[], ARRAY['security', 'curb-appeal']),

-- Insulation
('Insulation', 'Fiberglass Batts', 'Standard fiberglass insulation', 'sq ft', 0.50, 1.50, 'economy', ARRAY['attic', 'basement', 'wholehouse']::room_type[], ARRAY['budget', 'common']),
('Insulation', 'Spray Foam', 'Closed-cell spray foam insulation', 'sq ft', 1.50, 4.00, 'premium', ARRAY['attic', 'basement', 'wholehouse']::room_type[], ARRAY['air-seal', 'efficient', 'premium']),
('Insulation', 'Blown-In', 'Loose-fill cellulose or fiberglass', 'sq ft', 0.75, 2.00, 'standard', ARRAY['attic', 'wholehouse']::room_type[], ARRAY['retrofit', 'easy-install'])

ON CONFLICT DO NOTHING;

-- ============================================================================
-- STORAGE BUCKET SETUP
-- Note: Run these in Supabase Dashboard > Storage or via API
-- ============================================================================

-- Storage bucket policies are defined separately in the storage setup
-- See: supabase/storage_setup.sql

