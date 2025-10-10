import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface BatchNotificationPayload {
  userIds: string[]
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

    const { userIds, title, body, data, journeyId, stage }: BatchNotificationPayload = await req.json()

    if (!userIds || !Array.isArray(userIds) || userIds.length === 0 || !title || !body) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: userIds (array), title, body' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Get users' push tokens from the database
    const { data: usersData, error: usersError } = await supabaseAdmin
      .from('users')
      .select('id, push_token, fcm_token')
      .in('id', userIds)

    if (usersError) {
      console.error('Error fetching users data:', usersError)
      return new Response(
        JSON.stringify({ error: 'Failed to fetch users data' }),
        { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Filter users with valid push tokens
    const validTokens = usersData
      .filter(user => user.push_token || user.fcm_token)
      .map(user => user.push_token || user.fcm_token)

    if (validTokens.length === 0) {
      return new Response(
        JSON.stringify({ error: 'No valid push tokens found for any user' }),
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

    // Send push notifications via FCM (batch send)
    const fcmMessage = {
      registration_ids: validTokens,
      notification: {
        title: title,
        body: body,
        sound: 'default'
      },
      data: notificationData,
      android: {
        priority: 'high',
        notification: {
          channel_id: 'flight-tracking',
          sound: 'default'
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1
          }
        }
      }
    }

    const fcmResponse = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Authorization': `key=${Deno.env.get('FCM_SERVER_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(fcmMessage)
    })

    const fcmResult = await fcmResponse.json()

    // Count successful and failed notifications
    let successCount = 0
    let errorCount = 0
    const errors: string[] = []

    if (fcmResult.results) {
      fcmResult.results.forEach((result: any, index: number) => {
        if (result.message_id) {
          successCount++
        } else {
          errorCount++
          errors.push(`Token ${index}: ${result.error || 'Unknown error'}`)
        }
      })
    }

    // Log the batch notification in the database
    if (journeyId) {
      await supabaseAdmin
        .from('journey_events')
        .insert({
          journey_id: journeyId,
          event_type: 'batch_push_notification_sent',
          title: 'Batch Push Notification Sent',
          description: `${title}: ${body} (${successCount} sent, ${errorCount} failed)`,
          event_timestamp: new Date().toISOString(),
          metadata: {
            ...notificationData,
            totalUsers: userIds.length,
            successCount,
            errorCount,
            errors: errors.length > 0 ? errors : undefined
          }
        })
    }

    console.log(`Batch push notification sent: ${successCount} successful, ${errorCount} failed`)

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: `Batch push notification sent: ${successCount} successful, ${errorCount} failed`,
        results: {
          totalUsers: userIds.length,
          successCount,
          errorCount,
          errors: errors.length > 0 ? errors : undefined
        },
        fcmResult 
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Error in send-batch-notifications function:', error)
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
