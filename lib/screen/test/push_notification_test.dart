import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airline_app/services/push_notification_service.dart';
import 'package:airline_app/provider/auth_provider.dart';
import 'package:airline_app/utils/app_styles.dart';

class PushNotificationTestScreen extends ConsumerStatefulWidget {
  const PushNotificationTestScreen({super.key});

  @override
  ConsumerState<PushNotificationTestScreen> createState() => _PushNotificationTestScreenState();
}

class _PushNotificationTestScreenState extends ConsumerState<PushNotificationTestScreen> {
  String? _fcmToken;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getFCMToken();
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Push Notification Test'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Padding(
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
                      'Actions',
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
          ],
        ),
      ),
    );
  }
}
