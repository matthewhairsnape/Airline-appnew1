# Apple Sign-In Setup for Supabase

## 🍎 Overview
This guide helps you generate the correct Apple Secret Key for Supabase authentication using your Apple Developer credentials.

## 📋 What You Need

### From Apple Developer Console:
1. **Team ID** (10 characters like `ABC123DEF4`)
2. **AuthKey file** (`AuthKey_D738P9CC7G.p8`) ✅ Already have this
3. **Bundle ID** (`com.exp.aero.signin`) ✅ Already configured

### From Supabase:
1. Supabase project with Authentication enabled
2. Access to Authentication > Providers > Apple

## 🚀 Quick Setup

### Step 1: Configure Your Team ID
```bash
node setup_apple_config.js
```
This will prompt you for your Apple Developer Team ID and update all configuration files.

### Step 2: Generate Apple Secret Key
```bash
node generate_supabase_apple_secret.js
```
This generates the JWT token you need for Supabase.

### Step 3: Configure Supabase
1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Go to **Authentication** > **Providers** > **Apple**
4. Enable Apple provider
5. Set the following values:

```
Client ID: com.exp.aero.signin
Secret Key: [paste the generated JWT token]
```

## 📊 Configuration Details

### Apple Developer Console Setup:
- **Services ID**: `com.exp.aero.signin`
- **Team ID**: Your 10-character Team ID
- **Key ID**: `D738P9CC7G` (from your .p8 filename)
- **Private Key**: `AuthKey_D738P9CC7G.p8` ✅

### Supabase Configuration:
```javascript
{
  "provider": "apple",
  "client_id": "com.exp.aero.signin",
  "secret": "[generated-jwt-token]"
}
```

## 🔧 File Structure
```
├── generate_supabase_apple_secret.js    # Generates Supabase secret key
├── setup_apple_config.js                # Interactive setup script
├── generate_apple_jwt.js                # General JWT generator
├── AuthKey_D738P9CC7G.p8               # Your Apple private key
├── supabase_apple_secret.txt            # Generated secret (created after running)
└── SUPABASE_APPLE_SETUP.md             # This guide
```

## 🎯 Step-by-Step Instructions

### 1. Get Your Team ID
1. Go to [Apple Developer Console](https://developer.apple.com/account/#!/membership/)
2. Find your **Team ID** (10 characters)
3. Copy it

### 2. Run Setup Script
```bash
node setup_apple_config.js
```
Enter your Team ID when prompted.

### 3. Generate Secret Key
```bash
node generate_supabase_apple_secret.js
```
Copy the generated JWT token.

### 4. Configure Supabase
1. **Supabase Dashboard** → Your Project
2. **Authentication** → **Providers** → **Apple**
3. **Enable** Apple provider
4. **Client ID**: `com.exp.aero.signin`
5. **Secret Key**: Paste the generated JWT token
6. **Save** configuration

### 5. Test Apple Sign-In
```dart
// In your Flutter app
final AuthResponse response = await supabase.auth.signInWithOAuth(
  Provider.apple,
  redirectTo: 'io.supabase.flutterquickstart://login-callback/',
);
```

## 🔐 Security Notes

### Important:
- ✅ **Secret Key expires in 6 months** - regenerate before expiration
- ✅ **Keep your .p8 file secure** - never commit to version control
- ✅ **Use environment variables** in production
- ✅ **Test in development** before deploying

### Production Setup:
```javascript
// Use environment variables
const APPLE_CONFIG = {
  teamId: process.env.APPLE_TEAM_ID,
  keyId: process.env.APPLE_KEY_ID,
  bundleId: process.env.APPLE_BUNDLE_ID,
  privateKeyPath: process.env.APPLE_PRIVATE_KEY_PATH
};
```

## 🐛 Troubleshooting

### Common Issues:

#### 1. "Invalid Team ID"
- Ensure Team ID is exactly 10 characters
- Get it from Apple Developer Console membership page

#### 2. "Secret Key Invalid"
- Regenerate the secret key
- Ensure no extra spaces when copying/pasting
- Check that the .p8 file is valid

#### 3. "Client ID Mismatch"
- Ensure Bundle ID matches: `com.exp.aero.signin`
- Check Apple Developer Console Services ID configuration

#### 4. "Token Expired"
- Secret keys expire in 6 months
- Regenerate using `node generate_supabase_apple_secret.js`

## 📱 Flutter Integration

### Add to pubspec.yaml:
```yaml
dependencies:
  supabase_flutter: ^2.0.0
```

### Configure Apple Sign-In:
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static Future<void> signInWithApple() async {
    try {
      final AuthResponse response = await Supabase.instance.client.auth.signInWithOAuth(
        Provider.apple,
        redirectTo: 'your-app-scheme://login-callback/',
      );
      
      if (response.user != null) {
        print('Apple Sign-In successful!');
      }
    } catch (error) {
      print('Apple Sign-In error: $error');
    }
  }
}
```

## 🔗 Useful Links

- [Supabase Apple Authentication](https://supabase.com/docs/guides/auth/social-login/auth-apple)
- [Apple Sign-In Documentation](https://developer.apple.com/sign-in-with-apple/)
- [Apple Developer Console](https://developer.apple.com/account/)

## 📞 Support

If you encounter issues:
1. Check the troubleshooting section above
2. Verify your Apple Developer account settings
3. Ensure Supabase project is properly configured
4. Test with a simple Apple Sign-In flow first
