import 'package:flutter/material.dart';

/// Global navigation service to handle navigation from anywhere
/// This avoids circular imports and provides a centralized navigation solution
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Navigate to a route by name
  static Future<dynamic>? navigateTo(String routeName, {Object? arguments}) {
    final navigatorState = navigatorKey.currentState;
    if (navigatorState != null && navigatorState.mounted) {
      return navigatorState.pushNamed(routeName, arguments: arguments);
    }
    return null;
  }

  /// Navigate to a route and remove all previous routes
  static void navigateToAndRemoveUntil(String routeName, {Object? arguments}) {
    final navigatorState = navigatorKey.currentState;
    if (navigatorState != null && navigatorState.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          navigatorState.pushNamedAndRemoveUntil(
            routeName,
            (route) => false,
            arguments: arguments,
          );
        } catch (e) {
          debugPrint('❌ Navigation error: $e');
        }
      });
    }
  }

  /// Navigate to My Journey screen
  static void navigateToMyJourney({int retryCount = 0}) {
    try {
      final navigatorState = navigatorKey.currentState;
      if (navigatorState != null && navigatorState.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            navigatorState.pushNamedAndRemoveUntil(
              '/my-journey',
              (route) => false,
            );
            debugPrint('✅ Navigated to My Journey screen');
          } catch (e) {
            debugPrint('❌ Error during navigation: $e');
            if (retryCount < 3) {
              Future.delayed(const Duration(milliseconds: 500), () {
                navigateToMyJourney(retryCount: retryCount + 1);
              });
            }
          }
        });
      } else {
        debugPrint('⚠️ Navigator state not available (retry: $retryCount)');
        if (retryCount < 5) {
          Future.delayed(const Duration(milliseconds: 500), () {
            navigateToMyJourney(retryCount: retryCount + 1);
          });
        } else {
          debugPrint('❌ Failed to navigate after 5 retries');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error navigating to My Journey: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
}

