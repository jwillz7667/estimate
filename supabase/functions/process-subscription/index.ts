// BUILD PEEK - Process Subscription Edge Function
// Handles App Store receipt validation and subscription status updates

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface SubscriptionRequest {
  receipt: string
  productId: string
  transactionId: string
  originalTransactionId?: string
  environment?: 'sandbox' | 'production'
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
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Get user
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

    // Parse request body
    const body: SubscriptionRequest = await req.json()

    // Determine tier from product ID
    const tierMap: Record<string, string> = {
      'com.projectestimate.pro.monthly': 'professional',
      'com.projectestimate.pro.annual': 'professional',
      'com.projectestimate.enterprise.monthly': 'enterprise',
      'com.projectestimate.enterprise.annual': 'enterprise',
    }

    const tier = tierMap[body.productId] || 'free'

    // Calculate expiration date based on product
    const now = new Date()
    let expiresAt: Date

    if (body.productId.includes('.annual')) {
      expiresAt = new Date(now.setFullYear(now.getFullYear() + 1))
    } else {
      expiresAt = new Date(now.setMonth(now.getMonth() + 1))
    }

    // Validate receipt with Apple (in production)
    // For now, we trust the client-side StoreKit validation
    // TODO: Implement server-side receipt validation for production
    const isValidReceipt = true // await validateAppleReceipt(body.receipt, body.environment)

    if (!isValidReceipt) {
      return new Response(
        JSON.stringify({ error: 'Invalid receipt' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Update user profile with new subscription
    const { error: updateError } = await supabase
      .from('profiles')
      .update({
        subscription_tier: tier,
        subscription_expires_at: expiresAt.toISOString(),
        subscription_product_id: body.productId,
        updated_at: new Date().toISOString()
      })
      .eq('id', user.id)

    if (updateError) {
      console.error('Error updating profile:', updateError)
      return new Response(
        JSON.stringify({ error: 'Failed to update subscription' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Record subscription history
    const { error: historyError } = await supabase
      .from('subscription_history')
      .insert({
        user_id: user.id,
        product_id: body.productId,
        tier: tier,
        transaction_id: body.transactionId,
        original_transaction_id: body.originalTransactionId,
        purchase_date: new Date().toISOString(),
        expiration_date: expiresAt.toISOString(),
        is_trial: false,
        is_renewal: !!body.originalTransactionId,
        environment: body.environment || 'production'
      })

    if (historyError) {
      console.error('Error recording subscription history:', historyError)
      // Don't fail the request, subscription was still updated
    }

    // Log API usage
    await supabase.rpc('log_api_usage', {
      p_user_id: user.id,
      p_endpoint: 'process-subscription',
      p_request_type: 'subscription-update',
      p_tokens_used: 0,
      p_cost_cents: 0,
      p_duration_ms: 0,
      p_status_code: 200
    })

    return new Response(
      JSON.stringify({
        success: true,
        tier,
        expiresAt: expiresAt.toISOString()
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

// TODO: Implement Apple receipt validation
// async function validateAppleReceipt(receipt: string, environment?: string): Promise<boolean> {
//   const url = environment === 'sandbox'
//     ? 'https://sandbox.itunes.apple.com/verifyReceipt'
//     : 'https://buy.itunes.apple.com/verifyReceipt'
//
//   const response = await fetch(url, {
//     method: 'POST',
//     headers: { 'Content-Type': 'application/json' },
//     body: JSON.stringify({
//       'receipt-data': receipt,
//       'password': Deno.env.get('APPLE_SHARED_SECRET')
//     })
//   })
//
//   const data = await response.json()
//   return data.status === 0
// }
