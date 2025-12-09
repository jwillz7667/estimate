-- ============================================================================
-- BUILD PEEK - Supabase Storage Bucket Configuration
-- ============================================================================
-- Run this in Supabase Dashboard SQL Editor or via supabase CLI
-- This sets up storage buckets and their access policies
-- ============================================================================

-- ============================================================================
-- CREATE STORAGE BUCKETS
-- ============================================================================

-- Bucket for AI-generated images (private, user-specific)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'generated-images',
    'generated-images',
    false,
    10485760, -- 10MB limit
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Bucket for user avatars (public for display)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'user-avatars',
    'user-avatars',
    true,
    2097152, -- 2MB limit
    ARRAY['image/jpeg', 'image/png']
)
ON CONFLICT (id) DO UPDATE SET
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Bucket for project attachments/photos (private)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'project-attachments',
    'project-attachments',
    false,
    26214400, -- 25MB limit
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf']
)
ON CONFLICT (id) DO UPDATE SET
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Bucket for project photos (private, user-uploaded reference photos)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'project-photos',
    'project-photos',
    false,
    15728640, -- 15MB limit
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
ON CONFLICT (id) DO UPDATE SET
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Bucket for exported PDFs (private)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'exported-pdfs',
    'exported-pdfs',
    false,
    52428800, -- 50MB limit
    ARRAY['application/pdf']
)
ON CONFLICT (id) DO UPDATE SET
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ============================================================================
-- STORAGE POLICIES - Generated Images
-- ============================================================================

-- Users can upload their own generated images
CREATE POLICY "Users can upload generated images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'generated-images' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Users can view their own generated images
CREATE POLICY "Users can view own generated images"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'generated-images' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Users can update their own generated images
CREATE POLICY "Users can update own generated images"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'generated-images' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Users can delete their own generated images
CREATE POLICY "Users can delete own generated images"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'generated-images' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- ============================================================================
-- STORAGE POLICIES - User Avatars
-- ============================================================================

-- Users can upload their own avatar
CREATE POLICY "Users can upload own avatar"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'user-avatars' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Anyone can view avatars (public bucket)
CREATE POLICY "Anyone can view avatars"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'user-avatars');

-- Users can update their own avatar
CREATE POLICY "Users can update own avatar"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'user-avatars' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Users can delete their own avatar
CREATE POLICY "Users can delete own avatar"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'user-avatars' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- ============================================================================
-- STORAGE POLICIES - Project Attachments
-- ============================================================================

-- Users can upload attachments to their projects
CREATE POLICY "Users can upload project attachments"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'project-attachments' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Users can view their own project attachments
CREATE POLICY "Users can view own project attachments"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'project-attachments' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Users can delete their own project attachments
CREATE POLICY "Users can delete own project attachments"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'project-attachments' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- ============================================================================
-- STORAGE POLICIES - Project Photos
-- ============================================================================

-- Users can upload photos to their projects
CREATE POLICY "Users can upload project photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'project-photos' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Users can view their own project photos
CREATE POLICY "Users can view own project photos"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'project-photos' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Users can delete their own project photos
CREATE POLICY "Users can delete own project photos"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'project-photos' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- ============================================================================
-- STORAGE POLICIES - Exported PDFs
-- ============================================================================

-- Users can upload exported PDFs
CREATE POLICY "Users can upload exported PDFs"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'exported-pdfs' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Users can view their own exported PDFs
CREATE POLICY "Users can view own exported PDFs"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'exported-pdfs' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Users can delete their own exported PDFs
CREATE POLICY "Users can delete own exported PDFs"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'exported-pdfs' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- ============================================================================
-- HELPER FUNCTIONS FOR STORAGE
-- ============================================================================

-- Function to get signed URL for private objects
CREATE OR REPLACE FUNCTION get_signed_url(
    p_bucket_id TEXT,
    p_path TEXT,
    p_expires_in INTEGER DEFAULT 3600 -- 1 hour default
)
RETURNS TEXT AS $$
DECLARE
    v_url TEXT;
BEGIN
    -- Verify user owns this file
    IF NOT EXISTS (
        SELECT 1 FROM storage.objects
        WHERE bucket_id = p_bucket_id
        AND name = p_path
        AND (storage.foldername(name))[1] = auth.uid()::text
    ) THEN
        RAISE EXCEPTION 'Access denied to file';
    END IF;

    -- Generate signed URL (this is a placeholder - actual implementation
    -- depends on Supabase storage extension)
    SELECT storage.signed_url(p_bucket_id, p_path, p_expires_in) INTO v_url;

    RETURN v_url;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to clean up orphaned storage objects
CREATE OR REPLACE FUNCTION cleanup_orphaned_images()
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER := 0;
BEGIN
    -- Delete generated images not linked to any record
    DELETE FROM storage.objects
    WHERE bucket_id = 'generated-images'
    AND name NOT IN (
        SELECT storage_path FROM generated_images WHERE storage_path IS NOT NULL
    )
    AND created_at < NOW() - INTERVAL '24 hours';

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute on functions
GRANT EXECUTE ON FUNCTION get_signed_url(TEXT, TEXT, INTEGER) TO authenticated;

