// BUILD PEEK - Generate Image Edge Function
// Handles AI image generation via Nano Banana Pro (Gemini) with storage integration

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { decode as base64Decode } from "https://deno.land/std@0.168.0/encoding/base64.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ImageRequest {
  projectId?: string
  prompt: string
  style: string
  aspectRatio: string
  title?: string
  notes?: string
  referenceImageBase64?: string  // Optional reference photo for image-to-image
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get auth token
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'No authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Get user from auth header
    const userClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: authHeader } }
    })
    const { data: { user }, error: userError } = await userClient.auth.getUser()

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check usage limit
    const { data: profile } = await supabase
      .from('profiles')
      .select('subscription_tier, images_generated_this_month')
      .eq('id', user.id)
      .single()

    if (!profile) {
      return new Response(
        JSON.stringify({ error: 'Profile not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const limits: Record<string, number> = {
      'free': 3,
      'professional': 50,
      'enterprise': 999999
    }

    const limit = limits[profile.subscription_tier] || 3
    if (profile.images_generated_this_month >= limit) {
      return new Response(
        JSON.stringify({
          error: 'Monthly image generation limit reached',
          limit,
          used: profile.images_generated_this_month
        }),
        { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Parse request body
    const body: ImageRequest = await req.json()

    // Build enhanced prompt
    const enhancedPrompt = buildImagePrompt(body)

    // Call Nano Banana Pro (Gemini Image Generation)
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY')
    if (!geminiApiKey) {
      return new Response(
        JSON.stringify({ error: 'Gemini API not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const startTime = Date.now()
    const imageData = await generateImage(geminiApiKey, enhancedPrompt, body.referenceImageBase64)
    const duration = Date.now() - startTime

    if (!imageData) {
      return new Response(
        JSON.stringify({ error: 'Failed to generate image' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Upload to Supabase Storage
    const imageId = crypto.randomUUID()
    const storagePath = `${user.id}/${imageId}.jpg`

    const { error: uploadError } = await supabase.storage
      .from('generated-images')
      .upload(storagePath, base64Decode(imageData), {
        contentType: 'image/jpeg',
        upsert: false
      })

    if (uploadError) {
      console.error('Storage upload error:', uploadError)
      return new Response(
        JSON.stringify({ error: 'Failed to save image' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get public URL
    const { data: urlData } = supabase.storage
      .from('generated-images')
      .getPublicUrl(storagePath)

    // Create thumbnail (smaller version)
    const thumbnailPath = `${user.id}/thumb_${imageId}.jpg`
    // Note: In production, you'd resize the image here

    // Save to database
    const { data: savedImage, error: saveError } = await supabase
      .from('generated_images')
      .insert({
        id: imageId,
        project_id: body.projectId || null,
        user_id: user.id,
        storage_path: storagePath,
        thumbnail_url: null, // Set after thumbnail creation
        image_url: urlData.publicUrl,
        prompt: body.prompt,
        style: body.style.toLowerCase().replace(/\s+/g, '_'),
        aspect_ratio: body.aspectRatio,
        title: body.title || `Generated ${new Date().toLocaleDateString()}`,
        notes: body.notes || '',
        generation_duration_ms: duration,
        api_model: 'nano-banana-pro'
      })
      .select()
      .single()

    if (saveError) {
      console.error('Database save error:', saveError)
      // Clean up uploaded file
      await supabase.storage.from('generated-images').remove([storagePath])
      return new Response(
        JSON.stringify({ error: 'Failed to save image record' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Increment usage count
    await supabase.rpc('increment_image_count', { p_user_id: user.id })

    // Log API usage
    await supabase.rpc('log_api_usage', {
      p_user_id: user.id,
      p_endpoint: 'generate-image',
      p_request_type: 'nano-banana-pro',
      p_tokens_used: 0,
      p_cost_cents: 0,
      p_duration_ms: duration,
      p_status_code: 200
    })

    return new Response(
      JSON.stringify({
        success: true,
        image: savedImage,
        imageUrl: urlData.publicUrl,
        duration_ms: duration
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

function buildImagePrompt(request: ImageRequest): string {
  // Style modifiers
  const styleModifiers: Record<string, string> = {
    'photorealistic': 'photorealistic, high-resolution photograph, professional interior photography, natural lighting, 8K quality',
    'architectural': 'architectural 3D rendering, professional visualization, clean lines, accurate proportions, ambient occlusion',
    'sketch': 'architectural sketch, blueprint style, technical drawing, pencil rendering, professional drafting',
    'modern': 'modern minimalist design, clean aesthetic, contemporary style, sleek finishes, Scandinavian influence',
    'traditional': 'traditional style, classic design elements, warm and inviting, timeless elegance, rich details',
    'industrial': 'industrial style, exposed elements, raw materials, urban loft aesthetic, Edison bulbs',
    'scandinavian': 'scandinavian design, light and airy, natural materials, hygge atmosphere, white walls',
    'coastal': 'coastal style, beach-inspired, light colors, relaxed atmosphere, natural textures'
  }

  const styleMod = styleModifiers[request.style.toLowerCase()] || styleModifiers['photorealistic']

  return `CREATE A STUNNING RENOVATION VISUALIZATION:

${request.prompt}

STYLE: ${styleMod}

REQUIREMENTS:
- Professional quality interior/exterior photography
- Perfect lighting and composition
- Realistic materials and textures
- Show the space from a flattering angle
- Include subtle lifestyle elements (plants, decor)
- Ensure proper scale and proportions
- No people in the image
- High dynamic range
- Magazine-quality result

AVOID:
- Unrealistic elements
- Distorted perspectives
- Inconsistent lighting
- Low-quality textures
- Cluttered composition`
}

async function generateImage(apiKey: string, prompt: string, referenceImage?: string): Promise<string | null> {
  // Use Nano Banana Pro (Gemini Image Generation)
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent?key=${apiKey}`

  const parts: any[] = [{ text: prompt }]

  // Add reference image if provided (for image-to-image generation)
  if (referenceImage) {
    parts.unshift({
      inline_data: {
        mime_type: 'image/jpeg',
        data: referenceImage
      }
    })
  }

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ parts }],
      generationConfig: {
        temperature: 0.9,
        maxOutputTokens: 8192,
        responseModalities: ['image', 'text'],
        responseMimeType: 'image/jpeg'
      }
    })
  })

  if (!response.ok) {
    const error = await response.text()
    console.error('Gemini API error:', error)
    throw new Error(`Image generation failed: ${error}`)
  }

  const data = await response.json()

  // Extract image data from response
  const candidate = data.candidates?.[0]
  if (!candidate) {
    throw new Error('No image generated')
  }

  // Find image part in response
  for (const part of candidate.content?.parts || []) {
    if (part.inline_data?.data) {
      return part.inline_data.data
    }
  }

  throw new Error('No image data in response')
}
