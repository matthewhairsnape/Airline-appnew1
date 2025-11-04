import 'dart:io';
import 'package:airline_app/screen/app_widgets/main_button.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:airline_app/provider/auth_provider.dart';
import 'package:airline_app/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class SkipScreen extends ConsumerStatefulWidget {
  const SkipScreen({super.key});

  @override
  ConsumerState<SkipScreen> createState() => _SkipScreenState();
}

class _SkipScreenState extends ConsumerState<SkipScreen> {
  int selectedIndex = 0;
  final PageController _pageController = PageController();
  bool _isLoading = false;
  bool _hasNavigated = false; // Prevent double navigation
  DateTime? _lastNavigationAttempt; // Track navigation attempts for debouncing

  final List<String> titleList = [
    "Unbiased Reviews",
    "Shared Flight Feedback",
    "Let's get started"
  ];

  final List<String> contentList = [
    "Explore real, verified reviews to help you make informed travel choices",
    "Your voice matters! Share your experiences and help improve air travel for everyone",
    "Real, verified reviews and live flight feedback — all in one place."
  ];

  @override
  void initState() {
    super.initState();

    // Set loading state immediately to prevent showing SkipScreen content
    setState(() {
      _isLoading = true;
    });

    // Check auth immediately using multiple methods
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Method 1: Check Supabase session directly (fastest, synchronous)
    try {
      final session = SupabaseService.client.auth.currentSession;
      if (session?.user != null && mounted && !_hasNavigated) {
        debugPrint('✅ Found Supabase session, navigating immediately');
        _navigateToStartReviews();
        return;
      }
    } catch (e) {
      debugPrint('⚠️ Error checking Supabase session: $e');
    }

    // Method 2: Wait for first frame, then check auth provider
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted || _hasNavigated) return;

    // Check auth provider state
    final authState = ref.read(authProvider);
    
    // If auth is initialized and user exists, navigate
    if (authState.isInitialized) {
      final user = authState.user.valueOrNull;
      if (user != null && mounted && !_hasNavigated) {
        debugPrint('✅ Auth provider initialized with user, navigating');
        _navigateToStartReviews();
        return;
      } else if (user == null && mounted) {
        // User is not logged in, show SkipScreen
        setState(() {
          _isLoading = false;
        });
      }
    }

