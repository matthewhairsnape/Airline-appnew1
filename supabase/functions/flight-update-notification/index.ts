import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface FlightUpdateRequest {
  journeyId: string
  status?: string
  phase?: string
  notificationType?: string
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('📥 Flight update notification request received')
    console.log('📋 Request method:', req.method)
    
    // Initialize Supabase client with service role
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

    const { journeyId, status, phase, notificationType }: FlightUpdateRequest = await req.json()
    
    console.log('📋 Request data:', { journeyId, status, phase, notificationType })

    // Validate input
    if (!journeyId) {
      console.error('❌ Missing journeyId')
      return new Response(
        JSON.stringify({ error: 'journeyId is required' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Get journey details
    const { data: journey, error: journeyError } = await supabaseAdmin
      .from('journeys')
      .select('*')
      .eq('id', journeyId)
      .single()
    
    if (journeyError || !journey) {
      console.error('❌ Error fetching journey:', journeyError)
      return new Response(
        JSON.stringify({ error: 'Journey not found', details: journeyError?.message }),
        { 
          status: 404, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    console.log('✅ Journey found:', journeyId)
    console.log('📋 Journey data:', {
      id: journey.id,
      passenger_id: journey.passenger_id,
      user_id: journey.user_id,
      flight_id: journey.flight_id
    })

    // Check if journey is already completed
    const isCompleted = await checkJourneyCompleted(supabaseAdmin, journeyId)
    if (isCompleted) {
      console.log('ℹ️ Journey is already completed, skipping notification')
      return CorsResponse({
        success: true,
        message: 'Journey is already completed, notification skipped',
        journeyId,
        isCompleted: true,
        notificationSent: false
      }, 200)
    }

    // Get user ID from journey (using passenger_id based on your schema)
    const userId = journey.passenger_id || journey.user_id
    if (!userId) {
      console.error('❌ No passenger_id or user_id found in journey')
      console.error('Journey keys:', Object.keys(journey))
      return new Response(
        JSON.stringify({ error: 'Journey has no associated user' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    console.log('👤 User ID:', userId)

    // Get user's FCM token
    const { data: user, error: userError } = await supabaseAdmin
      .from('users')
      .select('id, fcm_token, push_token')
      .eq('id', userId)
      .single()
    
    if (userError || !user) {
      console.error('❌ Error fetching user:', userError)
      return new Response(
        JSON.stringify({ error: 'User not found', details: userError?.message }),
        { 
          status: 404, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    console.log('✅ User found')
    console.log('📋 User data:', {
      id: user.id,
      hasFcmToken: !!user.fcm_token,
      hasPushToken: !!user.push_token,
      fcmTokenPreview: user.fcm_token ? user.fcm_token.substring(0, 20) + '...' : null
    })

    // Skip journey update - only send notification
    console.log('ℹ️ Skipping journey update - sending notification only')

    // Get user's FCM token
    const fcmToken = user?.fcm_token || user?.push_token

    if (!fcmToken) {
      console.error('❌ No FCM token found for user:', userId)
      
      // Log event but don't fail the request
      try {
        await supabaseAdmin.from('journey_events').insert({
          journey_id: journeyId,
          event_type: 'notification_failed',
          title: 'Notification Failed',
          description: 'No FCM token found for user',
          event_timestamp: new Date().toISOString(),
          metadata: { phase, status, notificationType }
        })
      } catch (e) {
        console.error('Error logging event:', e)
      }

      return new Response(
        JSON.stringify({ 
          success: true,
          message: 'Journey updated but notification not sent - no FCM token found',
          userId,
          notificationSent: false
        }),
        { 
          status: 200, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    console.log('📱 FCM Token found:', fcmToken.substring(0, 20) + '...')

    // Get flight details for better notification
    let flightInfo = ''
    if (journey.flight_id) {
      const { data: flight, error: flightError } = await supabaseAdmin
        .from('flights')
        .select('flight_number, carrier_code')
        .eq('id', journey.flight_id)
        .single()

      if (!flightError && flight) {
        flightInfo = `${flight.carrier_code || ''}${flight.flight_number || ''}`.trim()
        console.log('✈️ Flight info:', flightInfo)
      }
    }

    // Determine notification content
    const { title, body } = getNotificationContent(notificationType || phase, flightInfo)

    console.log('📤 Preparing notification:', { title, body })
    console.log('📤 Invoking send-push-notification with:', {
      userId: userId,
      title: title,
      body: body,
      journeyId: journeyId
    })

    // Send notification via send-push-notification function
    try {
      const invokeResponse = await supabaseAdmin.functions.invoke(
        'send-push-notification',
        {
          body: {
            userId: userId,
            title: title,
            body: body,
            journeyId: journeyId,
            data: {
              type: notificationType || 'flight_status_update',
              phase: phase || '',
              status: status || '',
              timestamp: new Date().toISOString(),
            },
          },
        }
      )

      console.log('📥 send-push-notification response:', JSON.stringify(invokeResponse))
      
      const notificationResult = invokeResponse.data
      const notificationError = invokeResponse.error

      if (notificationError) {
        console.error('❌ Error in notification response:', notificationError)
        
        // Log failed notification event
        try {
          await supabaseAdmin.from('journey_events').insert({
            journey_id: journeyId,
            event_type: 'notification_failed',
            title: 'Notification Failed',
            description: `Failed to send notification: ${typeof notificationError === 'string' ? notificationError : JSON.stringify(notificationError)}`,
            event_timestamp: new Date().toISOString(),
            metadata: { phase, status, notificationType, error: notificationError }
          })
        } catch (e) {
          console.error('Error logging failed event:', e)
        }

        return new Response(
          JSON.stringify({ 
            success: false,
            message: 'Journey updated but notification failed to send',
            error: typeof notificationError === 'string' ? notificationError : JSON.stringify(notificationError),
            notificationSent: false,
            debug: {
              userId,
              journeyId,
              fcmTokenPreview: fcmToken ? fcmToken.substring(0, 20) + '...' : null
            }
          }),
          { 
            status: 500, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        )
      }

      console.log('✅ Notification sent successfully:', notificationResult)

      // Log successful notification event
      try {
        await supabaseAdmin.from('journey_events').insert({
          journey_id: journeyId,
          event_type: 'notification_sent',
          title: 'Push Notification Sent',
          description: `${title}: ${body}`,
          event_timestamp: new Date().toISOString(),
          metadata: { phase, status, notificationType, notificationResult }
        })
      } catch (e) {
        console.error('Error logging success event:', e)
      }

      return new Response(
        JSON.stringify({
          success: true,
          message: 'Flight status updated and notification sent successfully',
          journeyId,
          userId,
          phase,
          status,
          notificationType,
          notificationSent: true,
          notificationResult: notificationResult
        }),
        { 
          status: 200, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    } catch (invokeError) {
      console.error('❌ Exception invoking send-push-notification:', invokeError)
      console.error('Error details:', {
        message: invokeError.message,
        stack: invokeError.stack,
        name: invokeError.name
      })

      return new Response(
        JSON.stringify({ 
          success: false,
          message: 'Error invoking notification function',
          error: invokeError.message,
          notificationSent: false,
          debug: {
            userId,
            journeyId,
            hasFcmToken: !!fcmToken
          }
        }),
        { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

  } catch (error) {
    console.error('❌ Error in flight-update-notification function:', error)
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

// Helper function to check if journey is completed
async function checkJourneyCompleted(
  supabaseAdmin: any,
  journeyId: string
): Promise<boolean> {
  try {
    // First, check journey table fields
    const { data: journey, error: journeyError } = await supabaseAdmin
      .from('journeys')
      .select('current_phase, visit_status, status')
      .eq('id', journeyId)
      .single()

    if (!journeyError && journey) {
      const phase = journey.current_phase?.toLowerCase()
      const visitStatus = journey.visit_status
      const status = journey.status?.toLowerCase()

      // Journey is completed ONLY if visit_status is 'Completed' or status is 'completed'
      // NOTE: 'landed' phase does NOT mean completed - user must explicitly complete
      if (visitStatus === 'Completed' || status === 'completed') {
        console.log('✅ Journey completion detected via table fields')
        return true
      }
    }

    // Fallback: Check journey events for completion event
    // This handles cases where table update failed but event was created
    try {
      const { data: completionEvent, error: eventError } = await supabaseAdmin
        .from('journey_events')
        .select('id')
        .eq('journey_id', journeyId)
        .eq('event_type', 'journey_completed')
        .limit(1)
        .maybeSingle()

      if (!eventError && completionEvent) {
        console.log('✅ Journey completion detected via event')
        return true
      }
    } catch (eventError) {
      console.error('⚠️ Error checking journey events:', eventError)
    }

    return false
  } catch (error) {
    console.error('❌ Error checking journey completion status:', error)
    return false
  }
}

// Helper function to create CORS response
function CorsResponse(data: any, status: number = 200) {
  return new Response(
    JSON.stringify(data),
    {
      status,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    }
  )
}

// Helper function to get notification content
function getNotificationContent(notificationType: string | undefined, flightInfo: string): { title: string; body: string } {
  const flightText = flightInfo ? `Flight ${flightInfo}` : 'Your flight'
  
  switch (notificationType) {
    case 'boarding':
    case 'pre_check_in':
      return {
        title: '✈️ Boarding Started',
        body: `${flightText} is now boarding! Please proceed to the gate.`
      }
    case 'departed':
    case 'in_flight':
      return {
        title: '✈️ Flight Departed',
        body: `${flightText} has departed. Enjoy your journey!`
      }
    case 'landed':
    case 'arrived':
      return {
        title: '🛬 Flight Landed',
        body: `${flightText} has landed. Welcome to your destination!`
      }
    case 'gate_change':
      return {
        title: '🚪 Gate Change',
        body: `${flightText} gate has changed. Please check the new gate information.`
      }
    case 'delay':
      return {
        title: '⏰ Flight Delayed',
        body: `${flightText} has been delayed. Please check for updates.`
      }
    case 'cancelled':
      return {
        title: '❌ Flight Cancelled',
        body: `${flightText} has been cancelled. Please contact airline for assistance.`
      }
    default:
      return {
        title: '📱 Flight Status Update',
        body: `${flightText} status has been updated.`
      }
  }
}
