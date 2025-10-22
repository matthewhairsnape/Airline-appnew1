import 'dart:convert';
import 'package:airline_app/provider/user_data_provider.dart';
import 'package:airline_app/provider/auth_provider.dart';
import 'package:airline_app/screen/app_widgets/custom_snackbar.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:airline_app/screen/app_widgets/loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Login extends ConsumerStatefulWidget {
  const Login({super.key});

  @override
  ConsumerState<Login> createState() => _LoginState();
}

class _LoginState extends ConsumerState<Login> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _checkExistingAuth();

    // Listen to auth state changes
    ref.listenManual(authProvider, (previous, next) {
      next.when(
        data: (user) {
          if (user != null && mounted) {
            debugPrint('✅ Auth state changed: User logged in');
            setState(() {
              _isLoading = false;
            });
            Navigator.pushNamed(context, AppRoutes.startreviews);
          } else if (user == null && mounted) {
            debugPrint('❌ Auth state: No user data');
            setState(() {
              _isLoading = false;
            });
          }
        },
        loading: () {
          debugPrint('⏳ Auth state: Loading...');
          // Keep loading state
        },
        error: (error, stackTrace) {
          debugPrint('❌ Auth state error: $error');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            CustomSnackBar.error(
                context, 'Authentication error: ${error.toString()}');
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // Future<void> _initializeOtpless() async {
  //   if (Platform.isAndroid) {
  //     await _otplessFlutterPlugin.enableDebugLogging(true);
  //     await _otplessFlutterPlugin.initHeadless(appId);
  //     _otplessFlutterPlugin.setHeadlessCallback(onHeadlessResult);
  //   }
  //   _otplessFlutterPlugin.setWebviewInspectable(true);
  // } // Temporarily disabled

  Future<void> _checkExistingAuth() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final lastAccessTime = prefs.getInt('lastAccessTime');
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    // Check if 24 hours have passed since last access
    if (token != null &&
        lastAccessTime != null &&
        currentTime - lastAccessTime < Duration(hours: 24).inMilliseconds) {
      // Update last access time
      await prefs.setInt('lastAccessTime', currentTime);

      final userData = prefs.getString('userData');
      if (userData != null) {
        ref.read(userDataProvider.notifier).setUserData(json.decode(userData));
        if (mounted) {
          Navigator.pushNamed(context, AppRoutes.startreviews);
        }
      }
    } else {
      await prefs.clear();
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isSignUp) {
        debugPrint('📝 Starting sign up process...');
        await ref.read(authProvider.notifier).signUp(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              fullName: _nameController.text.trim().isNotEmpty
                  ? _nameController.text.trim()
                  : null,
            );
      } else {
        debugPrint('🔐 Starting sign in process...');
        await ref.read(authProvider.notifier).signIn(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );
      }

      debugPrint('✅ Auth method completed successfully');
    } catch (e) {
      debugPrint('❌ Authentication exception: $e');
      if (mounted) {
        CustomSnackBar.error(context, 'Authentication failed: ${e.toString()}');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      CustomSnackBar.error(context, 'Please enter your email address first.');
      return;
    }

    try {
      await ref
          .read(authProvider.notifier)
          .resetPassword(_emailController.text.trim());
      if (mounted) {
        CustomSnackBar.success(
            context, 'Password reset email sent! Check your inbox.');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.error(
            context, 'Failed to send reset email. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: LoadingWidget()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background image
          ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(76),
                  Colors.black.withAlpha(25)
                ],
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcATop,
            child: Image.asset(
              'assets/images/pixar-background.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          // Login form
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  SizedBox(height: screenSize.height * 0.1),
                  // Logo
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withAlpha(76),
                          spreadRadius: 2,
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withAlpha(25),
                          Colors.white.withAlpha(13),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: SvgPicture.asset(
                      'assets/icons/logo.svg',
                      colorFilter: ColorFilter.mode(
                        Colors.white.withAlpha(229),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Exp.aero",
                    style: AppStyles.textStyle_24_600.copyWith(
                      letterSpacing: 1.5,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Let's get flying",
                    style: AppStyles.textStyle_20_600.copyWith(
                      letterSpacing: 1.2,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withAlpha(153),
                          offset: const Offset(1, 2),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: screenSize.height * 0.08),
                  // Login form
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(240),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(51),
                          spreadRadius: 1,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _isSignUp ? "Create Account" : "Welcome Back",
                            style: AppStyles.textStyle_24_600.copyWith(
                              color: Colors.black87,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Name field (only for signup)
                          if (_isSignUp) ...[
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: "Full Name",
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              validator: (value) {
                                if (_isSignUp &&
                                    (value == null || value.trim().isEmpty)) {
                                  return 'Please enter your full name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Email field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: "Email",
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value.trim())) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: "Password",
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Login/Signup button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleAuth,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Text(
                                    _isSignUp ? "Create Account" : "Sign In",
                                    style: AppStyles.textStyle_18_600.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 16),

                          // Toggle between login and signup
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isSignUp = !_isSignUp;
                                _formKey.currentState?.reset();
                              });
                            },
                            child: Text(
                              _isSignUp
                                  ? "Already have an account? Sign In"
                                  : "Don't have an account? Sign Up",
                              style: AppStyles.textStyle_14_500.copyWith(
                                color: Colors.blue[600],
                              ),
                            ),
                          ),

                          // Forgot password (only for login)
                          if (!_isSignUp) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _handleForgotPassword,
                              child: Text(
                                "Forgot Password?",
                                style: AppStyles.textStyle_14_500.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: screenSize.height * 0.05),
                ],
              ),
            ),
          ),
          _isLoading
              ? const LoadingWidget()
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [],
                  ),
                ),
        ],
      ),
    );
  }
}
