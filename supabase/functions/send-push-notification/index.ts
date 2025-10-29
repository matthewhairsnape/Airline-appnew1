import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Helper function to get human-readable FCM error descriptions
function getFCMErrorDescription(errorCode: string): string {
  const errorMap: Record<string, string> = {
    'MissingRegistration': 'Missing registration token. Make sure the token is provided.',
    'InvalidRegistration': 'Invalid registration token. The token may be expired or not valid.',
    'NotRegistered': 'Unregistered device. The user may have uninstalled the app.',
    'InvalidPackageName': 'Invalid package name. Check your Firebase configuration.',
    'MismatchSenderId': 'Mismatch Sender ID. The token is not associated with your FCM project.',
    'InvalidParameters': 'Invalid parameters in the message payload.',
    'MessageTooBig': 'Message payload is too large (max 4KB).',
    'InvalidDataKey': 'Invalid data key in the payload.',
    'InvalidTtl': ' Special value, if set, GCM will not throttle the message.',
    'Unavailable': 'FCM service is temporarily unavailable. Try again later.',
    'InternalServerError': 'FCM server encountered an internal error.',
    'DeviceMessageRateExceeded': 'Message rate exceeded for this device.',
    'TopicsMessageRateExceeded': 'Message rate exceeded for this topic.',
  }
  return errorMap[errorCode] || `Unknown error code: ${errorCode}`
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface NotificationRequest {
  userId?: string
  token?: string
  tokens?: string[]
  topic?: string
  title: string
  body: string
  data?: Record<string, any>
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log('📤 SEND-PUSH-NOTIFICATION FUNCTION CALLED')
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log('📋 Request method:', req.method)
    console.log('📋 Request URL:', req.url)
    
    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { userId, token, tokens, topic, title, body, data }: NotificationRequest = await req.json()
    
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log('📋 REQUEST DATA RECEIVED:')
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log('userId:', userId)
    console.log('hasToken:', !!token)
    console.log('tokensCount:', tokens?.length || 0)
    console.log('topic:', topic)
    console.log('title:', title)
    console.log('body:', body)
    console.log('data:', data)
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')

    // Validate input
    if (!title || !body) {
      console.error('❌ Missing title or body')
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
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log('🔑 FCM SERVER KEY CHECK')
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log('FCM_SERVER_KEY exists:', !!fcmServerKey)
    if (fcmServerKey) {
      console.log('FCM_SERVER_KEY length:', fcmServerKey.length)
      console.log('FCM_SERVER_KEY preview:', fcmServerKey.substring(0, 10) + '...')
    }
    
    if (!fcmServerKey) {
      console.error('❌ FCM server key not configured')
      console.error('⚠️ Please set FCM_SERVER_KEY in Supabase Dashboard → Edge Functions → Secrets')
      return new Response(
        JSON.stringify({ error: 'FCM server key not configured' }),
        { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    let targetTokens: string[] = []

    // If userId is provided, look up the FCM token
    if (userId) {
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
      console.log('👤 LOOKING UP FCM TOKEN FOR USER')
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
      console.log('userId:', userId)
      const { data: user, error: userError } = await supabaseClient
        .from('users')
        .select('fcm_token, push_token')
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

      const fcmToken = user.fcm_token || user.push_token
      if (!fcmToken) {
        console.error('❌ No FCM token found for user:', userId)
        return new Response(
          JSON.stringify({ error: 'No FCM token found for user' }),
          { 
            status: 400, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        )
      }

      targetTokens = [fcmToken]
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
      console.log('✅ FCM TOKEN FOUND')
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
      console.log('Token preview:', fcmToken.substring(0, 30) + '...')
      console.log('Token length:', fcmToken.length)
    } else if (token) {
      // Single token provided directly
      targetTokens = [token]
      console.log('📱 Using provided token')
    } else if (tokens && tokens.length > 0) {
      // Multiple tokens provided
      targetTokens = tokens
      console.log('📱 Using provided tokens:', tokens.length)
    } else if (topic) {
      // Get all tokens for users subscribed to topic
      const { data: userTokens, error } = await supabaseClient
        .from('user_topic_subscriptions')
        .select('fcm_token')
        .eq('topic', topic)
        .not('fcm_token', 'is', null)

      if (error) {
        console.error('❌ Error fetching tokens for topic:', error)
        return new Response(
          JSON.stringify({ error: 'Failed to fetch tokens for topic' }),
          { 
            status: 500, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        )
      }

      targetTokens = userTokens?.map((row: any) => row.fcm_token) || []
      console.log('📱 Found tokens for topic:', targetTokens.length)
    } else {
      console.error('❌ No token source provided')
      return new Response(
        JSON.stringify({ error: 'Either userId, token, tokens, or topic must be provided' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    if (targetTokens.length === 0) {
      console.error('❌ No valid tokens found')
      return new Response(
        JSON.stringify({ error: 'No valid tokens found' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    console.log('📤 Sending notifications to', targetTokens.length, 'tokens')

    // Send notifications via FCM
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

        console.log('📨 Sending to token:', fcmToken.substring(0, 20) + '...')

        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
        console.log('📨 SENDING TO FCM API')
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
        console.log('Token (first 30 leaked chars):', fcmToken.substring(0, 30) + '...')
        console.log('Title:', title)
        console.log('Body:', body)
        
        const response = await fetch('https://fcm.googleapis.com/fcm/send', {
          method: 'POST',
          headers: {
            'Authorization': `key=${fcmServerKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(message),
        })

        const responseText = await response.text()
        console.log('📥 FCM API Response Status:', response.status)
        console.log('📥 FCM API Response:', responseText)

        if (!response.ok) {
          console.error('❌ FCM API error:', response.status, responseText)
          throw new Error(`FCM API error: ${response.status} - ${responseText}`)
        }

        let result
        try {
          result = JSON.parse(responseText)
          console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
          console.log('✅ FCM RESPONSE PARSED')
          console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
          console.log('Full response JSON:', JSON.stringify(result, null, 2))
          console.log('Has results array:', !!result.results)
          console.log('Results length:', result.results?.length ?? 0)
          console.log('Success count:', result.success ?? 0)
          console.log('Failure count:', result.failure ?? 0)
          
          // Immediately log errors if present
          if (result.results && Array.isArray(result.results)) {
            result.results.forEach((r: any, idx: number) => {
              if (r.error) {
                console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
                console.error(`❌ IMMEDIATE FCM ERROR DETECTED IN RESULT ${idx}`)
                console.error(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`)
                console.error(`Error code: ${r.error}`)
                console.error(`Error description: ${getFCMErrorDescription(r.error)}`)
                console.error(`Full error result:`, JSON.stringify(r, null, 2))
              }
            })
          }
          
          if (result.failure > 0 && (!result.results || result.results.length === 0)) {
            console.error('⚠️ FCM reported failures but no results array details')
          }
        } catch (e) {
          console.error('❌ Error parsing FCM response:', e)
          console.error('Raw response text:', responseText)
          result = { raw: responseText, parseError: e.message }
        }
        
        return result
      })
    )

    // Count successful and failed notifications
    let successful = 0
    let failed = 0
    
    // First pass: analyze results to get accurate counts
    results.forEach((result, index) => {
      if (result.status === 'fulfilled') {
        const fcmResult = result.value
        // Check if FCM actually succeeded (has message_id) or failed (has error)
        if (fcmResult?.results && Array.isArray(fcmResult.results)) {
          const hasError = fcmResult.results.some((r: any) => r.error)
          const hasSuccess = fcmResult.results.some((r: any) => r.message_id)
          if (hasSuccess && !hasError) {
            successful++
          } else if (hasError) {
            failed++
          }
        } else {
          // Fallback to FCM's success/failure counts
          if (fcmResult?.success > 0 && fcmResult?.failure === 0) {
            successful++
          } else {
            failed++
          }
        }
      } else if (result.status === 'rejected') {
        failed++
      }
    })

    // Log any errors
    results.forEach((result, index) => {
      if (result.status === 'rejected') {
        console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
        console.error(`❌ FAILED TO SEND NOTIFICATION ${index}`)
        console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
        console.error('Error reason:', result.reason)
        console.error('Error message:', result.reason?.message)
        console.error('Error stack:', result.reason?.stack)
        console.error('Token (first 30 chars):', targetTokens[index]?.substring(0, 30))
      } else if (result.status === 'fulfilled') {
        const fcmResult = result.value
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
        console.log(`📋 NOTIFICATION ${index} FCM RESPONSE:`)
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
        console.log('Full FCM response:', JSON.stringify(fcmResult, null, 2))
        
        if (fcmResult?.results && Array.isArray(fcmResult.results)) {
          fcmResult.results.forEach((r: any, i: number) => {
            console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`)
            console.log(`📋 FCM RESULT ${i} DETAILS:`)
            console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`)
            console.log('Full result:', JSON.stringify(r, null, 2))
            if (r.error) {
              console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
              console.error(`❌❌❌ FCM ERROR DETECTED ❌❌❌`)
              console.error(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`)
              console.error(`Error code: ${r.error}`)
              console.error(`Error description: ${getFCMErrorDescription(r.error)}`)
              console.error(`Token used (first 30 chars): ${targetTokens[index]?.substring(0, 30)}...`)
              console.error(`Token length: ${targetTokens[index]?.length}`)
              console.error(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`)
            } else if (r.message_id) {
              console.log(`✅✅✅ SUCCESS! Message ID: ${r.message_id} ✅✅✅`)
            } else {
              console.log(`⚠️ Unknown result state:`, r)
            }
          })
        } else if (fcmResult?.success !== undefined || fcmResult?.failure !== undefined) {
          console.log('FCM success count:', fcmResult.success ?? 0)
          console.log('FCM failure count:', fcmResult.failure ?? 0)
          if (fcmResult.failure > 0 && !fcmResult.results) {
            console.error('⚠️ FCM reported failures but no result details available')
          }
        } else {
          console.log('⚠️ Unexpected FCM response format:', JSON.stringify(fcmResult, null, 2))
        }
      }
    })

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log('📊 NOTIFICATION SEND SUMMARY')
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log('✅ Successful:', successful)
    console.log('❌ Failed:', failed)
    console.log('📊 Total:', targetTokens.length)

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
    console.error('❌ Error in send-push-notification function:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
