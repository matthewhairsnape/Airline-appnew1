// Example configuration for Apple JWT Generator
// Copy this file to config.js and update with your actual values

module.exports = {
  // Your Apple Developer Team ID (10 characters)
  // Get this from: https://developer.apple.com/account/#!/membership/
  teamId: 'YOUR_TEAM_ID_HERE',
  
  // Your Apple Developer Key ID (10 characters)
  // This comes from your .p8 filename: AuthKey_D738P9CC7G.p8
  keyId: 'D738P9CC7G',
  
  // Your App Bundle ID (reverse domain notation)
  // Example: com.yourcompany.airlineapp
  bundleId: 'com.yourcompany.airlineapp',
  
  // Path to your private key file
  privateKeyPath: './AuthKey_D738P9CC7G.p8'
};

// Instructions:
// 1. Copy this file: cp config.example.js config.js
// 2. Update the values above with your actual Apple Developer details
// 3. Run: node generate_apple_jwt.js
