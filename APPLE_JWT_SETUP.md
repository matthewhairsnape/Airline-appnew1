# Apple JWT Token Generator Setup

## 🍎 Overview
This tool generates JWT tokens for Apple Push Notification Service (APNs) authentication using your Apple Developer private key.

## 📋 Prerequisites
- Apple Developer Account
- AuthKey file (`.p8` file from Apple Developer Console)
- Node.js installed
- Your Apple Developer Team ID

## 🚀 Quick Start

### 1. Install Dependencies
```bash
npm install
```

### 2. Configure Your Settings
Edit `generate_apple_jwt.js` and update these values:

```javascript
const APPLE_CONFIG = {
  teamId: 'YOUR_TEAM_ID_HERE',        // Your 10-character Team ID
  keyId: 'D738P9CC7G',                // From your .p8 filename
  bundleId: 'com.yourcompany.airlineapp', // Your app's bundle ID
  privateKeyPath: './AuthKey_D738P9CC7G.p8'
};
```

### 3. Find Your Team ID
1. Go to [Apple Developer Console](https://developer.apple.com/account/#!/membership/)
2. Look for your **Team ID** (10 characters like `ABC123DEF4`)

### 4. Generate JWT Token
```bash
npm start
```

## 📁 File Structure
```
├── generate_apple_jwt.js    # Main JWT generator script
├── package.json             # Node.js dependencies
├── AuthKey_D738P9CC7G.p8   # Your Apple private key
├── apple_jwt_token.txt     # Generated token (created after running)
└── APPLE_JWT_SETUP.md      # This setup guide
```

## 🔧 Usage Examples

### Basic Token Generation
```bash
node generate_apple_jwt.js
```

### Using in Your Flutter App
```javascript
// The generated token can be used in your Supabase Edge Functions
// or backend services for sending push notifications

const headers = {
  'Authorization': `Bearer ${jwtToken}`,
  'Content-Type': 'application/json',
  'apns-topic': 'com.yourcompany.airlineapp'
};
```

### Custom Expiration
```javascript
const { generateTokenWithCustomExpiration } = require('./generate_apple_jwt');
const token = generateTokenWithCustomExpiration(12); // 12 hours
```

## 🔐 Security Notes

### ⚠️ Important Security Considerations:
1. **Never commit your `.p8` file to version control**
2. **Store the private key securely in production**
3. **Regenerate tokens regularly (they expire in 24 hours)**
4. **Use environment variables for sensitive data**

### Recommended Production Setup:
```javascript
// Use environment variables
const APPLE_CONFIG = {
  teamId: process.env.APPLE_TEAM_ID,
  keyId: process.env.APPLE_KEY_ID,
  bundleId: process.env.APPLE_BUNDLE_ID,
  privateKeyPath: process.env.APPLE_PRIVATE_KEY_PATH
};
```

## 📱 Integration with Flutter App

### 1. Backend Integration
Use the generated JWT token in your Supabase Edge Functions:

```typescript
// supabase/functions/send-push-notification/index.ts
const jwtToken = 'your-generated-jwt-token-here';

const response = await fetch('https://api.push.apple.com/3/device/DEVICE_TOKEN', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${jwtToken}`,
    'Content-Type': 'application/json',
    'apns-topic': 'com.yourcompany.airlineapp',
    'apns-priority': '10'
  },
  body: JSON.stringify({
    aps: {
      alert: 'Your flight is boarding!',
      sound: 'default'
    }
  })
});
```

### 2. Token Refresh Strategy
```javascript
// Refresh token every 20 hours (before 24-hour expiration)
setInterval(() => {
  const newToken = generateAppleJWT();
  // Update your backend with the new token
}, 20 * 60 * 60 * 1000);
```

## 🐛 Troubleshooting

### Common Issues:

#### 1. "Private key file not found"
- Ensure `AuthKey_D738P9CC7G.p8` is in the same directory
- Check file permissions

#### 2. "Invalid Team ID"
- Verify your Team ID from Apple Developer Console
- Ensure it's exactly 10 characters

#### 3. "JWT verification failed"
- Check that your Key ID matches the .p8 filename
- Verify the private key is valid

#### 4. "Token expired"
- Tokens expire in 24 hours
- Regenerate the token using `npm start`

## 📊 Token Information

### JWT Header:
```json
{
  "alg": "ES256",
  "kid": "D738P9CC7G"
}
```

### JWT Payload:
```json
{
  "iss": "YOUR_TEAM_ID",
  "iat": 1640995200,
  "exp": 1641081600,
  "aud": "https://appleid.apple.com",
  "sub": "com.yourcompany.airlineapp"
}
```

## 🔗 Useful Links

- [Apple Push Notification Service Documentation](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/sending_notification_requests_to_apns)
- [Apple Developer Console](https://developer.apple.com/account/)
- [JWT.io - JWT Debugger](https://jwt.io/)

## 📞 Support

If you encounter any issues:
1. Check the troubleshooting section above
2. Verify your Apple Developer account settings
3. Ensure all dependencies are installed correctly
