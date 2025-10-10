import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface PushNotificationPayload {
  userId: string
  title: string
  body: string
  data?: Record<string, any>
  journeyId?: string
  stage?: string
}

interface ExpoPushMessage {
  to: string | string[]
  title: string
  body: string
  data?: Record<string, any>
  sound?: 'default' | null
  badge?: number
  channelId?: string
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Get the service role key for admin operations
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    const { userId, title, body, data, journeyId, stage }: PushNotificationPayload = await req.json()

    if (!userId || !title || !body) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: userId, title, body' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Get user's push token from the database
    const { data: userData, error: userError } = await supabaseAdmin
      .from('users')
      .select('push_token, fcm_token')
      .eq('id', userId)
      .single()

    if (userError || !userData) {
      console.error('Error fetching user data:', userError)
      return new Response(
        JSON.stringify({ error: 'User not found or no push token' }),
        { 
          status: 404, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    const pushToken = userData.push_token || userData.fcm_token
    if (!pushToken) {
      return new Response(
        JSON.stringify({ error: 'No push token found for user' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Prepare notification payload
    const notificationData = {
      ...data,
      journeyId,
      stage,
      timestamp: new Date().toISOString()
    }

    // For now, we'll just log the notification since we don't have FCM set up
    // In production, you would send this via FCM, APNs, or another push service
    console.log('Push notification would be sent:', {
      to: pushToken,
      title,
      body,
      data: notificationData
    })

    // Simulate successful notification
    const notificationResult = {
      success: true,
      messageId: `msg_${Date.now()}`,
      token: pushToken
    }

    // Log the notification in the database
    if (journeyId) {
      await supabaseAdmin
        .from('journey_events')
        .insert({
          journey_id: journeyId,
          event_type: 'push_notification_sent',
          title: 'Push Notification Sent',
          description: `${title}: ${body}`,
          event_timestamp: new Date().toISOString(),
          metadata: notificationData
        })
    }

    console.log('Push notification logged successfully:', notificationResult)

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Push notification logged successfully (simulation mode)',
        result: notificationResult
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Error in send-push-notification function:', error)
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error', 
        details: error.message 
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
