import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Configuration
const CIRIUM_BASE_URL = 'https://api.flightstats.com/flex'
const CIRIUM_APP_ID = Deno.env.get('CIRIUM_APP_ID') || '7f155a19'
const CIRIUM_APP_KEY = Deno.env.get('CIRIUM_APP_KEY') || '6c5f44eeeb23a68f311a6321a96fcbdf'
const MAX_JOURNEYS_PER_RUN = 100
const MAX_CONCURRENT_REQUESTS = 5 // Process 5 journeys in parallel
const API_REQUEST_DELAY = 200 // ms between API calls
const REQUEST_TIMEOUT = 10000 // 10 seconds timeout
const MAX_RETRIES = 2

// Types
interface FlightData {
  carrier: string
  flightNumber: string
  status: string
  departureAirport: string
  arrivalAirport: string
  gate: string
  terminal: string
  scheduledDeparture: string
  scheduledArrival: string
  actualDeparture: string
  actualArrival: string
  departureDelay: number
  arrivalDelay: number
}

interface JourneyResult {
  journeyId: string
  status: 'updated' | 'no_change' | 'error' | 'skipped'
  phase?: string
  status_new?: string
  gate?: string
  terminal?: string
  error?: string
}

// Map Cirium status to our phase system
function mapCiriumStatusToPhase(status: string | null | undefined): string {
  if (!status) {
    console.log('⚠️ No status provided, returning unknown')
    return 'unknown'
  }
  
  const statusLower = status.toLowerCase().trim()
  console.log(`🔍 Mapping Cirium status: "${status}" (lowercase: "${statusLower}")`)
  
  // Scheduled/On-time statuses
  if (statusLower.includes('scheduled') || 
      statusLower.includes('ontime') || 
      statusLower.includes('on-time') ||
      statusLower === 's' ||
      statusLower === 'ontime') {
    return 'pre_check_in'
  }
  
  // Boarding statuses
  if (statusLower.includes('boarding') || 
      statusLower.includes('gate') ||
      statusLower === 'b' ||
      statusLower === 'boarding') {
    return 'boarding'
  }
  
  // Departure/In-flight statuses
  if (statusLower.includes('departed') || 
      statusLower.includes('inflight') ||
      statusLower.includes('in-flight') ||
      statusLower.includes('in flight') ||
      statusLower === 'd' ||
      statusLower === 'departed' ||
      statusLower === 'inflight') {
    return 'departed'
  }
  
  // Landing statuses
  if (statusLower.includes('landed') || 
      statusLower.includes('landing') ||
      statusLower === 'l' ||
      statusLower === 'landed') {
    return 'landed'
  }
  
  // Arrival statuses
  if (statusLower.includes('arrived') || 
      statusLower.includes('arrival') ||
      statusLower === 'a' ||
      statusLower === 'arrived') {
    return 'arrived'
  }
  
  // Cancellation statuses
  if (statusLower.includes('cancelled') || 
      statusLower.includes('canceled') ||
      statusLower.includes('cancel') ||
      statusLower === 'c' ||
      statusLower === 'cancelled' ||
      statusLower === 'canceled') {
    return 'cancelled'
  }
  
  // Diverted statuses
  if (statusLower.includes('diverted') || 
      statusLower.includes('divert') ||
      statusLower === 'diverted') {
    return 'diverted'
  }
  
  // Delayed statuses
  if (statusLower.includes('delayed') || 
      statusLower.includes('delay')) {
    return 'pre_check_in' // Keep in pre-check-in phase but notify about delay
  }
  
  console.log(`⚠️ Unknown Cirium status: "${status}" - returning unknown`)
  return 'unknown'
}

// Map phase to status
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

// Fetch flight status from Cirium API with retry logic and timeout
async function fetchFlightStatus(
  carrier: string,
  flightNumber: string,
  departureDate: Date,
  retryCount = 0
): Promise<any> {
  try {
    const year = departureDate.getFullYear()
    const month = String(departureDate.getMonth() + 1).padStart(2, '0')
    const day = String(departureDate.getDate()).padStart(2, '0')
    
    const isHistorical = (Date.now() - departureDate.getTime()) > 24 * 60 * 60 * 1000
    
    const url = isHistorical
      ? `${CIRIUM_BASE_URL}/flightstatus/historical/rest/v3/json/flight/status/${carrier}/${flightNumber}/dep/${year}/${month}/${day}?appId=${CIRIUM_APP_ID}&appKey=${CIRIUM_APP_KEY}&extendedOptions=useHttpErrors`
      : `${CIRIUM_BASE_URL}/flightstatus/rest/v2/json/flight/status/${carrier}/${flightNumber}/dep/${year}/${month}/${day}?appId=${CIRIUM_APP_ID}&appKey=${CIRIUM_APP_KEY}&utc=true`
    
    // Create abort controller for timeout
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), REQUEST_TIMEOUT)
    
    try {
      const response = await fetch(url, {
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        signal: controller.signal,
      })
      
      clearTimeout(timeoutId)
      
      if (!response.ok) {
        const errorText = await response.text()
        // Retry on 5xx errors or rate limit (429)
        if ((response.status >= 500 || response.status === 429) && retryCount < MAX_RETRIES) {
          console.log(`⚠️ Retrying ${carrier}${flightNumber} (attempt ${retryCount + 1}/${MAX_RETRIES})...`)
          await new Promise(resolve => setTimeout(resolve, 1000 * (retryCount + 1))) // Exponential backoff
          return fetchFlightStatus(carrier, flightNumber, departureDate, retryCount + 1)
        }
        console.error(`❌ Cirium API error: ${response.status} - ${errorText.substring(0, 200)}`)
        return null
      }
      
      const data = await response.json()
      return data
    } catch (fetchError: any) {
      clearTimeout(timeoutId)
      if (fetchError.name === 'AbortError') {
        console.error(`⏱️ Timeout fetching ${carrier}${flightNumber}`)
      } else if (retryCount < MAX_RETRIES) {
        console.log(`⚠️ Retrying ${carrier}${flightNumber} after error (attempt ${retryCount + 1}/${MAX_RETRIES})...`)
        await new Promise(resolve => setTimeout(resolve, 1000 * (retryCount + 1)))
        return fetchFlightStatus(carrier, flightNumber, departureDate, retryCount + 1)
      }
      throw fetchError
    }
  } catch (error) {
    console.error(`❌ Error fetching from Cirium ${carrier}${flightNumber}: ${error}`)
    return null
  }
}