    // Method 3: Listen to auth provider for changes (if still loading)
    if (!authState.isInitialized || authState.user.isLoading) {
      // Set up listener to catch when auth becomes ready
      _setupAuthListener();
      
      // Also poll periodically until initialized
      _pollAuthState();
    } else {
      // Already initialized, set up listener for future changes
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && !_hasNavigated) {
          _setupAuthListener();
        }
      });
    }
  }

  void _pollAuthState() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted || _hasNavigated) return;
      
      final authState = ref.read(authProvider);
      if (authState.isInitialized) {
        final user = authState.user.valueOrNull;
        if (user != null) {
          debugPrint('✅ Auth initialized with user (poll), navigating');
          _navigateToStartReviews();
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        // Still not initialized, poll again
        _pollAuthState();
      }
    });
  }

  void _navigateToStartReviews() {
    if (_hasNavigated || !mounted) return;
    
    final now = DateTime.now();
    if (_lastNavigationAttempt != null) {
      final timeSinceLastAttempt = now.difference(_lastNavigationAttempt!);
      if (timeSinceLastAttempt.inMilliseconds < 500) {
        return; // Debounce
      }
    }
    
    _hasNavigated = true;
    _lastNavigationAttempt = now;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.startreviews);
    });
  }

  void _setupAuthListener() {
    // Listen to auth state changes
    ref.listenManual(authProvider, (previous, next) {
      // Check if auth is now initialized with a user
      if (next.isInitialized && next.user.valueOrNull != null && !_hasNavigated) {
        debugPrint('✅ Auth listener: User found, navigating');
        _navigateToStartReviews();
        return;
      }
      
      // Handle new login (transition from null to user)
      final previousUser = previous?.user.valueOrNull;
      next.user.when(
        data: (user) {
          // Only navigate if this is a NEW login (previous state had no user)
          // AND we haven't navigated yet
          if (user != null && 
              mounted && 
              !_hasNavigated && 
              previousUser == null) {
            debugPrint('✅ Auth state changed: User logged in (navigating to startreviews)');
            _navigateToStartReviews();
          } else if (user == null && mounted) {
            // User logged out or no user
            setState(() {
              _isLoading = false;
            });
          }
        },
        loading: () {
          debugPrint('⏳ Auth state: Loading...');
        },
        error: (error, stackTrace) {
          debugPrint('❌ Auth state error: $error');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _signInWithApple() async {
    if (!Platform.isIOS) {
      // Skip Apple Sign-In on non-iOS platforms
      if (!_hasNavigated) {
        final now = DateTime.now();
        if (_lastNavigationAttempt != null) {
          final timeSinceLastAttempt = now.difference(_lastNavigationAttempt!);
          if (timeSinceLastAttempt.inMilliseconds < 500) {
            return; // Debounce
          }
        }
        _hasNavigated = true;
        _lastNavigationAttempt = now;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, AppRoutes.startreviews);
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      debugPrint('🍎 Apple Sign-In successful: ${credential.userIdentifier}');

      // Sign in with Supabase using Apple credentials
      await ref.read(authProvider.notifier).signInWithApple(
            idToken: credential.identityToken!,
            accessToken: credential.authorizationCode!,
            email: credential.email,
            fullName:
                credential.givenName != null && credential.familyName != null
                    ? '${credential.givenName} ${credential.familyName}'
                    : null,
          );

      // Navigation will be handled by the auth provider listener
    } catch (e) {
      debugPrint('❌ Apple Sign-In failed: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _continueAsGuest() {
    if (!_hasNavigated) {
      final now = DateTime.now();
      if (_lastNavigationAttempt != null) {
        final timeSinceLastAttempt = now.difference(_lastNavigationAttempt!);
        if (timeSinceLastAttempt.inMilliseconds < 500) {
          return; // Debounce
        }
      }
      _hasNavigated = true;
      _lastNavigationAttempt = now;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.startreviews);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    // Show loading screen while checking auth state (prevents flash of SkipScreen)
    if (_isLoading && !_hasNavigated) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // Reactively check auth state as backup
    final authState = ref.watch(authProvider);
    
    // Handle auth state changes reactively
    return authState.user.when(
      data: (user) {
        // If user is logged in, navigate immediately
        if (user != null && mounted && !_hasNavigated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _hasNavigated) return;
            _navigateToStartReviews();
          });
          // Return loading screen while navigation happens
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // User is not logged in, show SkipScreen content
        return _buildSkipScreenContent(screenSize);
      },
      loading: () {
        // Auth state is still loading, show loading screen
        return Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
      error: (error, stackTrace) {
        // Error loading auth, show SkipScreen
        debugPrint('⚠️ Auth state error: $error');
        return _buildSkipScreenContent(screenSize);
      },
    );
  }

  Widget _buildSkipScreenContent(Size screenSize) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => selectedIndex = index),
            itemCount: 3,
            itemBuilder: (context, index) => _buildPage(index, screenSize),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomSheet(screenSize),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index, Size screenSize) {
    return Stack(
      children: [
        Container(
          width: screenSize.width,
          height: screenSize.height,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/skipscreen$index.jpg'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withAlpha(127),
                BlendMode.darken,
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withAlpha(127),
              ],
              stops: const [0.5, 1.0],
            ),
          ),
        ),
        Positioned(
          left: 35,
          top: screenSize.height * 0.15,
          child: SizedBox(
            width: screenSize.width - 70,
            child: _buildHeaderText(index),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSheet(Size screenSize) {
    return Container(
      height: screenSize.height * 0.45, // Slightly increased height
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, left: 28, right: 28, bottom: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 4,
                    width: 45,
                    decoration: BoxDecoration(
                      color: const Color(0xff97A09C),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    titleList[selectedIndex],
                    style: AppStyles.textStyle_24_600.copyWith(
                      letterSpacing: 1.0,
                      fontSize: 24, // Slightly reduced font size
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    contentList[selectedIndex],
                    style: AppStyles.textStyle_15_400.copyWith(
                      height: 1.5,
                      fontSize: 15, // Slightly reduced font size
                      color: Colors.black87,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _buildPageIndicator(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: _buildNavigationButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          height: 6,
          width: selectedIndex == index ? 32 : 6,
          decoration: BoxDecoration(
            color: selectedIndex == index
                ? AppStyles.mainColor
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
            boxShadow: selectedIndex == index
                ? [
                    BoxShadow(
                      color: AppStyles.mainColor.withAlpha(104),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButton() {
    // Show Next button for first 2 pages, auth buttons on last page
    if (selectedIndex < 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: MainButton(
          text: "Next",
          color: Colors.black,
          onPressed: () {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            );
          },
        ),
      );
    }

    // On last page, show Apple Sign-In and Continue as Guest
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: CircularProgressIndicator(),
            )
          else if (Platform.isIOS)
            SignInWithAppleButton(
              onPressed: _signInWithApple,
              height: 50,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            )
          else
            MainButton(
              text: 'Get Started',
              color: Colors.black,
              onPressed: _continueAsGuest,
            ),

          const SizedBox(height: 12),

          // Continue as Guest button
          TextButton(
            onPressed: _continueAsGuest,
            child: Text(
              'Continue as Guest',
              style: AppStyles.textStyle_14_600.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderText(int index) {
    const baseStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      height: 1.1,
      shadows: [
        Shadow(
          offset: Offset(2, 2),
          blurRadius: 8,
          color: Colors.black45,
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Experience',
          style: baseStyle.copyWith(
            fontSize: 54,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          'Feedback',
          style: baseStyle.copyWith(
            fontSize: 54,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'that takes',
          style: baseStyle.copyWith(
            fontSize: 40,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        Text(
          'Flight',
          style: baseStyle.copyWith(
            fontSize: 64,
            letterSpacing: 3,
            fontWeight: FontWeight.w900,
            shadows: const [
              Shadow(
                offset: Offset(3, 3),
                blurRadius: 10,
                color: Colors.black54,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
