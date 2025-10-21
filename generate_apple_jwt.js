const jwt = require('jsonwebtoken');
const fs = require('fs');
const path = require('path');

// Apple Developer Configuration for Supabase
const APPLE_CONFIG = {
  // Your Apple Developer Team ID (10 characters)
  teamId: '4SS8VUUV4W',
  
  // Your Apple Developer Key ID (10 characters) - from the filename D738P9CC7G
  keyId: 'D738P9CC7G',
  
  // Your App Bundle ID - this should match what you see in the interface
  bundleId: 'com.exp.aero.signin',
  
  // Private key file path
  privateKeyPath: './AuthKey_D738P9CC7G.p8'
};

/**
 * Generate Apple JWT Token for Push Notifications
 * This token is used to authenticate with Apple's APNs servers
 */
function generateAppleJWT() {
  try {
    console.log('🍎 Generating Apple JWT Token...\n');
    
    // Read the private key file
    const privateKey = fs.readFileSync(APPLE_CONFIG.privateKeyPath, 'utf8');
    console.log('✅ Private key loaded successfully');
    
    // JWT payload
    const payload = {
      iss: APPLE_CONFIG.teamId,
      iat: Math.floor(Date.now() / 1000), // Current timestamp
      exp: Math.floor(Date.now() / 1000) + (60 * 60 * 24), // Expires in 24 hours
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
    
    console.log('\n🎉 Apple JWT Token Generated Successfully!');
    console.log('=' .repeat(60));
    console.log(token);
    console.log('=' .repeat(60));
    
    // Save token to file
    const tokenFilePath = './apple_jwt_token.txt';
    fs.writeFileSync(tokenFilePath, token);
    console.log(`\n💾 Token saved to: ${tokenFilePath}`);
    
    // Display token info
    console.log('\n📊 Token Information:');
    console.log(`- Team ID: ${APPLE_CONFIG.teamId}`);
    console.log(`- Key ID: ${APPLE_CONFIG.keyId}`);
    console.log(`- Bundle ID: ${APPLE_CONFIG.bundleId}`);
    console.log(`- Algorithm: ES256`);
    console.log(`- Expires: ${new Date((payload.iat + 60 * 60 * 24) * 1000).toISOString()}`);
    
    return token;
    
  } catch (error) {
    console.error('❌ Error generating Apple JWT:', error.message);
    
    if (error.code === 'ENOENT') {
      console.error('💡 Make sure the AuthKey_D738P9CC7G.p8 file is in the same directory');
    }
    
    throw error;
  }
}

/**
 * Verify the generated JWT token
 */
function verifyJWT(token) {
  try {
    console.log('\n🔍 Verifying JWT token...');
    
    // Decode without verification (just to see the payload)
    const decoded = jwt.decode(token, { complete: true });
    
    console.log('✅ Token decoded successfully');
    console.log('📋 Decoded Header:', JSON.stringify(decoded.header, null, 2));
    console.log('📋 Decoded Payload:', JSON.stringify(decoded.payload, null, 2));
    
    return decoded;
  } catch (error) {
    console.error('❌ Error verifying JWT:', error.message);
    throw error;
  }
}

/**
 * Generate a new token with custom expiration
 */
function generateTokenWithCustomExpiration(hours = 24) {
  try {
    console.log(`\n🕐 Generating token with ${hours} hour expiration...`);
    
    const privateKey = fs.readFileSync(APPLE_CONFIG.privateKeyPath, 'utf8');
    
    const payload = {
      iss: APPLE_CONFIG.teamId,
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + (60 * 60 * hours),
      aud: 'https://appleid.apple.com',
      sub: APPLE_CONFIG.bundleId
    };
    
    const token = jwt.sign(payload, privateKey, {
      algorithm: 'ES256',
      header: {
        alg: 'ES256',
        kid: APPLE_CONFIG.keyId
      }
    });
    
    console.log(`✅ Token generated with ${hours} hour expiration`);
    console.log(`- Expires: ${new Date(payload.exp * 1000).toISOString()}`);
    
    return token;
  } catch (error) {
    console.error('❌ Error generating custom token:', error.message);
    throw error;
  }
}

// Main execution
if (require.main === module) {
  console.log('🍎 Apple JWT Token Generator');
  console.log('=============================\n');
  
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
    process.exit(1);
  }
  
  try {
    // Generate the main token
    const token = generateAppleJWT();
    
    // Verify the token
    verifyJWT(token);
    
    console.log('\n🎯 Usage Instructions:');
    console.log('1. Use this JWT token as Bearer token in APNs requests');
    console.log('2. Token expires in 24 hours - regenerate as needed');
    console.log('3. For production, store the private key securely');
    console.log('4. Update the configuration with your actual Team ID and Bundle ID');
    
  } catch (error) {
    console.error('\n💥 Failed to generate Apple JWT token');
    process.exit(1);
  }
}

module.exports = {
  generateAppleJWT,
  verifyJWT,
  generateTokenWithCustomExpiration,
  APPLE_CONFIG
};
