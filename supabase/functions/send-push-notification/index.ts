import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface NotificationRequest {
  userId?: string
  token?: string
  tokens?: string[]
  title: string
  body: string
  data?: Record<string, any>
}

// Get OAuth 2.0 token for Firebase Admin
async function getFirebaseAccessToken(): Promise<string> {
  const privateKey = Deno.env.get('FIREBASE_PRIVATE_KEY')
  const clientEmail = Deno.env.get('FIREBASE_CLIENT_EMAIL')

  if (!privateKey || !clientEmail) {
    throw new Error('Firebase credentials not configured')
  }

  // Create JWT
  const header = {
    alg: 'RS256',
    typ: 'JWT',
  }

  const now = Math.floor(Date.now() / 1000)
  const payload = {
    iss: clientEmail,
    sub: clientEmail,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  }

  // Encode header and payload
  const encodedHeader = btoa(JSON.stringify(header))
  const encodedPayload = btoa(JSON.stringify(payload))
  const unsignedToken = `${encodedHeader}.${encodedPayload}`

  // Sign with private key
  const encoder = new TextEncoder()
  const data = encoder.encode(unsignedToken)
  
  // Import private key for signing
  // Handle escaped newlines in the private key
  const cleanedKey = privateKey.replace(/\\n/g, '\n')
  
  const pemHeader = '-----BEGIN PRIVATE KEY-----'
  const pemFooter = '-----END PRIVATE KEY-----'
  
  // Extract the content between BEGIN and END
  const pemStartIndex = cleanedKey.indexOf(pemHeader)
  const pemEndIndex = cleanedKey.indexOf(pemFooter)
  
  if (pemStartIndex === -1 || pemEndIndex === -1) {
    throw new Error('Invalid private key format')
  }
  
  const pemContents = cleanedKey
    .substring(pemStartIndex + pemHeader.length, pemEndIndex)
    .replace(/\s/g, '') // Remove all whitespace including newlines
  
  const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))
  
  const key = await crypto.subtle.importKey(
    'pkcs8',
    binaryDer,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign']
  )

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    data
  )

  const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
  const jwt = `${unsignedToken}.${encodedSignature}`

  // Exchange JWT for access token
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  const tokenData = await tokenResponse.json()
  return tokenData.access_token
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log('📤 SEND-PUSH-NOTIFICATION (V2 - Firebase Admin SDK)')
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { userId, token, tokens, title, body, data }: NotificationRequest = await req.json()

    console.log('📋 Request:', { userId, hasToken: !!token, tokensCount: tokens?.length, title })

    if (!title || !body) {
      return new Response(
        JSON.stringify({ error: 'Title and body are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check Firebase credentials
    const projectId = Deno.env.get('FIREBASE_PROJECT_ID')
    const clientEmail = Deno.env.get('FIREBASE_CLIENT_EMAIL')
    const privateKey = Deno.env.get('FIREBASE_PRIVATE_KEY')

    console.log('🔑 Firebase Credentials Check:')
    console.log('  - Project ID:', !!projectId ? 'Found ✅' : 'Missing ❌')
    console.log('  - Client Email:', !!clientEmail ? 'Found ✅' : 'Missing ❌')
    console.log('  - Private Key:', !!privateKey ? 'Found ✅' : 'Missing ❌')

    if (!projectId || !clientEmail || !privateKey) {
      return new Response(
        JSON.stringify({ error: 'Firebase credentials not configured. Add FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, and FIREBASE_PRIVATE_KEY secrets.' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    let targetTokens: string[] = []

    // Get FCM token(s)
    if (userId) {
      console.log('👤 Looking up FCM token for user:', userId)
      const { data: user, error } = await supabaseClient
        .from('users')
        .select('fcm_token')
        .eq('id', userId)
        .single()

      if (error || !user || !user.fcm_token) {
        return new Response(
          JSON.stringify({ error: 'No FCM token found for user' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      targetTokens = [user.fcm_token]
      console.log('✅ FCM token found:', user.fcm_token.substring(0, 30) + '...')
    } else if (token) {
      targetTokens = [token]
    } else if (tokens && tokens.length > 0) {
      targetTokens = tokens
    } else {
      return new Response(
        JSON.stringify({ error: 'Either userId, token, or tokens must be provided' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (targetTokens.length === 0) {
      return new Response(
        JSON.stringify({ error: 'No valid tokens found' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('📤 Sending to', targetTokens.length, 'device(s)')

    // Get Firebase access token
    console.log('🔐 Getting Firebase access token...')
    const accessToken = await getFirebaseAccessToken()
    console.log('✅ Access token obtained')

    // Send notifications using FCM v1 API
    const results = await Promise.allSettled(
      targetTokens.map(async (fcmToken) => {
        const message = {
          message: {
            token: fcmToken,
            notification: {
              title,
              body,
            },
            data: data || {},
            android: {
              priority: 'high',
              notification: {
                sound: 'default',
                channelId: 'high_importance_channel', // CRITICAL for Android foreground notifications
                defaultSound: true,
                defaultVibrateTimings: true,
              },
            },
            apns: {
              headers: {
                'apns-priority': '10', // CRITICAL: High priority for immediate delivery
                'apns-push-type': 'alert', // CRITICAL: Ensures notification shows outside app
              },
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                  alert: {
                    title,
                    body,
                  },
                  // CRITICAL: These settings ensure notification shows outside app
                  'content-available': 1,
                  'mutable-content': 1,
                  // CRITICAL for iOS 15+: Use time-sensitive to prevent auto-dismiss
                  // This ensures notifications persist until user dismisses them
                  'interruption-level': 'time-sensitive',  // iOS 15+ - prevents auto-dismiss
                  // Category for better notification management
                  category: 'FLIGHT_NOTIFICATION',
                  // Thread identifier to prevent notification grouping (iOS 12+)
                  'thread-id': 'flight_notifications',
                },
              },
            },
          },
        }

        console.log('📨 Sending to:', fcmToken.substring(0, 20) + '...')

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
        console.log('✅✅✅ SUCCESS! Message:', result.name)
        return result
      })
    )

    let successful = 0
    let failed = 0

    results.forEach((result, index) => {
      if (result.status === 'fulfilled') {
        successful++
        console.log(`✅ Notification ${index} sent successfully`)
      } else {
        failed++
        console.error(`❌ Notification ${index} failed:`, result.reason)
      }
    })

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log('📊 SUMMARY')
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log('✅ Successful:', successful)
    console.log('❌ Failed:', failed)

    return new Response(
      JSON.stringify({
        success: true,
        sent: successful,
        failed,
        total: targetTokens.length,
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

