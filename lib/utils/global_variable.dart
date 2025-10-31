// ⚠️ PRODUCTION: Move sensitive values to environment variables or secure config

// API URLs
const apiUrl = "https://airlinereview-b835007a0bbc.herokuapp.com";
const backendUrl = "airlinereview-b835007a0bbc.herokuapp.com";
const String appId = "bzpl0offchgcjrm8a4sj";
const chatbotUrl = "https://airline-chatbot-ae62e84c30ae.herokuapp.com";

// Cirium API Configuration
// ⚠️ SECURITY: Use environment variables in production instead of hardcoded values
const String ciriumUrl =
    "https://api.flightstats.com/flex/flightstatus/rest/v2";
// These should be loaded from environment variables in production
// ⚠️ NOTE: In production, set these via build arguments:
// flutter build apk --dart-define=CIRIUM_APP_ID=your_id --dart-define=CIRIUM_APP_KEY=your_key
const String ciriumAppId = String.fromEnvironment(
  'CIRIUM_APP_ID',
  defaultValue: "7f155a19", // Fallback - remove in production
);
const String ciriumAppKey = String.fromEnvironment(
  'CIRIUM_APP_KEY',
  defaultValue: "6c5f44eeeb23a68f311a6321a96fcbdf", // Fallback - remove in production
);

// AWS credentials - loaded from environment variables
const accessKeyId =
    String.fromEnvironment('AWS_ACCESS_KEY_ID', defaultValue: '');
const secretAccessKey =
    String.fromEnvironment('AWS_SECRET_ACCESS_KEY', defaultValue: '');
const region = "eu-north-1";
const bucketName = "airsharereview";
