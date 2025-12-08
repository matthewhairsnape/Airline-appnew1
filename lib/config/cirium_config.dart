/// Cirium API Configuration
/// 
/// ⚠️ PRODUCTION: These should be moved to environment variables or secure storage
/// For production, use String.fromEnvironment or secure storage instead of hardcoded values
class CiriumConfig {
  // ⚠️ SECURITY: Remove hardcoded values in production - use environment variables
  // These are fallback values - prefer using environment variables
  static const String _defaultAppId = '7f155a19';
  static const String _defaultAppKey = '6c5f44eeeb23a68f311a6321a96fcbdf';

  // Load from environment variables (preferred for production)
  static String get appIdFromEnv => const String.fromEnvironment(
        'CIRIUM_APP_ID',
        defaultValue: _defaultAppId,
      );

  static String get appKeyFromEnv => const String.fromEnvironment(
        'CIRIUM_APP_KEY',
        defaultValue: _defaultAppKey,
      );

  // Use environment values if available, otherwise fallback to defaults
  static String get appId => appIdFromEnv;
  static String get appKey => appKeyFromEnv;

  // Validation
  static bool get isConfigured =>
      appIdFromEnv != 'YOUR_CIRIUM_APP_ID' &&
      appKeyFromEnv != 'YOUR_CIRIUM_APP_KEY';
  
  // Check if using environment variables (more secure)
  static bool get isUsingEnvironmentVariables =>
      appIdFromEnv != _defaultAppId || appKeyFromEnv != _defaultAppKey;
}
