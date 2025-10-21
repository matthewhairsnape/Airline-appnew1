import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface NotificationRequest {
  token?: string
  tokens?: string[]
  topic?: string
  title: string
  body: string
  data?: Record<string, string>
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
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { token, tokens, topic, title, body, data }: NotificationRequest = await req.json()

    // Validate input
    if (!title || !body) {
      return new Response(
        JSON.stringify({ error: 'Title and body are required' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Get FCM server key from environment
    const fcmServerKey = Deno.env.get('FCM_SERVER_KEY')
    if (!fcmServerKey) {
      return new Response(
        JSON.stringify({ error: 'FCM server key not configured' }),
        { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    let targetTokens: string[] = []

    if (token) {
      // Single token
      targetTokens = [token]
    } else if (tokens && tokens.length > 0) {
      // Multiple tokens
      targetTokens = tokens
    } else if (topic) {
      // Get all tokens for users subscribed to topic
      const { data: userTokens, error } = await supabaseClient
        .from('user_topic_subscriptions')
        .select('fcm_token')
        .eq('topic', topic)
        .not('fcm_token', 'is', null)

      if (error) {
        console.error('Error fetching tokens for topic:', error)
        return new Response(
          JSON.stringify({ error: 'Failed to fetch tokens for topic' }),
          { 
            status: 500, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        )
      }

      targetTokens = userTokens?.map((row: any) => row.fcm_token) || []
    } else {
      return new Response(
        JSON.stringify({ error: 'Either token, tokens, or topic must be provided' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    if (targetTokens.length === 0) {
      return new Response(
        JSON.stringify({ error: 'No valid tokens found' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Send notifications
    const results = await Promise.allSettled(
      targetTokens.map(async (fcmToken) => {
        const message = {
          to: fcmToken,
          notification: {
            title,
            body,
          },
          data: data || {},
          android: {
            priority: 'high',
            notification: {
              sound: 'default',
              priority: 'high',
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
        }

        const response = await fetch('https://fcm.googleapis.com/fcm/send', {
          method: 'POST',
          headers: {
            'Authorization': `key=${fcmServerKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(message),
        })

        if (!response.ok) {
          const errorText = await response.text()
          throw new Error(`FCM API error: ${response.status} - ${errorText}`)
        }

        return await response.json()
      })
    )

    // Count successful and failed notifications
    const successful = results.filter(result => result.status === 'fulfilled').length
    const failed = results.filter(result => result.status === 'rejected').length

    // Log any errors
    results.forEach((result, index) => {
      if (result.status === 'rejected') {
        console.error(`Failed to send notification to token ${index}:`, result.reason)
      }
    })

    return new Response(
      JSON.stringify({
        success: true,
        sent: successful,
        failed,
        total: targetTokens.length,
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Error in send-push-notification function:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
