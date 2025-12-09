// BUILD PEEK - Generate Estimate Edge Function
// Handles AI estimate generation via Gemini API with rate limiting and usage tracking

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface EstimateRequest {
  projectId: string
  roomType: string
  squareFootage: number
  qualityTier: string
  location?: string
  zipCode?: string
  selectedMaterials?: string[]
  includesPermits: boolean
  includesDesign: boolean
  urgency: string
  notes?: string
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
    const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey, {
      global: { headers: { Authorization: authHeader } }
    })

    // Get user
    const { data: { user }, error: userError } = await supabase.auth.getUser()
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check usage limit
    const { data: profile } = await supabase
      .from('profiles')
      .select('subscription_tier, estimates_generated_this_month')
      .eq('id', user.id)
      .single()

    if (!profile) {
      return new Response(
        JSON.stringify({ error: 'Profile not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const limits: Record<string, number> = {
      'free': 5,
      'professional': 100,
      'enterprise': 999999
    }

    const limit = limits[profile.subscription_tier] || 5
    if (profile.estimates_generated_this_month >= limit) {
      return new Response(
        JSON.stringify({
          error: 'Monthly estimate limit reached',
          limit,
          used: profile.estimates_generated_this_month
        }),
        { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Parse request body
    const body: EstimateRequest = await req.json()

    // Build Gemini prompt
    const prompt = buildEstimatePrompt(body)

    // Call Gemini API
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY')
    if (!geminiApiKey) {
      return new Response(
        JSON.stringify({ error: 'Gemini API not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const startTime = Date.now()
    const geminiResponse = await callGeminiAPI(geminiApiKey, prompt)
    const duration = Date.now() - startTime

    // Parse and validate response
    const estimateData = parseGeminiResponse(geminiResponse)

    // Save estimate to database
    const { data: estimate, error: saveError } = await supabase
      .from('estimate_results')
      .insert({
        project_id: body.projectId,
        user_id: user.id,
        total_cost_low: estimateData.totalCost.low,
        total_cost_high: estimateData.totalCost.high,
        labor_cost_low: estimateData.laborCost?.low || 0,
        labor_cost_high: estimateData.laborCost?.high || 0,
        material_cost_low: estimateData.materialCost?.low || 0,
        material_cost_high: estimateData.materialCost?.high || 0,
        permit_cost: estimateData.permitCost || 0,
        design_cost: estimateData.designCost || 0,
        contingency_cost: estimateData.contingencyCost || 0,
        timeline_days_low: estimateData.timeline.daysLow,
        timeline_days_high: estimateData.timeline.daysHigh,
        recommended_season: estimateData.timeline.recommendedSeason,
        confidence_score: estimateData.confidence || 0.85,
        regional_multiplier: estimateData.regionalData?.multiplier || 1.0,
        region_name: estimateData.regionalData?.region || 'National Average',
        notes: estimateData.notes,
        warnings: estimateData.warnings || [],
        recommendations: estimateData.recommendations || [],
        breakdown: estimateData.breakdown,
        raw_response: geminiResponse,
        api_model: 'gemini-3.0-pro',
        generation_duration_ms: duration
      })
      .select()
      .single()

    if (saveError) {
      console.error('Error saving estimate:', saveError)
      return new Response(
        JSON.stringify({ error: 'Failed to save estimate' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Increment usage count
    await supabase.rpc('increment_estimate_count', { p_user_id: user.id })

    // Log API usage
    await supabase.rpc('log_api_usage', {
      p_user_id: user.id,
      p_endpoint: 'generate-estimate',
      p_request_type: 'gemini-estimate',
      p_tokens_used: 0, // TODO: Get actual token count
      p_cost_cents: 0,
      p_duration_ms: duration,
      p_status_code: 200
    })

    // Update project status
    await supabase
      .from('renovation_projects')
      .update({ status: 'estimated' })
      .eq('id', body.projectId)

    return new Response(
      JSON.stringify({
        success: true,
        estimate,
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

function buildEstimatePrompt(request: EstimateRequest): string {
  return `You are BUILD PEEK, an expert renovation cost estimator. Generate a detailed, accurate cost estimate for the following renovation project.

PROJECT DETAILS:
- Room Type: ${request.roomType}
- Square Footage: ${request.squareFootage} sq ft
- Quality Tier: ${request.qualityTier}
- Location: ${request.location || 'Not specified'} ${request.zipCode ? `(${request.zipCode})` : ''}
- Urgency: ${request.urgency}
- Include Permits: ${request.includesPermits ? 'Yes' : 'No'}
- Include Design Services: ${request.includesDesign ? 'Yes' : 'No'}
${request.selectedMaterials?.length ? `- Selected Materials: ${request.selectedMaterials.join(', ')}` : ''}
${request.notes ? `- Additional Notes: ${request.notes}` : ''}

Respond with a JSON object in this exact format:
{
  "totalCost": { "low": number, "high": number },
  "laborCost": { "low": number, "high": number },
  "materialCost": { "low": number, "high": number },
  "permitCost": number,
  "designCost": number,
  "contingencyCost": number,
  "breakdown": [
    {
      "category": "string",
      "item": "string",
      "description": "string",
      "quantity": number,
      "unit": "string",
      "costLow": number,
      "costHigh": number,
      "optional": boolean
    }
  ],
  "timeline": {
    "daysLow": number,
    "daysHigh": number,
    "recommendedSeason": "string"
  },
  "notes": "string with overall project notes",
  "warnings": ["array of potential issues or risks"],
  "recommendations": ["array of suggestions for cost savings or improvements"],
  "confidence": number between 0 and 1,
  "regionalData": {
    "multiplier": number,
    "region": "string"
  }
}

Be thorough, realistic, and factor in current 2024 market prices. Include at least 10-15 detailed line items in the breakdown.`
}

async function callGeminiAPI(apiKey: string, prompt: string): Promise<any> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.0-pro:generateContent?key=${apiKey}`

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 8192,
        responseMimeType: 'application/json'
      }
    })
  })

  if (!response.ok) {
    const error = await response.text()
    throw new Error(`Gemini API error: ${error}`)
  }

  const data = await response.json()
  return data.candidates?.[0]?.content?.parts?.[0]?.text
}

function parseGeminiResponse(response: string): any {
  try {
    // Clean up response if needed
    let jsonStr = response
    if (response.includes('```json')) {
      jsonStr = response.split('```json')[1].split('```')[0]
    } else if (response.includes('```')) {
      jsonStr = response.split('```')[1].split('```')[0]
    }

    return JSON.parse(jsonStr.trim())
  } catch (error) {
    console.error('Failed to parse Gemini response:', error)
    throw new Error('Failed to parse AI response')
  }
}