// Parse Cirium flight status with validation
function parseFlightStatus(ciriumData: any): FlightData | null {
  try {
    const flightStatuses = ciriumData?.flightStatuses
    if (!flightStatuses || !Array.isArray(flightStatuses) || flightStatuses.length === 0) {
      return null
    }
    
    const status = flightStatuses[0]
    const flight = status?.flight || {}
    const departureDate = status?.departureDate || {}
    const arrivalDate = status?.arrivalDate || {}
    const airportResources = status?.airportResources || {}
    const depResources = airportResources?.departure || {}
    
    return {
      carrier: flight.carrierFsCode || '',
      flightNumber: flight.flightNumber || '',
      status: status.status || '',
      departureAirport: status.departureAirportFsCode || '',
      arrivalAirport: status.arrivalAirportFsCode || '',
      gate: depResources.gate || departureDate.gate || '',
      terminal: depResources.terminal || departureDate.terminal || '',
      scheduledDeparture: departureDate.dateLocal || '',
      scheduledArrival: arrivalDate.dateLocal || '',
      actualDeparture: departureDate.dateUtc || '',
      actualArrival: arrivalDate.dateUtc || '',
      departureDelay: departureDate.delayMinutes || 0,
      arrivalDelay: arrivalDate.delayMinutes || 0,
    }
  } catch (error) {
    console.error(`❌ Error parsing Cirium data: ${error}`)
    return null
  }
}

