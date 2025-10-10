import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface FlightPhaseNotificationPayload {
  journeyId: string
  newPhase: string
  previousPhase?: string
  flightData?: Record<string, any>
}

// Map flight phases to notification content
const phaseNotifications = {
  'pre_check_in': {
    title: '✈️ Check-in Available',
    body: 'Check-in is now open for your flight! Get ready for your journey.',
    stage: 'pre_check_in'
  },
  'check_in_open': {
    title: '📋 Check-in Open',
    body: 'Check-in is now available! Don\'t forget to check in for your flight.',
    stage: 'check_in'
  },
  'boarding': {
    title: '🚪 Boarding Started',
    body: 'Your flight is now boarding! Please proceed to the gate.',
    stage: 'boarding'
  },
  'departed': {
    title: '🛫 Flight Departed',
    body: 'Your flight has departed! Have a great journey.',
    stage: 'departed'
  },
  'in_flight': {
    title: '✈️ In Flight',
    body: 'You\'re in the air! How\'s your flight experience so far?',
    stage: 'in_flight'
  },
  'landed': {
    title: '🛬 Flight Landed',
    body: 'Welcome to your destination! How was your flight?',
    stage: 'landed'
  },
  'baggage_claim': {
    title: '🧳 Baggage Claim',
    body: 'Your flight has arrived! Please proceed to baggage claim.',
    stage: 'baggage_claim'
  },
  'completed': {
    title: '✅ Journey Complete',
    body: 'Your journey is complete! Thank you for flying with us.',
    stage: 'completed'
  }
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

    const { journeyId, newPhase, previousPhase, flightData }: FlightPhaseNotificationPayload = await req.json()

    if (!journeyId || !newPhase) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: journeyId, newPhase' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Get journey details with user information
    const { data: journeyData, error: journeyError } = await supabaseAdmin
      .from('journeys')
      .select(`
        *,
        user:users!journeys_user_id_fkey (
          id,
          push_token,
          fcm_token,
          display_name
        ),
        flight:flights!journeys_flight_id_fkey (
          flight_number,
          airline:airlines!flights_airline_id_fkey (
            name,
            iata_code
          ),
          departure_airport:airports!flights_departure_airport_id_fkey (
            iata_code,
            city
          ),
          arrival_airport:airports!flights_arrival_airport_id_fkey (
            iata_code,
            city
          )
        )
      `)
      .eq('id', journeyId)
      .single()

    if (journeyError || !journeyData) {
      console.error('Error fetching journey data:', journeyError)
      return new Response(
        JSON.stringify({ error: 'Journey not found' }),
        { 
          status: 404, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    const user = journeyData.user
    const flight = journeyData.flight

    if (!user) {
      return new Response(
        JSON.stringify({ error: 'User not found for journey' }),
        { 
          status: 404, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    const pushToken = user.push_token || user.fcm_token
    if (!pushToken) {
      return new Response(
        JSON.stringify({ error: 'No push token found for user' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Get notification content for the phase
    const notificationConfig = phaseNotifications[newPhase as keyof typeof phaseNotifications]
    if (!notificationConfig) {
      return new Response(
        JSON.stringify({ error: `Unknown flight phase: ${newPhase}` }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Customize notification with flight details
    let title = notificationConfig.title
    let body = notificationConfig.body

    if (flight) {
      const airlineName = flight.airline?.name || 'Your airline'
      const flightNumber = flight.flight_number || ''
      const departureCity = flight.departure_airport?.city || ''
      const arrivalCity = flight.arrival_airport?.city || ''

      title = `${title} - ${airlineName} ${flightNumber}`
      body = `${body} ${departureCity} → ${arrivalCity}`
    }

    // Prepare notification data
    const notificationData = {
      journeyId,
      stage: notificationConfig.stage,
      phase: newPhase,
      previousPhase,
      timestamp: new Date().toISOString(),
      ...flightData
    }

    // Send push notification via FCM
    const fcmMessage = {
      to: pushToken,
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

    if (fcmResult.failure) {
      console.error('FCM push error:', fcmResult)
      return new Response(
        JSON.stringify({ 
          error: 'Failed to send push notification', 
          details: fcmResult.results?.[0]?.error || 'Unknown FCM error'
        }),
        { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Update journey with new phase
    await supabaseAdmin
      .from('journeys')
      .update({
        current_phase: newPhase,
        updated_at: new Date().toISOString()
      })
      .eq('id', journeyId)

    // Log the phase change event
    await supabaseAdmin
      .from('journey_events')
      .insert({
        journey_id: journeyId,
        event_type: 'phase_change',
        title: 'Flight Phase Changed',
        description: `Phase changed from ${previousPhase || 'unknown'} to ${newPhase}`,
        event_timestamp: new Date().toISOString(),
        metadata: {
          newPhase,
          previousPhase,
          notificationSent: true,
          ...flightData
        }
      })

    console.log(`Flight phase notification sent for journey ${journeyId}: ${newPhase}`)

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Flight phase notification sent successfully',
        phase: newPhase,
        fcmResult 
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Error in flight-phase-notification function:', error)
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
