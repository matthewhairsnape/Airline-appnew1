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
  gate?: string
  terminal?: string
  oldGate?: string
  oldTerminal?: string
  notificationType?: string
}

// Helper to create CORS response
function CorsResponse(body: any, status: number = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

// Check if journey is already completed
function checkJourneyCompleted(journey: any): boolean {
  const completedPhases = ['arrived', 'cancelled', 'completed']
  const completedStatuses = ['completed', 'cancelled']
  
  return (
    completedPhases.includes(journey.current_phase) ||
    completedStatuses.includes(journey.status)
  )
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log('✈️ FLIGHT UPDATE NOTIFICATION')
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const request: FlightUpdateRequest = await req.json()
    console.log('📋 Request received:', {
      journeyId: request.journeyId,
      status: request.status,
      phase: request.phase,
      notificationType: request.notificationType,
    })

    // Validate input
    if (!request.journeyId) {
      console.error('❌ Missing journeyId')
      return CorsResponse(
        { error: 'Missing required field: journeyId' },
        400
      )
    }

    // Fetch journey details
    console.log('🔍 Fetching journey:', request.journeyId)
    const { data: journey, error: journeyError } = await supabaseClient
      .from('journeys')
      .select('*')
      .eq('id', request.journeyId)
      .single()

    if (journeyError || !journey) {
      console.error('❌ Journey not found:', journeyError)
      return CorsResponse({ error: 'Journey not found' }, 404)
    }

    console.log('✅ Journey found:', {
      id: journey.id,
      passenger_id: journey.passenger_id,
      status: journey.status,
      current_phase: journey.current_phase,
    })

    // Check if journey is already completed
    if (checkJourneyCompleted(journey)) {
      console.log('⚠️ Journey already completed, skipping notification')
      return CorsResponse({
        success: true,
        message: 'Journey already completed, notification skipped',
        journeyId: request.journeyId,
      })
    }

    // Get user ID from journey (passenger_id)
    const userId = journey.passenger_id || journey.user_id
    if (!userId) {
      console.error('❌ No user ID found in journey')
      return CorsResponse({ error: 'User ID not found in journey' }, 400)
    }

    console.log('👤 User ID:', userId)

    // Fetch user details (including FCM token)
    console.log('🔍 Fetching user details:', userId)
    const { data: user, error: userError } = await supabaseClient
      .from('users')
      .select('id, email, display_name, fcm_token, push_token')
      .eq('id', userId)
      .single()

    if (userError || !user) {
      console.error('❌ User not found:', userError)
      return CorsResponse({ error: 'User not found' }, 404)
    }

    console.log('✅ User found:', {
      id: user.id,
      email: user.email,
      has_fcm_token: !!user.fcm_token,
      has_push_token: !!user.push_token,
    })

    // CRITICAL: Check if user has FCM token
    if (!user.fcm_token) {
      console.warn('⚠️ User has no FCM token, skipping notification')
      return CorsResponse({
        success: true,
        message: 'User has no FCM token, notification skipped',
        journeyId: request.journeyId,
        userId: userId,
      })
    }

    // Determine notification content
    const phase = request.phase || journey.current_phase || ''
    const status = request.status || journey.status || ''
    const notificationType = request.notificationType || 'status_change'

    // Get flight details for better notification content
    let flightInfo: any = null
    if (journey.flight_id) {
      const { data: flight, error: flightError } = await supabaseClient
        .from('flights')
        .select('id, flight_number, carrier_code, gate, terminal, departure_airport_id, arrival_airport_id')
        .eq('id', journey.flight_id)
        .single()
      
      if (!flightError && flight) {
        flightInfo = flight
      } else {
        console.warn('⚠️ Flight not found or error:', flightError)
      }
    }

    // Determine notification title and body
    let title = 'Flight Status Update'
    let body = 'Your flight status has been updated.'

    const carrier = (flightInfo?.carrier_code || '') as string
    const flightNumber = (flightInfo?.flight_number || '') as string
    const flightCode = carrier && flightNumber ? `${carrier}${flightNumber}` : 'Your flight'

    switch (notificationType) {
      case 'delay':
        title = 'Flight Delayed'
        body = `⏰ ${flightCode} has been delayed. Please check for updates.`
        break
      case 'cancellation':
        title = 'Flight Cancelled'
        body = `❌ ${flightCode} has been cancelled. Please contact airline for assistance.`
        break
      case 'boarding':
        title = 'Flight Boarding'
        body = `🛫 ${flightCode} is now boarding! Please proceed to the gate.`
        break
      case 'departure':
        title = 'Flight Departed'
        body = `✈️ ${flightCode} has departed. Enjoy your journey!`
        break
      case 'arrival':
        title = 'Flight Arrived'
        body = `🛬 ${flightCode} has arrived. Welcome to your destination!`
        break
      case 'gate_change':
        const newGate = request.gate || journey.gate || ''
        const oldGateValue = request.oldGate || ''
        if (oldGateValue && newGate) {
          title = 'Gate Changed'
          body = `🚪 Your gate has changed from Gate ${oldGateValue} to Gate ${newGate}. Please proceed to Gate ${newGate}.`
        } else if (newGate) {
          title = 'Gate Assigned'
          body = `🚪 Your gate is Gate ${newGate}. Please proceed to Gate ${newGate}.`
        } else {
          title = 'Gate Update'
          body = `🚪 Gate information for ${flightCode} has been updated.`
        }
        break
      case 'terminal_change':
        const newTerminal = request.terminal || journey.terminal || ''
        const oldTerminalValue = request.oldTerminal || ''
        if (oldTerminalValue && newTerminal) {
          title = 'Terminal Changed'
          body = `🏢 Your terminal has changed from Terminal ${oldTerminalValue} to Terminal ${newTerminal}. Please proceed to Terminal ${newTerminal}.`
        } else if (newTerminal) {
          title = 'Terminal Assigned'
          body = `🏢 Your terminal is Terminal ${newTerminal}. Please proceed to Terminal ${newTerminal}.`
        } else {
          title = 'Terminal Update'
          body = `🏢 Terminal information for ${flightCode} has been updated.`
        }
        break
      default:
        // Phase-based notifications
        switch (phase) {
          case 'pre_check_in':
            title = 'Check-in Available'
            body = `📱 Check-in is now available for ${flightCode}.`
            break
          case 'boarding':
            title = 'Flight Boarding'
            body = `🛫 ${flightCode} is now boarding! Please proceed to the gate.`
            break
          case 'gate_closed':
            title = 'Gate Closed'
            body = `⚠️ Gate is now closed for ${flightCode}. Please contact airline staff.`
            break
          case 'departed':
          case 'in_flight':
            title = 'Flight Departed'
            body = `✈️ ${flightCode} has departed. Enjoy your journey!`
            break
          case 'landed':
            title = 'Flight Landed'
            body = `🛬 ${flightCode} has landed.`
            break
          case 'arrived':
            title = 'Flight Arrived'
            body = `✅ ${flightCode} has arrived. Thank you for flying with us!`
            break
          case 'cancelled':
            title = 'Flight Cancelled'
            body = `❌ ${flightCode} has been cancelled. Please contact airline for assistance.`
            break
          default:
            title = 'Flight Status Update'
            body = `📱 ${flightCode} status has been updated to ${phase || status}.`
        }
    }

    console.log('📝 Notification content:', { title, body })

    // Prepare notification data - FCM requires all data values to be strings
    const notificationData: Record<string, string> = {
      type: notificationType || 'status_change',
      journey_id: request.journeyId,
      phase: phase || '',
      status: status || '',
      timestamp: new Date().toISOString(),
      // CRITICAL: Include click_action for Android and category for iOS interaction
      click_action: 'FLIGHT_STATUS_UPDATE',
      // Include gate and terminal info if available
      gate: (request.gate || journey.gate || '').toString(),
      terminal: (request.terminal || journey.terminal || '').toString(),
    }

    // Invoke send-push-notification function
    console.log('📤 Invoking send-push-notification function...')
    console.log('📋 Request payload:', {
      userId,
      title,
      body,
      dataKeys: Object.keys(notificationData),
    })

    try {
      const notificationResponse = await fetch(
        `${Deno.env.get('SUPABASE_URL')}/functions/v1/send-push-notification`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
            'apikey': Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '',
          },
          body: JSON.stringify({
            userId: userId,
            title: title,
            body: body,
            data: notificationData,
          }),
        }
      )

      const responseText = await notificationResponse.text()
      console.log('📥 Notification response status:', notificationResponse.status)
      console.log('📥 Notification response body:', responseText)

      let notificationResult
      try {
        notificationResult = JSON.parse(responseText)
      } catch (parseError) {
        console.error('❌ Failed to parse response as JSON:', parseError)
        console.error('Raw response:', responseText)
        return CorsResponse(
          {
            success: false,
            error: 'Invalid response from send-push-notification',
            details: responseText,
          },
          500
        )
      }

      console.log('📥 Notification result:', notificationResult)

      if (!notificationResponse.ok) {
        console.error('❌ Failed to send notification:', notificationResult)
        return CorsResponse(
          {
            success: false,
            error: 'Failed to send notification',
            details: notificationResult,
          },
          notificationResponse.status || 500
        )
      }

      // Check if notification was actually sent
      if (notificationResult.success === false || notificationResult.error) {
        console.error('❌ Notification service returned error:', notificationResult)
        return CorsResponse(
          {
            success: false,
            error: notificationResult.error || 'Notification service returned error',
            details: notificationResult,
          },
          500
        )
      }

      // Verify notification was sent (check sent count)
      if (notificationResult.success === true && notificationResult.sent > 0) {
        console.log('✅ Notification sent successfully:', {
          sent: notificationResult.sent || 0,
          failed: notificationResult.failed || 0,
        })
      } else if (notificationResult.success === true && notificationResult.sent === 0) {
        console.warn('⚠️ Notification service returned success but no notifications were sent:', notificationResult)
        return CorsResponse(
          {
            success: false,
            error: 'No notifications were sent',
            details: notificationResult,
          },
          500
        )
      } else {
        // If success field is missing, assume it worked if we got 200 OK
        console.log('✅ Notification response received (assuming success):', notificationResult)
      }
    } catch (fetchError) {
      console.error('❌ Error calling send-push-notification:', fetchError)
      return CorsResponse(
        {
          success: false,
          error: 'Failed to invoke send-push-notification function',
          details: fetchError.message || String(fetchError),
        },
        500
      )
    }

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log('✅ SUCCESS')
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')

    return CorsResponse({
      success: true,
      journeyId: request.journeyId,
      userId: userId,
      notificationSent: true,
      message: 'Notification sent successfully',
    })
  } catch (error) {
    console.error('❌ Error in flight-update-notification:', error)
    return CorsResponse(
      {
        error: 'Internal server error',
        details: error.message,
      },
      500
    )
  }
})

