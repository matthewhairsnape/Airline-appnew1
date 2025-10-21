import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface FlightStatusUpdate {
  journeyId: string
  carrier: string
  flightNumber: string
  status: string
  phase: string
  flightData: Record<string, any>
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

    const { journeyId, carrier, flightNumber, status, phase, flightData }: FlightStatusUpdate = await req.json()

    // Validate input
    if (!journeyId || !carrier || !flightNumber || !status || !phase) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Get journey details
    const { data: journey, error: journeyError } = await supabaseClient
      .from('journeys')
      .select(`
        *,
        user:users(*),
        flight:flights(*)
      `)
      .eq('id', journeyId)
      .single()

    if (journeyError || !journey) {
      console.error('Error fetching journey:', journeyError)
      return new Response(
        JSON.stringify({ error: 'Journey not found' }),
        { 
          status: 404, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Update journey status
    const { error: updateError } = await supabaseClient
      .from('journeys')
      .update({
        current_phase: phase,
        status: mapPhaseToStatus(phase),
        updated_at: new Date().toISOString(),
      })
      .eq('id', journeyId)

    if (updateError) {
      console.error('Error updating journey:', updateError)
      return new Response(
        JSON.stringify({ error: 'Failed to update journey' }),
        { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Add journey event
    const { error: eventError } = await supabaseClient
      .from('journey_events')
      .insert({
        journey_id: journeyId,
        event_type: 'status_change',
        title: getEventTitle(phase),
        description: getEventDescription(phase, flightData),
        event_timestamp: new Date().toISOString(),
        metadata: flightData,
      })

    if (eventError) {
      console.error('Error creating journey event:', eventError)
      // Don't fail the entire request for this
    }

    // Send push notification if user has FCM token
    if (journey.user?.fcm_token) {
      try {
        const message = getNotificationMessage(phase, flightData)
        
        // Call the send-push-notification function
        const { error: notificationError } = await supabaseClient.functions.invoke(
          'send-push-notification',
          {
            body: {
              token: journey.user.fcm_token,
              title: 'Flight Status Update',
              body: message,
              data: {
                type: 'flight_status_update',
                phase: phase,
                journey_id: journeyId,
                flight_data: JSON.stringify(flightData),
              },
            },
          }
        )

        if (notificationError) {
          console.error('Error sending push notification:', notificationError)
        }
      } catch (error) {
        console.error('Error in push notification flow:', error)
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        journeyId,
        phase,
        status,
        message: 'Flight status updated successfully',
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Error in process-flight-status function:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})

// Helper functions
function mapPhaseToStatus(phase: string): string {
  switch (phase) {
    case 'pre_check_in':
    case 'boarding':
    case 'gate_closed':
      return 'scheduled'
    case 'departed':
    case 'in_flight':
    case 'landing':
      return 'in_progress'
    case 'landed':
    case 'arrived':
      return 'completed'
    case 'cancelled':
      return 'cancelled'
    case 'diverted':
      return 'diverted'
    default:
      return 'unknown'
  }
}

function getEventTitle(phase: string): string {
  switch (phase) {
    case 'boarding':
      return 'Flight Boarding'
    case 'gate_closed':
      return 'Gate Closed'
    case 'departed':
      return 'Flight Departed'
    case 'in_flight':
      return 'In Flight'
    case 'landed':
      return 'Flight Landed'
    case 'arrived':
      return 'Flight Arrived'
    case 'cancelled':
      return 'Flight Cancelled'
    case 'delayed':
      return 'Flight Delayed'
    default:
      return 'Status Update'
  }
}

function getEventDescription(phase: string, flightData: Record<string, any>): string {
  const carrier = flightData.carrier || ''
  const flightNumber = flightData.flightNumber || ''
  const flight = `${carrier}${flightNumber}`
  
  switch (phase) {
    case 'boarding':
      return `Flight ${flight} is now boarding. Please proceed to the gate.`
    case 'gate_closed':
      return `Gate is now closed for flight ${flight}. Please contact airline staff.`
    case 'departed':
      return `Flight ${flight} has departed. Enjoy your journey!`
    case 'in_flight':
      return `Flight ${flight} is in progress.`
    case 'landed':
      return `Flight ${flight} has landed.`
    case 'arrived':
      return `Flight ${flight} has arrived. Welcome to your destination!`
    case 'cancelled':
      return `Flight ${flight} has been cancelled. Please contact airline for assistance.`
    case 'delayed':
      return `Flight ${flight} has been delayed. Please check for updates.`
    default:
      return `Flight ${flight} status has been updated.`
  }
}

function getNotificationMessage(phase: string, flightData: Record<string, any>): string {
  const carrier = flightData.carrier || ''
  const flightNumber = flightData.flightNumber || ''
  const flight = `${carrier}${flightNumber}`
  
  switch (phase) {
    case 'boarding':
      return `🛫 Your flight ${flight} is now boarding! Please proceed to the gate.`
    case 'gate_closed':
      return `⚠️ Gate is now closed for flight ${flight}. Please contact airline staff.`
    case 'departed':
    case 'in_flight':
      return `✈️ Flight ${flight} has departed. Enjoy your journey!`
    case 'landed':
      return `🛬 Flight ${flight} has landed. Welcome to your destination!`
    case 'arrived':
      return `✅ Flight ${flight} has arrived. Thank you for flying with us!`
    case 'cancelled':
      return `❌ Flight ${flight} has been cancelled. Please contact airline for assistance.`
    case 'delayed':
      return `⏰ Flight ${flight} has been delayed. Please check for updates.`
    default:
      return `📱 Flight ${flight} status update available.`
  }
}
