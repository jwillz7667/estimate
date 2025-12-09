-- ============================================================================
-- RenovationEstimator Pro - Supabase Database Schema
-- ============================================================================
-- Complete database schema with authentication, tables, RLS policies,
-- indexes, triggers, and functions for enterprise-grade security
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- CUSTOM TYPES
-- ============================================================================

-- Subscription tiers
CREATE TYPE subscription_tier AS ENUM ('free', 'professional', 'enterprise');

-- Authentication providers
CREATE TYPE auth_provider AS ENUM ('email', 'google', 'apple');

-- Project status
CREATE TYPE project_status AS ENUM (
    'draft',
    'estimating',
    'estimated',
    'approved',
    'in_progress',
    'completed',
    'cancelled'
);

-- Room types
CREATE TYPE room_type AS ENUM (
    'kitchen',
    'bathroom',
    'bedroom',
    'living_room',
    'basement',
    'attic',
    'garage',
    'deck',
    'wholehouse',
    'addition',
    'exterior',
    'roof',
    'flooring',
    'electrical',
    'plumbing',
    'hvac'
);

-- Quality tiers
CREATE TYPE quality_tier AS ENUM ('economy', 'standard', 'premium', 'luxury');

-- Project urgency
CREATE TYPE project_urgency AS ENUM ('flexible', 'standard', 'rush', 'emergency');

-- Image styles
CREATE TYPE image_style AS ENUM (
    'photorealistic',
    'architectural',
    'sketch',
    'modern',
    'traditional',
    'industrial',
    'scandinavian',
    'coastal'
);

-- Measurement systems
CREATE TYPE measurement_system AS ENUM ('imperial', 'metric');

-- ============================================================================
-- PROFILES TABLE (extends auth.users)
-- ============================================================================

CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    display_name TEXT,
    company_name TEXT,
    phone_number TEXT,
    avatar_url TEXT,
    license_number TEXT,
    service_regions TEXT[] DEFAULT '{}',
    specializations TEXT[] DEFAULT '{}',
    default_quality_tier quality_tier DEFAULT 'standard',
    prefers_dark_mode BOOLEAN,
    measurement_system measurement_system DEFAULT 'imperial',
    subscription_tier subscription_tier DEFAULT 'free',
    subscription_expires_at TIMESTAMPTZ,
    subscription_product_id TEXT,
    estimates_generated_this_month INTEGER DEFAULT 0,
    images_generated_this_month INTEGER DEFAULT 0,
    usage_reset_date TIMESTAMPTZ DEFAULT NOW(),
    auth_provider auth_provider DEFAULT 'email',
    is_email_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    last_active_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- RENOVATION PROJECTS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS renovation_projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    project_name TEXT NOT NULL,
    room_type room_type NOT NULL,
    square_footage DECIMAL(10, 2) NOT NULL DEFAULT 0,
    location TEXT,
    zip_code TEXT,
    budget_min DECIMAL(12, 2) DEFAULT 0,
    budget_max DECIMAL(12, 2) DEFAULT 0,
    selected_materials TEXT[] DEFAULT '{}',
    quality_tier quality_tier DEFAULT 'standard',
    notes TEXT,
    urgency project_urgency DEFAULT 'standard',
    includes_permits BOOLEAN DEFAULT TRUE,
    includes_design BOOLEAN DEFAULT FALSE,
    status project_status DEFAULT 'draft',
    is_archived BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================================================
