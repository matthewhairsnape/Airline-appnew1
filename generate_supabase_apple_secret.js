const jwt = require('jsonwebtoken');
const fs = require('fs');

// Apple Developer Configuration for Supabase
const APPLE_CONFIG = {
  // Your Apple Developer Team ID (10 characters)
  // Get this from: https://developer.apple.com/account/#!/membership/
  teamId: '4SS8VUUV4W',
  
  // Your Apple Developer Key ID (10 characters) - from the filename D738P9CC7G
  keyId: 'D738P9CC7G',
  
  // Your App Bundle ID - this should match what you see in the Supabase interface
  bundleId: 'com.exp.aero.signin',
  
  // Private key file path
  privateKeyPath: './AuthKey_D738P9CC7G.p8'
};

/**
 * Generate Apple JWT Token for Supabase Apple Sign-In
 * This token is used as the "Secret Key (for OAuth)" in Supabase
 */
function generateSupabaseAppleSecret() {
  try {
    console.log('🍎 Generating Apple Secret Key for Supabase...\n');
    
    // Read the private key file
    const privateKey = fs.readFileSync(APPLE_CONFIG.privateKeyPath, 'utf8');
    console.log('✅ Private key loaded successfully');
    
    // JWT payload for Supabase Apple Sign-In
    const payload = {
      iss: APPLE_CONFIG.teamId,
      iat: Math.floor(Date.now() / 1000), // Current timestamp
      exp: Math.floor(Date.now() / 1000) + (60 * 60 * 24 * 180), // Expires in 180 days (6 months)
      aud: 'https://appleid.apple.com',
      sub: APPLE_CONFIG.bundleId
    };
    
    console.log('📋 JWT Payload:', JSON.stringify(payload, null, 2));
    
    // JWT header
    const header = {
      alg: 'ES256',
      kid: APPLE_CONFIG.keyId
    };
    
    console.log('📋 JWT Header:', JSON.stringify(header, null, 2));
    
    // Generate the JWT token
    const token = jwt.sign(payload, privateKey, {
      algorithm: 'ES256',
      header: header
    });
    
    console.log('\n🎉 Apple Secret Key Generated for Supabase!');
    console.log('=' .repeat(80));
    console.log(token);
    console.log('=' .repeat(80));
    
    // Save token to file
    const tokenFilePath = './supabase_apple_secret.txt';
    fs.writeFileSync(tokenFilePath, token);
    console.log(`\n💾 Secret key saved to: ${tokenFilePath}`);
    
    // Display configuration info
    console.log('\n📊 Supabase Configuration:');
    console.log(`- Client ID: ${APPLE_CONFIG.bundleId}`);
    console.log(`- Secret Key: ${token.substring(0, 20)}...${token.substring(token.length - 20)}`);
    console.log(`- Team ID: ${APPLE_CONFIG.teamId}`);
    console.log(`- Key ID: ${APPLE_CONFIG.keyId}`);
    console.log(`- Expires: ${new Date(payload.exp * 1000).toISOString()}`);
    
    console.log('\n🔧 Supabase Setup Instructions:');
    console.log('1. Go to your Supabase Dashboard');
    console.log('2. Navigate to Authentication > Providers > Apple');
    console.log('3. Enable Apple provider');
    console.log(`4. Set Client ID: ${APPLE_CONFIG.bundleId}`);
    console.log(`5. Set Secret Key: ${token}`);
    console.log('6. Save the configuration');
    
    return token;
    
  } catch (error) {
    console.error('❌ Error generating Apple Secret Key:', error.message);
    
    if (error.code === 'ENOENT') {
      console.error('💡 Make sure the AuthKey_D738P9CC7G.p8 file is in the same directory');
    }
    
    throw error;
  }
}

/**
 * Verify the generated JWT token
 */
function verifySecret(token) {
  try {
    console.log('\n🔍 Verifying Apple Secret Key...');
    
    // Decode without verification (just to see the payload)
    const decoded = jwt.decode(token, { complete: true });
    
    console.log('✅ Secret key decoded successfully');
    console.log('📋 Decoded Header:', JSON.stringify(decoded.header, null, 2));
    console.log('📋 Decoded Payload:', JSON.stringify(decoded.payload, null, 2));
    
    return decoded;
  } catch (error) {
    console.error('❌ Error verifying secret key:', error.message);
    throw error;
  }
}

// Main execution
if (require.main === module) {
  console.log('🍎 Apple Secret Key Generator for Supabase');
  console.log('==========================================\n');
  
  // Check if private key file exists
  if (!fs.existsSync(APPLE_CONFIG.privateKeyPath)) {
    console.error('❌ Private key file not found:', APPLE_CONFIG.privateKeyPath);
    console.log('💡 Please place your AuthKey_D738P9CC7G.p8 file in this directory');
    process.exit(1);
  }
  
  // Check configuration
  if (APPLE_CONFIG.teamId === 'YOUR_TEAM_ID_HERE') {
    console.error('❌ Please update your Team ID in the configuration');
    console.log('💡 Get your Team ID from: https://developer.apple.com/account/#!/membership/');
    console.log('💡 Update the teamId in this script or in generate_apple_jwt.js');
    process.exit(1);
  }
  
  try {
    // Generate the secret key
    const secret = generateSupabaseAppleSecret();
    
    // Verify the secret key
    verifySecret(secret);
    
    console.log('\n🎯 Next Steps:');
    console.log('1. Copy the secret key above');
    console.log('2. Go to Supabase Dashboard > Authentication > Providers > Apple');
    console.log('3. Paste the secret key in the "Secret Key (for OAuth)" field');
    console.log(`4. Set Client ID to: ${APPLE_CONFIG.bundleId}`);
    console.log('5. Enable Apple Sign-In provider');
    console.log('6. Test the authentication flow');
    
  } catch (error) {
    console.error('\n💥 Failed to generate Apple Secret Key');
    process.exit(1);
  }
}

module.exports = {
  generateSupabaseAppleSecret,
  verifySecret,
  APPLE_CONFIG
};
