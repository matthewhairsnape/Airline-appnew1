import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airline_app/provider/auth_provider.dart';
import 'package:airline_app/services/supabase_service.dart';
import 'package:airline_app/utils/app_styles.dart';

class AuthDebugScreen extends ConsumerStatefulWidget {
  const AuthDebugScreen({super.key});

  @override
  ConsumerState<AuthDebugScreen> createState() => _AuthDebugScreenState();
}

class _AuthDebugScreenState extends ConsumerState<AuthDebugScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isSignUp = false;
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _updateDebugInfo();
  }

  void _updateDebugInfo() {
    setState(() {
      _debugInfo = '''
Supabase Initialized: ${SupabaseService.isInitialized}
Auth State: ${ref.read(authProvider).user.when(
        data: (user) => user != null ? 'User: ${user.email}' : 'No user',
        loading: () => 'Loading...',
        error: (error, stackTrace) => 'Error: $error',
      )}
''';
    });
  }

  Future<void> _testSignUp() async {
    try {
      setState(() {
        _debugInfo += '\n📝 Testing sign up...\n';
      });

      await ref.read(authProvider.notifier).signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
      );

      setState(() {
        _debugInfo += '✅ Sign up completed\n';
      });
    } catch (e) {
      setState(() {
        _debugInfo += '❌ Sign up error: $e\n';
      });
    }
  }

  Future<void> _testSignIn() async {
    try {
      setState(() {
        _debugInfo += '\n🔐 Testing sign in...\n';
      });

      await ref.read(authProvider.notifier).signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      setState(() {
        _debugInfo += '✅ Sign in completed\n';
      });
    } catch (e) {
      setState(() {
        _debugInfo += '❌ Sign in error: $e\n';
      });
    }
  }

  Future<void> _testSignOut() async {
    try {
      setState(() {
        _debugInfo += '\n🚪 Testing sign out...\n';
      });

      await ref.read(authProvider.notifier).signOut();

      setState(() {
        _debugInfo += '✅ Sign out completed\n';
      });
    } catch (e) {
      setState(() {
        _debugInfo += '❌ Sign out error: $e\n';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auth Debug'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Debug Info
            Expanded(
              flex: 2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Debug Information',
                        style: AppStyles.textStyle_18_600,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            _debugInfo,
                            style: AppStyles.textStyle_12_500.copyWith(
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _updateDebugInfo,
                        child: const Text('Refresh Info'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Auth Form
            Expanded(
              flex: 3,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Test Authentication',
                        style: AppStyles.textStyle_18_600,
                      ),
                      const SizedBox(height: 16),
                      
                      // Toggle Sign Up/Sign In
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _isSignUp = true;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isSignUp ? Colors.blue[600] : Colors.grey[300],
                                foregroundColor: _isSignUp ? Colors.white : Colors.black,
                              ),
                              child: const Text('Sign Up'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _isSignUp = false;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: !_isSignUp ? Colors.blue[600] : Colors.grey[300],
                                foregroundColor: !_isSignUp ? Colors.white : Colors.black,
                              ),
                              child: const Text('Sign In'),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Name field (for sign up)
                      if (_isSignUp)
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      
                      if (_isSignUp) const SizedBox(height: 16),
                      
                      // Email field
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Password field
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSignUp ? _testSignUp : _testSignIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                foregroundColor: Colors.white,
                              ),
                              child: Text(_isSignUp ? 'Test Sign Up' : 'Test Sign In'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _testSignOut,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[600],
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Sign Out'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Auth State Display
            Expanded(
              flex: 1,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Auth State',
                        style: AppStyles.textStyle_16_600,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: authState.when(
                          data: (user) => Text(
                            user != null 
                                ? '✅ Logged in as: ${user.email ?? user.name ?? 'Unknown'}'
                                : '❌ Not logged in',
                            style: AppStyles.textStyle_14_500.copyWith(
                              color: user != null ? Colors.green[700] : Colors.red[700],
                            ),
                          ),
                          loading: () => const Text('⏳ Loading...'),
                          error: (error, stackTrace) => Text(
                            '❌ Error: $error',
                            style: AppStyles.textStyle_14_500.copyWith(
                              color: Colors.red[700],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