// Process journeys in batches with concurrency control
async function processBatch<T>(
  items: T[],
  processor: (item: T) => Promise<any>,
  concurrency: number
): Promise<any[]> {
  const results: any[] = []
  
  for (let i = 0; i < items.length; i += concurrency) {
    const batch = items.slice(i, i + concurrency)
    const batchResults = await Promise.allSettled(
      batch.map(item => processor(item))
    )
    
    results.push(...batchResults.map(result => 
      result.status === 'fulfilled' ? result.value : { error: result.reason }
    ))
    
    // Delay between batches to avoid rate limiting
    if (i + concurrency < items.length) {
      await new Promise(resolve => setTimeout(resolve, API_REQUEST_DELAY))
    }
  }
  
  return results
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log('✈️ CHECKING FLIGHT STATUSES (CRON JOB)')
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Find active journeys with optimized query
    const now = new Date()
    const twoDaysAgo = new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000)
    const twoDaysAhead = new Date(now.getTime() + 2 * 24 * 60 * 60 * 1000)

    console.log(`🔍 Finding active journeys...`)

    const { data: journeys, error: journeysError } = await supabaseClient
      .from('journeys')
      .select(`
        id,
        passenger_id,
        flight_id,
        status,
        current_phase,
        gate,
        terminal,
        updated_at,
        flight:flights (
          id,
          carrier_code,
          flight_number,
          scheduled_departure,
          departure_airport_id,
          airports_departure:departure_airport_id (
            iata_code
          )
        )
      `)
      .in('status', ['active', 'scheduled', 'in_progress'])
      .not('current_phase', 'in', '(arrived,cancelled,completed)')
      .order('updated_at', { ascending: false }) // Check recently updated ones first
      .limit(MAX_JOURNEYS_PER_RUN)

    if (journeysError) {
      console.error('❌ Error fetching journeys:', journeysError)
      return new Response(
        JSON.stringify({ error: 'Failed to fetch journeys', details: journeysError }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!journeys || journeys.length === 0) {
      console.log('✅ No active journeys found')
      return new Response(
        JSON.stringify({ success: true, message: 'No active journeys found', updated: 0 }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`📋 Found ${journeys.length} active journeys to check`)

    // Filter out journeys without valid flight info
    const validJourneys = journeys.filter(j => {
      const flight = j.flight as any
      return flight && flight.carrier_code && flight.flight_number && flight.scheduled_departure
    })

    console.log(`✅ ${validJourneys.length} journeys with valid flight info`)

    // Process journeys in parallel batches
    const results = await processBatch(
      validJourneys,
      async (journey: any) => {
        const flight = journey.flight as any
        const carrier = flight.carrier_code
        const flightNumber = flight.flight_number
        const departureDate = new Date(flight.scheduled_departure)

        try {
          // Fetch from Cirium
          const ciriumData = await fetchFlightStatus(carrier, flightNumber, departureDate)
          if (!ciriumData) {
            return {
              journeyId: journey.id,
              status: 'skipped' as const,
              error: 'No data from Cirium',
            } as JourneyResult
          }

          // Parse the response
          const flightData = parseFlightStatus(ciriumData)
          if (!flightData) {
            return {
              journeyId: journey.id,
              status: 'skipped' as const,
              error: 'Failed to parse Cirium data',
            } as JourneyResult
          }

          // Determine new phase and status
          const newPhase = mapCiriumStatusToPhase(flightData.status)
          const newStatus = mapPhaseToStatus(newPhase)
          const newGate = flightData.gate?.trim() || ''
          const newTerminal = flightData.terminal?.trim() || ''

          console.log(`📊 Journey ${journey.id}:`)
          console.log(`   Current: phase=${journey.current_phase}, status=${journey.status}, gate=${journey.gate}, terminal=${journey.terminal}`)
          console.log(`   New: phase=${newPhase}, status=${newStatus}, gate=${newGate}, terminal=${newTerminal}`)
          console.log(`   Cirium Status: "${flightData.status}"`)

          // Check if anything changed
          const phaseChanged = journey.current_phase !== newPhase
          const statusChanged = journey.status !== newStatus
          const gateChanged = journey.gate !== newGate && newGate !== ''
          const terminalChanged = journey.terminal !== newTerminal && newTerminal !== ''

          if (!phaseChanged && !statusChanged && !gateChanged && !terminalChanged) {
            return {
              journeyId: journey.id,
              status: 'no_change' as const,
              phase: newPhase,
            } as JourneyResult
          }

          // Prepare update data
          const updateData: any = {
            updated_at: new Date().toISOString(),
          }

          if (phaseChanged) updateData.current_phase = newPhase
          if (statusChanged) updateData.status = newStatus
          if (gateChanged) updateData.gate = newGate
          if (terminalChanged) updateData.terminal = newTerminal
          
          // Store original Cirium status in media column for better notifications
          // This helps when phase is "unknown" - we can show the actual Cirium status
          try {
            const existingMedia = journey.media || {}
            const updatedMedia = {
              ...existingMedia,
              lastCiriumStatus: flightData.status, // Store original Cirium status
              lastCiriumUpdate: new Date().toISOString(),
              flightStatuses: ciriumData?.flightStatuses || existingMedia.flightStatuses,
            }
            updateData.media = updatedMedia
            console.log(`💾 Storing Cirium status "${flightData.status}" in media for future notifications`)
          } catch (e) {
            console.warn(`⚠️ Error updating media with Cirium status: ${e}`)
            // Don't fail the update if media update fails
          }

          // Update the journey (trigger will send notifications)
          const { error: updateError } = await supabaseClient
            .from('journeys')
            .update(updateData)
            .eq('id', journey.id)

          if (updateError) {
            return {
              journeyId: journey.id,
              status: 'error' as const,
              error: updateError.message,
            } as JourneyResult
          }

          return {
            journeyId: journey.id,
            status: 'updated' as const,
            phase: newPhase,
            status_new: newStatus,
            gate: gateChanged ? newGate : undefined,
            terminal: terminalChanged ? newTerminal : undefined,
          } as JourneyResult

        } catch (error: any) {
          return {
            journeyId: journey.id,
            status: 'error' as const,
            error: error.message || String(error),
          } as JourneyResult
        }
      },
      MAX_CONCURRENT_REQUESTS
    )

    // Aggregate results
    const updatedCount = results.filter(r => r.status === 'updated').length
    const errorCount = results.filter(r => r.status === 'error').length
    const noChangeCount = results.filter(r => r.status === 'no_change').length
    const skippedCount = results.filter(r => r.status === 'skipped').length

    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log(`✅ COMPLETE:`)
    console.log(`   Checked: ${validJourneys.length}`)
    console.log(`   Updated: ${updatedCount}`)
    console.log(`   No change: ${noChangeCount}`)
    console.log(`   Skipped: ${skippedCount}`)
    console.log(`   Errors: ${errorCount}`)
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')

    return new Response(
      JSON.stringify({
        success: true,
        checked: validJourneys.length,
        updated: updatedCount,
        no_change: noChangeCount,
        skipped: skippedCount,
        errors: errorCount,
        summary: {
          total: validJourneys.length,
          updated: updatedCount,
          no_change: noChangeCount,
          skipped: skippedCount,
          errors: errorCount,
        },
        results: results.slice(0, 20), // Show more results
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('❌ Error in check-flight-statuses:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

