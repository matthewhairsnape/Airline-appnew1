# 📱 Notification Messages Guide

This document lists all notification messages in the app and where to edit them.

---

## 🎯 **Primary Location (Main Notifications)**

### **File**: `supabase/functions/flight-update-notification/index.ts`

**This is the main file that handles most automatic notifications.** Edit messages here for:
- Phase changes (boarding, departed, landed, etc.)
- Gate changes
- Terminal changes
- Status changes
- Delay/cancellation notifications

**Location**: Lines 162-304

### **Current Messages:**

#### **Phase-Based Notifications:**
```typescript
// Line 222-224
case 'pre_check_in':
  title = 'Check-in Available'
  body = `📱 Check-in is now available for ${flightCode}.`

// Line 226-228
case 'boarding':
  title = 'Flight Boarding'
  body = `🛫 ${flightCode} is now boarding! Please proceed to the gate.`

// Line 230-232
case 'gate_closed':
  title = 'Gate Closed'
  body = `⚠️ Gate is now closed for ${flightCode}. Please contact airline staff.`

// Line 234-237
case 'departed':
case 'in_flight':
  title = 'Flight Departed'
  body = `✈️ ${flightCode} has departed. Enjoy your journey!`

// Line 239-241
case 'landed':
  title = 'Flight Landed'
  body = `🛬 ${flightCode} has landed.`

// Line 243-245
case 'arrived':
  title = 'Flight Arrived'
  body = `✅ ${flightCode} has arrived. Thank you for flying with us!`

// Line 247-249
case 'cancelled':
  title = 'Flight Cancelled'
  body = `❌ ${flightCode} has been cancelled. Please contact airline for assistance.`

// Line 251-253
case 'diverted':
  title = 'Flight Diverted'
  body = `⚠️ ${flightCode} has been diverted. Please check with airline staff for updates.`
```

#### **Notification Type-Based Messages:**
```typescript
// Line 171-173
case 'delay':
  title = 'Flight Delayed'
  body = `⏰ ${flightCode} has been delayed. Please check for updates.`

// Line 175-177
case 'cancellation':
  title = 'Flight Cancelled'
  body = `❌ ${flightCode} has been cancelled. Please contact airline for assistance.`

// Line 179-181
case 'boarding':
  title = 'Flight Boarding'
  body = `🛫 ${flightCode} is now boarding! Please proceed to the gate.`

// Line 183-185
case 'departure':
  title = 'Flight Departed'
  body = `✈️ ${flightCode} has departed. Enjoy your journey!`

// Line 187-189
case 'arrival':
  title = 'Flight Arrived'
  body = `🛬 ${flightCode} has arrived. Welcome to your destination!`

// Line 191-203
case 'gate_change':
  title = 'Gate Changed'
  body = `🚪 Your gate has changed from Gate ${oldGate} to Gate ${newGate}. Please proceed to Gate ${newGate}.`

// Line 205-217
case 'terminal_change':
  title = 'Terminal Changed'
  body = `🏢 Your terminal has changed from Terminal ${oldTerminal} to Terminal ${newTerminal}. Please proceed to Terminal ${newTerminal}.`
```

---

## 📍 **Secondary Locations**

### **1. Client-Side Journey Notifications**

**File**: `lib/services/journey_notification_service.dart`

**Location**: Lines 147-230

**Messages:**
```dart
// Line 148-150
case FlightPhase.boarding:
  title = 'Boarding Started'
  body = 'Boarding has begun for $flightInfo'

// Line 153-155
case FlightPhase.inFlight:
  title = 'Flight Departed'
  body = 'Your flight $flightInfo has departed'

// Line 158-160
case FlightPhase.landed:
  title = 'Flight Landed'
  body = 'Your flight $flightInfo has landed'

// Line 163-165
case FlightPhase.completed:
  title = 'Journey Complete'
  body = 'Your journey $flightInfo is complete. Rate your experience!'

// Line 199-200 (Gate Change)
title = 'Gate Change'
body = 'Gate changed from $oldGate to $newGate for $flightInfo'

// Line 221-222 (Delay)
title = 'Flight Delay'
body = '$flightInfo delayed. New time: $newTime. Reason: $delayReason'
```

---

### **2. Feedback Stage Notifications**

**File**: `lib/services/stage_question_service.dart`

**Location**: Lines 175-198

**Messages:**
```dart
// Line 177-178 (Pre-Flight)
return '✈️ Your flight check-in is open! Share your pre-flight experience with us.'

// Line 179-180 (In-Flight)
return '☁️ You\'re in the air! Quick question about your in-flight experience.'

// Line 181-182 (Post-Flight)
return '🛬 Welcome! You\'ve landed. Tell us about your overall journey.'

// Titles (Lines 188-198):
case FeedbackStage.preFlight:
  return 'Preflight Feedback'
case FeedbackStage.inFlight:
  return 'In-Flight Feedback'
case FeedbackStage.postFlight:
  return 'Journey Reflection'
```

---

### **3. Cirium API Service Messages**

**File**: `lib/services/cirium_api_service.dart`

**Location**: Lines 227-253

**Messages:**
```dart
// Line 235-236
case 'boarding':
  return '🛫 Your flight $flight is now boarding! Please proceed to the gate.'

// Line 237-238
case 'gate_closed':
  return '⚠️ Gate is now closed for flight $flight. Please contact airline staff.'

// Line 239-241
case 'departed':
case 'in_flight':
  return '✈️ Flight $flight has departed. Enjoy your journey!'

// Line 242-243
case 'landed':
  return '🛬 Flight $flight has landed. Welcome to your destination!'

// Line 244-245
case 'arrived':
  return '✅ Flight $flight has arrived. Thank you for flying with us!'

// Line 246-247
case 'cancelled':
  return '❌ Flight $flight has been cancelled. Please contact airline for assistance.'

// Line 248-249
case 'delayed':
  return '⏰ Flight $flight has been delayed. Please check for updates.'
```

