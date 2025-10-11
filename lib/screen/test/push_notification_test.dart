import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airline_app/services/push_notification_service.dart';
import 'package:airline_app/provider/auth_provider.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:airline_app/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PushNotificationTestScreen extends ConsumerStatefulWidget {
  const PushNotificationTestScreen({super.key});

  @override
  ConsumerState<PushNotificationTestScreen> createState() => _PushNotificationTestScreenState();
}

class _PushNotificationTestScreenState extends ConsumerState<PushNotificationTestScreen> {
  String? _fcmToken;
  bool _isLoading = false;
  String? _savedTokenFromDB;
  bool _isCheckingDB = false;
  String _testResults = '';
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _getFCMToken();
    _checkDatabaseToken();
    _setupNotificationListeners();
  }

  void _setupNotificationListeners() {
    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      setState(() {
        _notificationCount++;
        _testResults += '\n🔔 Foreground notification received:\n';
        _testResults += 'Title: ${message.notification?.title}\n';
        _testResults += 'Body: ${message.notification?.body}\n';
        _testResults += 'Data: ${message.data}\n';
        _testResults += 'Time: ${DateTime.now()}\n';
      });
    });

    // Listen for notification taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      setState(() {
        _testResults += '\n🔔 Notification tapped (app was in background):\n';
        _testResults += 'Title: ${message.notification?.title}\n';
        _testResults += 'Data: ${message.data}\n';
        _testResults += 'Time: ${DateTime.now()}\n';
      });
    });
  }

  Future<void> _getFCMToken() async {
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('🔔 Getting FCM token...');
      _fcmToken = PushNotificationService.fcmToken;
      debugPrint('🔔 FCM token obtained: ${_fcmToken?.substring(0, 20)}...');
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting FCM token: $e')),
        );
      }
    }
  }

  Future<void> _saveTokenForCurrentUser() async {
    try {
      debugPrint('🔔 Attempting to save FCM token for current user...');
      final authState = ref.read(authProvider);
      authState.user.when(
        data: (user) async {
          if (user != null) {
            debugPrint('🔔 User found: ${user.id}, saving FCM token...');
            await PushNotificationService.saveTokenForUser(user.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ FCM token saved successfully!')),
              );
            }
          } else {
            debugPrint('❌ No user logged in');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('❌ No user logged in')),
              );
            }
          }
        },
        loading: () {
          debugPrint('⏳ Auth state loading...');
        },
        error: (error, stackTrace) {
          debugPrint('❌ Auth error: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('❌ Error: $error')),
            );
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error saving token: $e')),
        );
      }
    }
  }

  Future<void> _subscribeToTopic() async {
    try {
      await PushNotificationService.subscribeToTopic('airline_updates');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscribed to airline_updates topic')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error subscribing to topic: $e')),
        );
      }
    }
  }

  Future<void> _unsubscribeFromTopic() async {
    try {
      await PushNotificationService.unsubscribeFromTopic('airline_updates');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unsubscribed from airline_updates topic')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error unsubscribing from topic: $e')),
        );
      }
    }
  }

  Future<void> _checkDatabaseToken() async {
    setState(() {
      _isCheckingDB = true;
    });

    try {
      final authState = ref.read(authProvider);
      authState.user.when(
        data: (user) async {
          if (user != null) {
            final response = await Supabase.instance.client
                .from('users')
                .select('fcm_token')
                .eq('id', user.id)
                .single();
            
            setState(() {
              _savedTokenFromDB = response['fcm_token'];
              _isCheckingDB = false;
            });
          } else {
            setState(() {
              _savedTokenFromDB = null;
              _isCheckingDB = false;
            });
          }
        },
        loading: () {
          setState(() {
            _isCheckingDB = false;
          });
        },
        error: (error, stackTrace) {
          setState(() {
            _savedTokenFromDB = null;
            _isCheckingDB = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _savedTokenFromDB = null;
        _isCheckingDB = false;
      });
    }
  }

  Future<void> _testNotificationPermissions() async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      setState(() {
        _testResults += '\n🔔 Notification Permissions:\n';
        _testResults += 'Authorization Status: ${settings.authorizationStatus}\n';
        _testResults += 'Alert: ${settings.alert}\n';
        _testResults += 'Badge: ${settings.badge}\n';
        _testResults += 'Sound: ${settings.sound}\n';
        _testResults += 'Time: ${DateTime.now()}\n';
      });
    } catch (e) {
      setState(() {
        _testResults += '\n❌ Error checking permissions: $e\n';
      });
    }
  }

  Future<void> _simulateLocalNotification() async {
    setState(() {
      _notificationCount++;
      _testResults += '\n🔔 Simulated Local Notification:\n';
      _testResults += 'Title: Test Notification\n';
      _testResults += 'Body: This is a test notification from the app\n';
      _testResults += 'Time: ${DateTime.now()}\n';
      _testResults += 'Note: This is a simulation - not a real push notification\n';
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔔 Simulated notification logged to test results'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _clearTestResults() {
    setState(() {
      _testResults = '';
      _notificationCount = 0;
    });
  }

  void _showFirebaseConsoleInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Firebase Console Testing'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('To test push notifications via Firebase Console:'),
              const SizedBox(height: 16),
              const Text('1. Go to Firebase Console (console.firebase.google.com)'),
              const Text('2. Select your project'),
              const Text('3. Go to Cloud Messaging'),
              const Text('4. Click "Send your first message"'),
              const Text('5. Enter notification details:'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Title: Test Notification'),
                    Text('Body: Testing push notifications'),
                    Text('Target: Single device'),
                    Text('FCM registration token: ${_fcmToken ?? "No token available"}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('6. Click "Send test message"'),
              const SizedBox(height: 8),
              const Text('Note: Make sure your app is running on a physical device!'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Push Notification Test'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _clearTestResults,
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear Test Results',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FCM Token Status',
                      style: AppStyles.textStyle_18_600.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else if (_fcmToken != null) ...[
                      Text(
                        'Token: ${_fcmToken!.substring(0, 50)}...',
                        style: AppStyles.textStyle_14_500.copyWith(
                          color: Colors.green[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Length: ${_fcmToken!.length} characters',
                        style: AppStyles.textStyle_12_500.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ] else
                      Text(
                        'No FCM token available',
                        style: AppStyles.textStyle_14_500.copyWith(
                          color: Colors.red[700],
                        ),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _getFCMToken,
                      child: const Text('Refresh Token'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Authentication Status',
                      style: AppStyles.textStyle_18_600.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    authState.user.when(
                      data: (user) => user != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Logged in as: ${user.email ?? user.name ?? 'Unknown'}',
                                  style: AppStyles.textStyle_14_500.copyWith(
                                    color: Colors.green[700],
                                  ),
                                ),
                                Text(
                                  'User ID: ${user.id}',
                                  style: AppStyles.textStyle_12_500.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Not logged in',
                              style: AppStyles.textStyle_14_500.copyWith(
                                color: Colors.red[700],
                              ),
                            ),
                      loading: () => const CircularProgressIndicator(),
                      error: (error, stackTrace) => Text(
                        'Error: $error',
                        style: AppStyles.textStyle_14_500.copyWith(
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Database Token Verification',
                      style: AppStyles.textStyle_18_600.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isCheckingDB)
                      const CircularProgressIndicator()
                    else if (_savedTokenFromDB != null) ...[
                      Text(
                        '✅ Token saved in database',
                        style: AppStyles.textStyle_14_500.copyWith(
                          color: Colors.green[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'DB Token: ${_savedTokenFromDB!.substring(0, 50)}...',
                        style: AppStyles.textStyle_12_500.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tokens match: ${_fcmToken == _savedTokenFromDB ? "✅ Yes" : "❌ No"}',
                        style: AppStyles.textStyle_12_500.copyWith(
                          color: _fcmToken == _savedTokenFromDB ? Colors.green[700] : Colors.red[700],
                        ),
                      ),
                    ] else
                      Text(
                        '❌ No token found in database',
                        style: AppStyles.textStyle_14_500.copyWith(
                          color: Colors.red[700],
                        ),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _checkDatabaseToken,
                      child: const Text('Refresh Database Check'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Testing Actions',
                      style: AppStyles.textStyle_18_600.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _saveTokenForCurrentUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save Token for Current User'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _testNotificationPermissions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[600],
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Check Notification Permissions'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _simulateLocalNotification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple[600],
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Simulate Local Notification'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _showFirebaseConsoleInstructions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[600],
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Firebase Console Instructions'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Topic Management',
                      style: AppStyles.textStyle_16_600.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _subscribeToTopic,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Subscribe to Topic'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _unsubscribeFromTopic,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[600],
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Unsubscribe'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Test Results',
                          style: AppStyles.textStyle_18_600.copyWith(
                            color: Colors.black87,
                          ),
                        ),
                        if (_notificationCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Notifications: $_notificationCount',
                              style: AppStyles.textStyle_12_500.copyWith(
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _testResults.isEmpty 
                              ? 'No test results yet. Run some tests to see results here.'
                              : _testResults,
                          style: AppStyles.textStyle_12_500.copyWith(
                            fontFamily: 'monospace',
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _clearTestResults,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[600],
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Clear Results'),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Auto-scroll enabled - results appear here in real-time',
                          style: AppStyles.textStyle_10_500.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
