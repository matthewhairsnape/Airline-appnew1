const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

console.log('🍎 Apple Sign-In Setup for Supabase');
console.log('===================================\n');

console.log('To get your Apple Developer Team ID:');
console.log('1. Go to: https://developer.apple.com/account/#!/membership/');
console.log('2. Look for "Team ID" (10 characters like ABC123DEF4)');
console.log('3. Copy it and paste below\n');

rl.question('Enter your Apple Developer Team ID: ', (teamId) => {
  if (teamId && teamId.length === 10) {
    console.log(`\n✅ Team ID: ${teamId}`);
    
    // Update the configuration in both files
    updateConfigFiles(teamId);
    
    console.log('\n🎉 Configuration updated successfully!');
    console.log('\nNext steps:');
    console.log('1. Run: node generate_supabase_apple_secret.js');
    console.log('2. Copy the generated secret key');
    console.log('3. Paste it in Supabase Dashboard > Authentication > Providers > Apple');
    console.log(`4. Set Client ID to: com.exp.aero.signin`);
    
  } else {
    console.log('\n❌ Invalid Team ID. Please enter a 10-character Team ID.');
  }
  
  rl.close();
});

function updateConfigFiles(teamId) {
  const fs = require('fs');
  
  // Update generate_apple_jwt.js
  try {
    let content = fs.readFileSync('generate_apple_jwt.js', 'utf8');
    content = content.replace('teamId: \'YOUR_TEAM_ID_HERE\'', `teamId: '${teamId}'`);
    fs.writeFileSync('generate_apple_jwt.js', content);
    console.log('✅ Updated generate_apple_jwt.js');
  } catch (error) {
    console.log('⚠️ Could not update generate_apple_jwt.js');
  }
  
  // Update generate_supabase_apple_secret.js
  try {
    let content = fs.readFileSync('generate_supabase_apple_secret.js', 'utf8');
    content = content.replace('teamId: \'YOUR_TEAM_ID_HERE\'', `teamId: '${teamId}'`);
    fs.writeFileSync('generate_supabase_apple_secret.js', content);
    console.log('✅ Updated generate_supabase_apple_secret.js');
  } catch (error) {
    console.log('⚠️ Could not update generate_supabase_apple_secret.js');
  }
}