---

### **4. Test Notification**

**File**: `lib/services/push_notification_service.dart`

**Location**: Lines 995-996

**Message:**
```dart
'title': '✈️ Flight Status Test'
'body': 'This is a test notification! Your push notifications are working correctly.'
```

---

### **5. Alternative Edge Function (Not Currently Used)**

**File**: `supabase/functions/flight-status-notification/index.ts`

**Location**: Lines 90-153

**Note**: This file exists but may not be actively used. The main function is `flight-update-notification`.

**Messages:**
```typescript
// Line 98-100
case 'at_airport':
  title: '🏢 At the Airport'
  body: `Welcome! ${flightInfo} - Check-in and prepare for boarding.`

// Line 103-105
case 'boarding':
  title: '🎫 Boarding Started'
  body: `${flightInfo} is now boarding. Please proceed to your gate.`

// Line 108-110
case 'in_flight':
  title: '✈️ Flight Departed'
  body: `${flightInfo} is now in the air. Enjoy your flight!`

// Line 113-115
case 'landed':
  title: '🛬 Flight Landed'
  body: `${flightInfo} has landed safely. Welcome to your destination!`
```

---

## 📝 **How to Edit Messages**

### **Step 1: Edit Main Notification Messages**

1. Open: `supabase/functions/flight-update-notification/index.ts`
2. Navigate to lines 162-304
3. Find the message you want to edit
4. Modify the `title` and/or `body` variables
5. Save the file

### **Step 2: Redeploy Edge Function**

After editing, you must redeploy the Edge Function:

```bash
# Deploy the updated function
supabase functions deploy flight-update-notification --project-ref otidfywfqxyxteixpqre --no-verify-jwt
```

Or use the Supabase Dashboard:
1. Go to **Supabase Dashboard → Edge Functions**
2. Find `flight-update-notification`
3. Click **Deploy** (or edit and deploy)

### **Step 3: Test**

Test your changes by triggering a notification:
```sql
-- Test gate change notification
UPDATE journeys
SET gate = 'B12',
    updated_at = NOW()
WHERE id = 'your-journey-id';
```

---

## 🎨 **Message Customization Tips**

### **Variables Available:**

- `${flightCode}` - Flight code (e.g., "AA123")
- `${oldGate}` - Previous gate number
- `${newGate}` - New gate number
- `${oldTerminal}` - Previous terminal
- `${newTerminal}` - New terminal
- `${flightInfo}` - Flight information string

### **Emoji Usage:**

The app uses emojis for visual appeal:
- 🛫 Boarding
- ✈️ Departure/In-flight
- 🛬 Landing/Arrival
- ⚠️ Warnings/Important
- ✅ Success/Completion
- ❌ Cancellation/Error
- 📱 Check-in/Updates
- 🚪 Gate changes
- 🏢 Terminal changes
- ⏰ Delays

### **Best Practices:**

1. **Keep messages concise** - Notifications should be short and clear
2. **Include actionable information** - Tell users what to do next
3. **Use consistent tone** - Match your brand voice
4. **Test thoroughly** - Ensure messages display correctly on both iOS and Android
5. **Consider localization** - If supporting multiple languages, you may want to externalize messages

---

## 🌍 **Multi-Language Support (Future Enhancement)**

Currently, messages are hardcoded in English. To support multiple languages:

1. Create a messages file (e.g., `messages.json`)
2. Store messages by language code
3. Load messages based on user's language preference
4. Update Edge Function to accept language parameter

Example structure:
```json
{
  "en": {
    "boarding": {
      "title": "Flight Boarding",
      "body": "🛫 {flightCode} is now boarding! Please proceed to the gate."
    }
  },
  "es": {
    "boarding": {
      "title": "Embarque de Vuelo",
      "body": "🛫 {flightCode} está embarcando ahora. Por favor, diríjase a la puerta."
    }
  }
}
```

---

## 📋 **Quick Reference: All Message Locations**

| Message Type | File | Lines | Priority |
|-------------|------|-------|----------|
| **Phase Changes** | `supabase/functions/flight-update-notification/index.ts` | 221-254 | **HIGH** |
| **Gate Changes** | `supabase/functions/flight-update-notification/index.ts` | 191-203 | **HIGH** |
| **Terminal Changes** | `supabase/functions/flight-update-notification/index.ts` | 205-217 | **HIGH** |
| **Delays/Cancellations** | `supabase/functions/flight-update-notification/index.ts` | 171-178 | **HIGH** |
| **Journey Notifications** | `lib/services/journey_notification_service.dart` | 147-230 | Medium |
| **Feedback Messages** | `lib/services/stage_question_service.dart` | 175-198 | Medium |
| **Cirium Messages** | `lib/services/cirium_api_service.dart` | 227-253 | Low |
| **Test Notification** | `lib/services/push_notification_service.dart` | 995-996 | Low |

---

## ✅ **Summary**

**To edit notification messages:**

1. **Main location**: `supabase/functions/flight-update-notification/index.ts` (Lines 162-304)
2. **Edit** the `title` and `body` variables for each notification type
3. **Redeploy** the Edge Function
4. **Test** your changes

**Most notifications are automatically triggered by database changes**, so editing the main Edge Function will update most messages users receive.

