import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface FlightStatusNotificationRequest {
  journeyId: string
  userId: string
  oldStatus?: string
  newStatus: string
  oldPhase?: string
  newPhase?: string
  flightNumber?: string
  carrier?: string
}

// Get OAuth 2.0 token for Firebase Admin
async function getFirebaseAccessToken(): Promise<string> {
  const privateKey = Deno.env.get('FIREBASE_PRIVATE_KEY')
  const clientEmail = Deno.env.get('FIREBASE_CLIENT_EMAIL')

  if (!privateKey || !clientEmail) {
    throw new Error('Firebase credentials not configured')
  }

  // Create JWT
  const header = { alg: 'RS256', typ: 'JWT' }
  const now = Math.floor(Date.now() / 1000)
  const payload = {
    iss: clientEmail,
    sub: clientEmail,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  }

  const encodedHeader = btoa(JSON.stringify(header))
  const encodedPayload = btoa(JSON.stringify(payload))
  const unsignedToken = `${encodedHeader}.${encodedPayload}`

  const encoder = new TextEncoder()
  const data = encoder.encode(unsignedToken)
  
  const cleanedKey = privateKey.replace(/\\n/g, '\n')
  const pemHeader = '-----BEGIN PRIVATE KEY-----'
  const pemFooter = '-----END PRIVATE KEY-----'
  const pemStartIndex = cleanedKey.indexOf(pemHeader)
  const pemEndIndex = cleanedKey.indexOf(pemFooter)
  
  if (pemStartIndex === -1 || pemEndIndex === -1) {
    throw new Error('Invalid private key format')
  }
  
  const pemContents = cleanedKey
    .substring(pemStartIndex + pemHeader.length, pemEndIndex)
    .replace(/\s/g, '')
  
  const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))
  
  const key = await crypto.subtle.importKey(
    'pkcs8',
    binaryDer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  )

  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, data)
  const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
  const jwt = `${unsignedToken}.${encodedSignature}`

  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  const tokenData = await tokenResponse.json()
  return tokenData.access_token
}

// Generate notification content based on status/phase change
function getNotificationContent(request: FlightStatusNotificationRequest): { title: string, body: string } {
  const { newStatus, newPhase, oldPhase, flightNumber, carrier } = request
  const flightInfo = carrier && flightNumber ? `${carrier}${flightNumber}` : 'Your flight'

  // Phase-based notifications
  if (newPhase && newPhase !== oldPhase) {
    switch (newPhase) {
      case 'at_airport':
        return {
          title: '🏢 At the Airport',
          body: `Welcome! ${flightInfo} - Check-in and prepare for boarding.`
        }
      case 'boarding':
        return {
          title: '🎫 Boarding Started',
          body: `${flightInfo} is now boarding. Please proceed to your gate.`
        }
      case 'in_flight':
        return {
          title: '✈️ Flight Departed',
          body: `${flightInfo} is now in the air. Enjoy your flight!`
        }
      case 'landed':
        return {
          title: '🛬 Flight Landed',
          body: `${flightInfo} has landed safely. Welcome to your destination!`
        }
      default:
        return {
          title: '📱 Flight Update',
          body: `${flightInfo} - Status updated to ${newPhase}`
        }
    }
  }

  // Status-based notifications
  switch (newStatus) {
    case 'active':
      return {
        title: '✅ Journey Active',
        body: `Your journey for ${flightInfo} is now active.`
      }
    case 'completed':
      return {
        title: '🎉 Journey Completed',
        body: `Your journey for ${flightInfo} is complete. Please share your feedback!`
      }
    case 'delayed':
      return {
        title: '⏰ Flight Delayed',
        body: `${flightInfo} has been delayed. Check the app for updates.`
      }
    case 'cancelled':
      return {
        title: '❌ Flight Cancelled',
        body: `${flightInfo} has been cancelled. Please contact your airline.`
      }
    default:
      return {
        title: '📱 Flight Update',
        body: `${flightInfo} - Status updated`
      }
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log('✈️ FLIGHT STATUS NOTIFICATION')
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const request: FlightStatusNotificationRequest = await req.json()
    console.log('📋 Request:', {
      journeyId: request.journeyId,
      userId: request.userId,
      oldStatus: request.oldStatus,
      newStatus: request.newStatus,
      oldPhase: request.oldPhase,
      newPhase: request.newPhase,
    })

    // Validate request
    if (!request.journeyId || !request.userId || !request.newStatus) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: journeyId, userId, newStatus' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get user's FCM token
    console.log('👤 Looking up FCM token for user:', request.userId)
    const { data: user, error: userError } = await supabaseClient
      .from('users')
      .select('fcm_token')
      .eq('id', request.userId)
      .single()

    if (userError || !user || !user.fcm_token) {
      console.log('⚠️ No FCM token found for user')
      return new Response(
        JSON.stringify({ success: true, message: 'User has no FCM token, skipping notification' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('✅ FCM token found')

    // Check Firebase credentials
    const projectId = Deno.env.get('FIREBASE_PROJECT_ID')
    const clientEmail = Deno.env.get('FIREBASE_CLIENT_EMAIL')
    const privateKey = Deno.env.get('FIREBASE_PRIVATE_KEY')

    if (!projectId || !clientEmail || !privateKey) {
      console.error('❌ Firebase credentials not configured')
      return new Response(
        JSON.stringify({ error: 'Firebase credentials not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Generate notification content
    const { title, body } = getNotificationContent(request)
    console.log('📝 Notification:', { title, body })

    // Get Firebase access token
    console.log('🔐 Getting Firebase access token...')
    const accessToken = await getFirebaseAccessToken()
    console.log('✅ Access token obtained')

    // Send notification
    const message = {
      message: {
        token: user.fcm_token,
        notification: { title, body },
        data: {
          journey_id: request.journeyId,
          old_status: request.oldStatus || '',
          new_status: request.newStatus,
          old_phase: request.oldPhase || '',
          new_phase: request.newPhase || '',
          flight_number: request.flightNumber || '',
          type: 'flight_status_update',
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'high_importance_channel',
            defaultSound: true,
            defaultVibrateTimings: true,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
              alert: { title, body },
              contentAvailable: 1,
            },
          },
        },
      },
    }

    console.log('📨 Sending notification...')
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(message),
      }
    )

    const responseText = await response.text()
    console.log('📥 FCM Response:', response.status, responseText)

    if (!response.ok) {
      throw new Error(`FCM error: ${response.status} - ${responseText}`)
    }

    const result = JSON.parse(responseText)
    console.log('✅ Notification sent successfully:', result.name)

    // Log notification in database (optional)
    try {
      await supabaseClient.from('notification_logs').insert({
        user_id: request.userId,
        journey_id: request.journeyId,
        title,
        body,
        type: 'flight_status_update',
        status: 'sent',
        sent_at: new Date().toISOString(),
      })
      console.log('📝 Notification logged in database')
    } catch (logError) {
      console.log('⚠️ Could not log notification:', logError)
    }

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log('✅ SUCCESS')
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Notification sent successfully',
        messageId: result.name,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('❌ Error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