-- ESTIMATE RESULTS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS estimate_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES renovation_projects(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    total_cost_low DECIMAL(12, 2) NOT NULL DEFAULT 0,
    total_cost_high DECIMAL(12, 2) NOT NULL DEFAULT 0,
    labor_cost_low DECIMAL(12, 2) DEFAULT 0,
    labor_cost_high DECIMAL(12, 2) DEFAULT 0,
    material_cost_low DECIMAL(12, 2) DEFAULT 0,
    material_cost_high DECIMAL(12, 2) DEFAULT 0,
    permit_cost DECIMAL(12, 2) DEFAULT 0,
    design_cost DECIMAL(12, 2) DEFAULT 0,
    contingency_cost DECIMAL(12, 2) DEFAULT 0,
    timeline_days_low INTEGER DEFAULT 0,
    timeline_days_high INTEGER DEFAULT 0,
    recommended_season TEXT,
    confidence_score DECIMAL(3, 2) DEFAULT 0.8,
    regional_multiplier DECIMAL(4, 2) DEFAULT 1.0,
    region_name TEXT,
    notes TEXT,
    warnings TEXT[] DEFAULT '{}',
    recommendations TEXT[] DEFAULT '{}',
    breakdown JSONB DEFAULT '[]',
    raw_response JSONB,
    api_model TEXT,
    generation_duration_ms INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================================================
-- ESTIMATE LINE ITEMS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS estimate_line_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    estimate_id UUID NOT NULL REFERENCES estimate_results(id) ON DELETE CASCADE,
    category TEXT NOT NULL,
    item_name TEXT NOT NULL,
    description TEXT,
    quantity DECIMAL(10, 2) DEFAULT 1,
    unit TEXT,
    cost_low DECIMAL(12, 2) DEFAULT 0,
    cost_high DECIMAL(12, 2) DEFAULT 0,
    is_optional BOOLEAN DEFAULT FALSE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================================================
-- GENERATED IMAGES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS generated_images (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES renovation_projects(id) ON DELETE SET NULL,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    image_url TEXT,
    thumbnail_url TEXT,
    storage_path TEXT,
    prompt TEXT NOT NULL,
    style image_style DEFAULT 'photorealistic',
    aspect_ratio TEXT DEFAULT '16:9',
    title TEXT,
    notes TEXT,
    is_favorite BOOLEAN DEFAULT FALSE,
    generation_duration_ms INTEGER,
    api_model TEXT,
    width INTEGER,
    height INTEGER,
    file_size_bytes INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================================================
-- MATERIALS CATALOG TABLE (system-wide reference data)
-- ============================================================================

CREATE TABLE IF NOT EXISTS materials_catalog (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    unit TEXT,
    cost_low DECIMAL(10, 2),
    cost_high DECIMAL(10, 2),
    quality_tier quality_tier DEFAULT 'standard',
    applicable_room_types room_type[] DEFAULT '{}',
    tags TEXT[] DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================================================
-- API USAGE LOGS TABLE (for analytics and rate limiting)
-- ============================================================================

CREATE TABLE IF NOT EXISTS api_usage_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    endpoint TEXT NOT NULL,
    request_type TEXT NOT NULL,
    tokens_used INTEGER DEFAULT 0,
    cost_cents INTEGER DEFAULT 0,
    duration_ms INTEGER,
    status_code INTEGER,
    error_message TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================================================
-- SUBSCRIPTION HISTORY TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS subscription_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    product_id TEXT NOT NULL,
    tier subscription_tier NOT NULL,
    transaction_id TEXT,
    original_transaction_id TEXT,
    purchase_date TIMESTAMPTZ NOT NULL,
    expiration_date TIMESTAMPTZ,
    is_trial BOOLEAN DEFAULT FALSE,
    is_renewal BOOLEAN DEFAULT FALSE,
    environment TEXT DEFAULT 'production',
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Profiles indexes
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_subscription ON profiles(subscription_tier, subscription_expires_at);

-- Projects indexes
CREATE INDEX IF NOT EXISTS idx_projects_user ON renovation_projects(user_id);
CREATE INDEX IF NOT EXISTS idx_projects_status ON renovation_projects(status);
CREATE INDEX IF NOT EXISTS idx_projects_user_status ON renovation_projects(user_id, status);
CREATE INDEX IF NOT EXISTS idx_projects_updated ON renovation_projects(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_projects_search ON renovation_projects USING gin(to_tsvector('english', project_name || ' ' || COALESCE(notes, '')));

-- Estimates indexes
CREATE INDEX IF NOT EXISTS idx_estimates_project ON estimate_results(project_id);
CREATE INDEX IF NOT EXISTS idx_estimates_user ON estimate_results(user_id);
CREATE INDEX IF NOT EXISTS idx_estimates_created ON estimate_results(created_at DESC);

-- Line items indexes
CREATE INDEX IF NOT EXISTS idx_line_items_estimate ON estimate_line_items(estimate_id);
CREATE INDEX IF NOT EXISTS idx_line_items_category ON estimate_line_items(category);

-- Images indexes
CREATE INDEX IF NOT EXISTS idx_images_user ON generated_images(user_id);
CREATE INDEX IF NOT EXISTS idx_images_project ON generated_images(project_id);
CREATE INDEX IF NOT EXISTS idx_images_favorites ON generated_images(user_id, is_favorite) WHERE is_favorite = TRUE;

-- Materials indexes
CREATE INDEX IF NOT EXISTS idx_materials_category ON materials_catalog(category);
CREATE INDEX IF NOT EXISTS idx_materials_search ON materials_catalog USING gin(to_tsvector('english', name || ' ' || COALESCE(description, '')));

-- API logs indexes
CREATE INDEX IF NOT EXISTS idx_api_logs_user ON api_usage_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_api_logs_created ON api_usage_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_api_logs_user_date ON api_usage_logs(user_id, created_at);

-- ============================================================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE renovation_projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE estimate_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE estimate_line_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE generated_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_usage_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE materials_catalog ENABLE ROW LEVEL SECURITY;

-- PROFILES POLICIES
CREATE POLICY "Users can view own profile"
    ON profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
    ON profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- RENOVATION PROJECTS POLICIES
CREATE POLICY "Users can view own projects"
    ON renovation_projects FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create own projects"
    ON renovation_projects FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own projects"
    ON renovation_projects FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own projects"
    ON renovation_projects FOR DELETE
    USING (auth.uid() = user_id);

-- ESTIMATE RESULTS POLICIES
CREATE POLICY "Users can view own estimates"
    ON estimate_results FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create own estimates"
    ON estimate_results FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own estimates"
    ON estimate_results FOR DELETE
    USING (auth.uid() = user_id);

-- ESTIMATE LINE ITEMS POLICIES
CREATE POLICY "Users can view line items of own estimates"
    ON estimate_line_items FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM estimate_results
            WHERE estimate_results.id = estimate_line_items.estimate_id
            AND estimate_results.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create line items for own estimates"
    ON estimate_line_items FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM estimate_results
            WHERE estimate_results.id = estimate_line_items.estimate_id
            AND estimate_results.user_id = auth.uid()
        )
    );

-- GENERATED IMAGES POLICIES
CREATE POLICY "Users can view own images"
    ON generated_images FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create own images"
    ON generated_images FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own images"
    ON generated_images FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own images"
    ON generated_images FOR DELETE
    USING (auth.uid() = user_id);

-- API USAGE LOGS POLICIES
CREATE POLICY "Users can view own API logs"
    ON api_usage_logs FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "System can insert API logs"
    ON api_usage_logs FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- SUBSCRIPTION HISTORY POLICIES
CREATE POLICY "Users can view own subscription history"
    ON subscription_history FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "System can insert subscription history"
    ON subscription_history FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- MATERIALS CATALOG POLICIES (read-only for all authenticated users)
CREATE POLICY "Authenticated users can view materials"
    ON materials_catalog FOR SELECT
    TO authenticated
    USING (is_active = TRUE);

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to create profile on user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, email, auth_provider)
    VALUES (
        NEW.id,
        NEW.email,
        CASE
            WHEN NEW.raw_app_meta_data->>'provider' = 'google' THEN 'google'::auth_provider
            WHEN NEW.raw_app_meta_data->>'provider' = 'apple' THEN 'apple'::auth_provider
            ELSE 'email'::auth_provider
        END
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to reset monthly usage
CREATE OR REPLACE FUNCTION reset_monthly_usage()
RETURNS void AS $$
BEGIN
    UPDATE profiles
    SET
        estimates_generated_this_month = 0,
        images_generated_this_month = 0,
        usage_reset_date = NOW()
    WHERE usage_reset_date < DATE_TRUNC('month', NOW());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to increment estimate count
CREATE OR REPLACE FUNCTION increment_estimate_count(p_user_id UUID)
RETURNS void AS $$
BEGIN
    UPDATE profiles
    SET estimates_generated_this_month = estimates_generated_this_month + 1
    WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to increment image count
CREATE OR REPLACE FUNCTION increment_image_count(p_user_id UUID)
RETURNS void AS $$
BEGIN
    UPDATE profiles
    SET images_generated_this_month = images_generated_this_month + 1
    WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check usage limits
CREATE OR REPLACE FUNCTION check_usage_limit(p_user_id UUID, p_type TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_tier subscription_tier;
    v_count INTEGER;
    v_limit INTEGER;
BEGIN
    SELECT subscription_tier INTO v_tier FROM profiles WHERE id = p_user_id;

    IF p_type = 'estimate' THEN
        SELECT estimates_generated_this_month INTO v_count FROM profiles WHERE id = p_user_id;
        v_limit := CASE v_tier
            WHEN 'free' THEN 5
            WHEN 'professional' THEN 100
            WHEN 'enterprise' THEN 999999
        END;
    ELSIF p_type = 'image' THEN
        SELECT images_generated_this_month INTO v_count FROM profiles WHERE id = p_user_id;
        v_limit := CASE v_tier
            WHEN 'free' THEN 3
            WHEN 'professional' THEN 50
            WHEN 'enterprise' THEN 999999
        END;
    ELSE
        RETURN FALSE;
    END IF;

    RETURN v_count < v_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Trigger to update updated_at on profiles
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger to update updated_at on projects
CREATE TRIGGER update_projects_updated_at
    BEFORE UPDATE ON renovation_projects
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger to update updated_at on materials
CREATE TRIGGER update_materials_updated_at
    BEFORE UPDATE ON materials_catalog
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger to create profile on auth.users insert
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();

-- ============================================================================
-- SEED DATA - Materials Catalog
-- ============================================================================

INSERT INTO materials_catalog (category, name, description, unit, cost_low, cost_high, quality_tier, applicable_room_types, tags) VALUES
-- Kitchen materials
('Countertops', 'Laminate Countertop', 'Budget-friendly laminate surface', 'sq ft', 15, 40, 'economy', ARRAY['kitchen']::room_type[], ARRAY['budget', 'easy-maintenance']),
('Countertops', 'Granite Countertop', 'Natural granite stone surface', 'sq ft', 50, 200, 'premium', ARRAY['kitchen', 'bathroom']::room_type[], ARRAY['natural', 'durable', 'premium']),
('Countertops', 'Quartz Countertop', 'Engineered quartz surface', 'sq ft', 75, 150, 'premium', ARRAY['kitchen', 'bathroom']::room_type[], ARRAY['engineered', 'non-porous', 'modern']),
('Countertops', 'Marble Countertop', 'Luxury natural marble', 'sq ft', 100, 300, 'luxury', ARRAY['kitchen', 'bathroom']::room_type[], ARRAY['luxury', 'natural', 'classic']),
('Cabinets', 'Stock Cabinets', 'Pre-made standard cabinets', 'linear ft', 100, 300, 'economy', ARRAY['kitchen', 'bathroom']::room_type[], ARRAY['budget', 'quick-install']),
('Cabinets', 'Semi-Custom Cabinets', 'Modified standard cabinets', 'linear ft', 150, 650, 'standard', ARRAY['kitchen', 'bathroom']::room_type[], ARRAY['customizable', 'good-value']),
('Cabinets', 'Custom Cabinets', 'Fully custom built cabinets', 'linear ft', 500, 1200, 'luxury', ARRAY['kitchen', 'bathroom']::room_type[], ARRAY['custom', 'luxury', 'unique']),
('Appliances', 'Standard Appliance Package', 'Basic brand appliances', 'set', 2000, 4000, 'economy', ARRAY['kitchen']::room_type[], ARRAY['budget', 'functional']),
('Appliances', 'Mid-Range Appliance Package', 'Quality brand appliances', 'set', 4000, 8000, 'standard', ARRAY['kitchen']::room_type[], ARRAY['reliable', 'features']),
('Appliances', 'Premium Appliance Package', 'High-end brand appliances', 'set', 8000, 20000, 'premium', ARRAY['kitchen']::room_type[], ARRAY['premium', 'professional']),

-- Bathroom materials
('Fixtures', 'Standard Toilet', 'Basic toilet', 'each', 150, 350, 'economy', ARRAY['bathroom']::room_type[], ARRAY['budget', 'functional']),
('Fixtures', 'Low-Flow Toilet', 'Water-efficient toilet', 'each', 250, 500, 'standard', ARRAY['bathroom']::room_type[], ARRAY['eco-friendly', 'efficient']),
('Fixtures', 'Smart Toilet', 'High-tech bidet toilet', 'each', 800, 5000, 'luxury', ARRAY['bathroom']::room_type[], ARRAY['luxury', 'tech', 'bidet']),
('Fixtures', 'Standard Vanity', 'Pre-made bathroom vanity', 'each', 200, 600, 'economy', ARRAY['bathroom']::room_type[], ARRAY['budget', 'quick-install']),
('Fixtures', 'Custom Vanity', 'Custom built vanity', 'each', 800, 3000, 'premium', ARRAY['bathroom']::room_type[], ARRAY['custom', 'storage', 'premium']),
('Tile', 'Ceramic Tile', 'Standard ceramic floor/wall tile', 'sq ft', 2, 15, 'economy', ARRAY['bathroom', 'kitchen']::room_type[], ARRAY['budget', 'durable', 'easy-clean']),
('Tile', 'Porcelain Tile', 'Dense porcelain tile', 'sq ft', 5, 25, 'standard', ARRAY['bathroom', 'kitchen']::room_type[], ARRAY['durable', 'water-resistant']),
('Tile', 'Natural Stone Tile', 'Marble, travertine, or slate', 'sq ft', 10, 50, 'premium', ARRAY['bathroom', 'kitchen']::room_type[], ARRAY['natural', 'elegant', 'premium']),

-- Flooring materials
('Flooring', 'Carpet', 'Standard carpet with pad', 'sq ft', 3, 12, 'economy', ARRAY['bedroom', 'living_room']::room_type[], ARRAY['soft', 'warm', 'budget']),
('Flooring', 'Laminate Flooring', 'Click-lock laminate', 'sq ft', 3, 10, 'economy', ARRAY['bedroom', 'living_room', 'basement']::room_type[], ARRAY['budget', 'easy-install', 'durable']),
('Flooring', 'Engineered Hardwood', 'Engineered wood flooring', 'sq ft', 6, 15, 'standard', ARRAY['bedroom', 'living_room', 'kitchen']::room_type[], ARRAY['wood-look', 'stable', 'refinishable']),
('Flooring', 'Solid Hardwood', 'Solid wood flooring', 'sq ft', 8, 25, 'premium', ARRAY['bedroom', 'living_room']::room_type[], ARRAY['natural', 'refinishable', 'premium']),
('Flooring', 'Luxury Vinyl Plank', 'High-end vinyl plank', 'sq ft', 4, 12, 'standard', ARRAY['kitchen', 'bathroom', 'basement']::room_type[], ARRAY['waterproof', 'durable', 'wood-look']),

-- General materials
('Paint', 'Interior Paint - Economy', 'Basic interior latex paint', 'sq ft', 0.50, 1.50, 'economy', ARRAY['kitchen', 'bathroom', 'bedroom', 'living_room']::room_type[], ARRAY['budget', 'basic']),
('Paint', 'Interior Paint - Premium', 'High-quality interior paint', 'sq ft', 1.50, 3.00, 'premium', ARRAY['kitchen', 'bathroom', 'bedroom', 'living_room']::room_type[], ARRAY['durable', 'washable', 'premium']),
('Lighting', 'Recessed Lighting', 'LED recessed can lights', 'each', 75, 200, 'standard', ARRAY['kitchen', 'bathroom', 'bedroom', 'living_room']::room_type[], ARRAY['modern', 'energy-efficient']),
('Lighting', 'Pendant Lighting', 'Decorative pendant fixtures', 'each', 100, 500, 'premium', ARRAY['kitchen', 'living_room']::room_type[], ARRAY['decorative', 'statement'])
ON CONFLICT DO NOTHING;

-- ============================================================================
-- STORAGE BUCKETS (run in Supabase Dashboard)
-- ============================================================================
-- Note: These need to be created via Supabase Dashboard or API
--
-- Bucket: generated-images
--   Public: false
--   Allowed MIME types: image/jpeg, image/png, image/webp
--   Max file size: 10MB
--
-- Bucket: user-avatars
--   Public: true
--   Allowed MIME types: image/jpeg, image/png
--   Max file size: 2MB
--
-- Bucket: project-attachments
--   Public: false
--   Allowed MIME types: image/*, application/pdf
--   Max file size: 25MB

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant usage on schema
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO anon;

-- Grant execute on functions
GRANT EXECUTE ON FUNCTION reset_monthly_usage() TO authenticated;
GRANT EXECUTE ON FUNCTION check_usage_limit(UUID, TEXT) TO authenticated;
