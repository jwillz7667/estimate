# BUILD PEEK - Supabase Setup Guide

Complete guide for setting up Supabase backend for the BUILD PEEK iOS app.

## Quick Start

### 1. Create Supabase Project

1. Go to [supabase.com](https://supabase.com) and create a new project
2. Note your **Project URL** and **anon/public key** from Settings > API
3. Add these to your `Secrets.swift` file in the iOS project

### 2. Run Database Migrations

In the Supabase Dashboard SQL Editor, run these migrations in order:

```bash
# Option A: Using Supabase CLI
supabase db push

# Option B: Manual - Copy/paste into SQL Editor
1. supabase/migrations/20241206_initial_schema.sql
2. supabase/migrations/20241210_complete_schema.sql
3. supabase/storage_setup.sql
```

### 3. Set Up Storage Buckets

Run `storage_setup.sql` in the SQL Editor, or create buckets manually:

| Bucket | Public | Size Limit | MIME Types |
|--------|--------|------------|------------|
| `generated-images` | No | 10MB | image/jpeg, image/png, image/webp |
| `user-avatars` | Yes | 2MB | image/jpeg, image/png |
| `project-photos` | No | 15MB | image/jpeg, image/png, image/webp, image/heic |
| `project-attachments` | No | 25MB | image/*, application/pdf |
| `exported-pdfs` | No | 50MB | application/pdf |

### 4. Configure Authentication

In Supabase Dashboard > Authentication > Providers:

#### Email/Password
- Enable "Email" provider
- Configure email templates (optional)

#### Google OAuth
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create OAuth 2.0 credentials
3. Add authorized redirect URI: `https://YOUR_PROJECT.supabase.co/auth/v1/callback`
4. Copy Client ID and Secret to Supabase

#### Apple Sign-In
1. Configure in Apple Developer Portal
2. Add Services ID with Supabase callback URL
3. Generate key and add to Supabase

### 5. Deploy Edge Functions

```bash
# Install Supabase CLI
npm install -g supabase

# Login
supabase login

# Link to your project
supabase link --project-ref YOUR_PROJECT_REF

# Deploy functions
supabase functions deploy generate-estimate
supabase functions deploy generate-image
supabase functions deploy process-subscription
supabase functions deploy upload-photo

# Set secrets
supabase secrets set GEMINI_API_KEY=your_gemini_api_key
```

### 6. Configure Environment Variables

Set these secrets for edge functions:

```bash
supabase secrets set GEMINI_API_KEY=your_gemini_api_key
supabase secrets set APPLE_SHARED_SECRET=your_apple_iap_secret  # Optional
```

## Database Schema

### Tables

| Table | Description |
|-------|-------------|
| `profiles` | User profiles (extends auth.users) |
| `renovation_projects` | User's renovation projects |
| `estimate_results` | AI-generated cost estimates |
| `estimate_line_items` | Detailed line items per estimate |
| `generated_images` | AI-generated visualization images |
| `project_photos` | User-uploaded reference photos |
| `materials_catalog` | Reference materials database |
| `local_sellers` | Local material sellers |
| `price_quotes` | User price lookups |
| `api_usage_logs` | API usage tracking |
| `subscription_history` | Subscription transactions |
| `shared_projects` | Project sharing links |
| `user_feedback` | User feedback and ratings |

### Row Level Security (RLS)

All tables have RLS enabled. Users can only:
- View/modify their own data
- Read public reference data (materials_catalog, local_sellers)

### Key Functions

| Function | Description |
|----------|-------------|
| `reset_monthly_usage()` | Reset monthly usage counters |
| `increment_estimate_count(user_id)` | Increment estimate counter |
| `increment_image_count(user_id)` | Increment image counter |
| `check_usage_limit(user_id, type)` | Check if user is within limits |
| `get_user_stats(user_id)` | Get dashboard statistics |
| `search_materials(query, ...)` | Search materials catalog |

## Edge Functions

### generate-estimate
Generates AI cost estimates using Gemini 3.0 Pro.

**Request:**
```json
{
  "projectId": "uuid",
  "roomType": "kitchen",
  "squareFootage": 200,
  "qualityTier": "standard",
  "location": "Los Angeles, CA",
  "includesPermits": true,
  "includesDesign": false,
  "urgency": "standard"
}
```

### generate-image
Generates renovation visualizations using Nano Banana Pro.

**Request:**
```json
{
  "projectId": "uuid",
  "prompt": "Modern kitchen renovation with white cabinets",
  "style": "photorealistic",
  "aspectRatio": "16:9"
}
```

### process-subscription
Processes App Store subscription purchases.

**Request:**
```json
{
  "receipt": "base64_receipt_data",
  "productId": "com.projectestimate.pro.monthly",
  "transactionId": "123456789"
}
```

### upload-photo
Uploads project reference photos.

**Request:** `multipart/form-data`
- `file`: Image file
- `projectId`: Project UUID
- `photoType`: "before" | "during" | "after" | "reference"
- `description`: Optional description

## Subscription Tiers

| Tier | Estimates/Month | Images/Month | Features |
|------|----------------|--------------|----------|
| Free | 5 | 3 | Basic |
| Professional | 100 | 50 | + Priority AI, Custom branding |
| Enterprise | Unlimited | Unlimited | + API access, Multi-user |

## Troubleshooting

### "Permission denied" errors
- Check RLS policies are correctly applied
- Verify user is authenticated
- Check storage bucket policies

### Image upload fails
- Verify bucket exists and has correct policies
- Check file size limits
- Ensure correct MIME type

### Edge function errors
- Check function logs: `supabase functions logs generate-estimate`
- Verify secrets are set: `supabase secrets list`
- Check CORS headers in response

## Useful SQL Queries

```sql
-- Check user's usage
SELECT * FROM profiles WHERE email = 'user@example.com';

-- View recent estimates
SELECT * FROM estimate_results ORDER BY created_at DESC LIMIT 10;

-- Check storage usage
SELECT bucket_id, COUNT(*), SUM(metadata->>'size')::bigint
FROM storage.objects
GROUP BY bucket_id;

-- Reset a user's monthly usage
UPDATE profiles SET
  estimates_generated_this_month = 0,
  images_generated_this_month = 0
WHERE id = 'user-uuid';
```

## Support

For issues with:
- **Database/Auth**: Check Supabase documentation
- **Edge Functions**: Check Deno Deploy logs
- **iOS App**: See app documentation
