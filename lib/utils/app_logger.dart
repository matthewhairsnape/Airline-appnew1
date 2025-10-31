import 'package:flutter/foundation.dart';

/// Production-ready logger that only logs in debug mode
/// Use this instead of debugPrint for production builds
class AppLogger {
  // Only log in debug mode
  static bool get _shouldLog => kDebugMode;

  /// Log debug messages (only in debug mode)
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (_shouldLog) {
      debugPrint('🔍 DEBUG: $message');
      if (error != null) {
        debugPrint('   Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('   Stack: $stackTrace');
      }
    }
  }

  /// Log info messages (only in debug mode)
  static void info(String message) {
    if (_shouldLog) {
      debugPrint('ℹ️ INFO: $message');
    }
  }

  /// Log warning messages (always logged)
  static void warning(String message, [Object? error]) {
    if (_shouldLog) {
      debugPrint('⚠️ WARNING: $message');
      if (error != null) {
        debugPrint('   Error: $error');
      }
    }
  }

  /// Log error messages (always logged in debug, consider crash reporting in production)
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('❌ ERROR: $message');
    if (error != null) {
      debugPrint('   Error: $error');
    }
    if (stackTrace != null && _shouldLog) {
      debugPrint('   Stack: $stackTrace');
    }
    // In production, you might want to send this to crash reporting service
    // e.g., Firebase Crashlytics, Sentry, etc.
  }

  /// Log success messages (only in debug mode)
  static void success(String message) {
    if (_shouldLog) {
      debugPrint('✅ SUCCESS: $message');
    }
  }
}

