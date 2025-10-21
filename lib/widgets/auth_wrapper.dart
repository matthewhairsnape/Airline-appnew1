import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airline_app/provider/auth_provider.dart';
import 'package:airline_app/screen/logIn/log_in.dart';
import 'package:airline_app/screen/login/skip_screen.dart';

class AuthWrapper extends ConsumerWidget {
  final Widget child;
  
  const AuthWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    
    return authState.when(
      data: (user) {
        if (user != null) {
          // User is authenticated, show the main app
          return child;
        } else {
          // User is not authenticated, show login screen
          return const Login();
        }
      },
      loading: () {
        // Show loading screen while checking authentication
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
      error: (error, stackTrace) {
        // Show error screen or fallback to login
        debugPrint('Auth error: $error');
        return const Login();
      },
    );
  }
}

// Widget to check if user should see onboarding
class OnboardingWrapper extends ConsumerWidget {
  final Widget child;
  
  const OnboardingWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    
    return authState.when(
      data: (user) {
        if (user != null) {
          // User is authenticated, show the main app
          return child;
        } else {
          // User is not authenticated, show onboarding/skip screen
          return const SkipScreen();
        }
      },
      loading: () {
        // Show loading screen while checking authentication
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
      error: (error, stackTrace) {
        // Show error screen or fallback to onboarding
        debugPrint('Auth error: $error');
        return const SkipScreen();
      },
    );
  }
}
