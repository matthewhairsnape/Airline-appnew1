class CiriumConfig {
  // Replace these with your actual Cirium API credentials
  static const String appId = '7f155a19';
  static const String appKey = '6c5f44eeeb23a68f311a6321a96fcbdf';
  
  // You can also load these from environment variables or a secure config file
  static String get appIdFromEnv => const String.fromEnvironment(
    'CIRIUM_APP_ID',
    defaultValue: appId,
  );
  
  static String get appKeyFromEnv => const String.fromEnvironment(
    'CIRIUM_APP_KEY',
    defaultValue: appKey,
  );
  
  // Validation
  static bool get isConfigured => 
      appIdFromEnv != 'YOUR_CIRIUM_APP_ID' && 
      appKeyFromEnv != 'YOUR_CIRIUM_APP_KEY';
}
