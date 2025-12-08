import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:airline_app/services/push_notification_service.dart';
import 'package:airline_app/utils/notification_diagnostic.dart';

/// Test screen for push notifications
/// Navigate to this screen to test sending push notifications via Supabase Edge Function
class TestPushNotificationScreen extends StatefulWidget {
  const TestPushNotificationScreen({Key? key}) : super(key: key);

  @override
  State<TestPushNotificationScreen> createState() =>
      _TestPushNotificationScreenState();
}

class _TestPushNotificationScreenState
    extends State<TestPushNotificationScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = false;
  String _result = '';
  String? _fcmToken;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _result = '❌ Not logged in';
        });
        return;
      }

      setState(() {
        _userId = user.id;
      });

      // Get FCM token from database
      final response = await _supabase
          .from('users')
          .select('fcm_token')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null && response['fcm_token'] != null) {
        setState(() {
          _fcmToken = response['fcm_token'] as String;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading user info: $e');
    }
  }

  Future<void> _sendTestNotification() async {
    setState(() {
      _loading = true;
      _result = 'Sending test notification...';
    });

    try {
      final userId = _supabase.auth.currentUser?.id;

      if (userId == null) {
        setState(() {
          _result = '❌ Not logged in. Please login first.';
          _loading = false;
        });
        return;
      }

      if (_fcmToken == null || _fcmToken!.isEmpty) {
        setState(() {
          _result =
              '❌ No FCM token found in database.\n\nPlease restart the app and login again to generate a token.';
          _loading = false;
        });
        return;
      }

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📤 SENDING TEST PUSH NOTIFICATION');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('User ID: $userId');
      debugPrint('FCM Token (first 30 chars): ${_fcmToken!.substring(0, 30)}...');
      debugPrint('Token length: ${_fcmToken!.length}');

      final timestamp = DateTime.now().toIso8601String();
      
      final response = await _supabase.functions.invoke(
        'send-push-notification',
        body: {
          'userId': userId,
          'title': '🎉 Test Notification',
          'body':
              'This is a test push notification sent at $timestamp. If you see this, your push notification system is working! 🚀',
          'data': {
            'test': true,
            'timestamp': timestamp,
            'source': 'test_screen',
            'type': 'test_notification',
          },
        },
      );

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📥 EDGE FUNCTION RESPONSE');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('Status: ${response.status}');
      debugPrint('Data: ${response.data}');

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
        setState(() {
          _result = '''
✅ Notification sent successfully!

📊 Summary:
  • Sent: ${data['sent'] ?? 0}
  • Failed: ${data['failed'] ?? 0}
  • Total: ${data['total'] ?? 0}

📱 Check your device notification center!

🔍 Full Response:
${response.data}

✅ If you received the notification, push notifications are working perfectly!
''';
          _loading = false;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Notification sent! Check your device!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        setState(() {
          _result = '''
❌ Error sending notification

Status Code: ${response.status}

Response:
${response.data}

💡 Check Supabase Edge Function logs for details.
''';
          _loading = false;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to send notification'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error sending test notification: $e');
      debugPrint('Stack trace: $stackTrace');
      
      setState(() {
        _result = '''
❌ Error occurred

Error: $e

Stack Trace:
$stackTrace

💡 Common Issues:
  • FCM_SERVER_KEY not configured in Supabase
  • Edge function not deployed
  • Network connection issues
  • Invalid FCM token
''';
        _loading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _testForegroundNotification() async {
    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📲 TESTING FOREGROUND NOTIFICATION');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final timestamp = DateTime.now().toString();

      // Show foreground notification
      await PushNotificationService.showForegroundNotification(
        title: '🧪 Foreground Test',
        body: 'This is a test foreground notification!\nYou should see both a system notification AND an in-app banner.',
        data: {
          'test': 'foreground',
          'timestamp': timestamp,
          'type': 'test',
        },
      );

      setState(() {
        _result = '''
✅ Foreground notification triggered!

🎯 What to expect:
  1. System notification (heads-up)
  2. In-app banner (animated slide-in from top)
  3. Sound + Vibration

📲 Did you see:
  • A notification at the top of your screen? ✓
  • An animated banner slide down? ✓
  • Did it auto-dismiss after 5 seconds? ✓

📋 Test completed at: $timestamp

✅ If you saw the notification, foreground notifications are working!
''';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Foreground notification shown!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      debugPrint('✅ Foreground notification test completed');
    } catch (e, stackTrace) {
      debugPrint('❌ Error testing foreground notification: $e');
      debugPrint('Stack trace: $stackTrace');

      setState(() {
        _result = '''
❌ Error testing foreground notification:
$e

Check console for more details.
''';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _runDiagnostic() async {
    setState(() {
      _result = 'Running full diagnostic...\n\nPlease wait...';
    });

    try {
      debugPrint('🔍 Starting notification diagnostic...');
      final results = await NotificationDiagnostic.runFullDiagnostic();

      final buffer = StringBuffer();
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('🔍 NOTIFICATION DIAGNOSTIC RESULTS');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      buffer.writeln('📱 Platform: ${results['platform']}');
      buffer.writeln('📊 OS Version: ${results['platform_version']}\n');

      buffer.writeln('🔔 FCM Authorization: ${results['fcm_authorization']}');
      buffer.writeln('🔕 FCM Alert: ${results['fcm_alert']}');
      buffer.writeln('🔕 FCM Badge: ${results['fcm_badge']}');
      buffer.writeln('🔕 FCM Sound: ${results['fcm_sound']}\n');

      if (results['ios_implementation'] != null) {
        buffer.writeln('🍎 iOS Implementation: ${results['ios_implementation']}');
        buffer.writeln('🍎 APNS Token: ${results['ios_apns_token']}\n');
      }

      buffer.writeln('🔑 FCM Token Available: ${results['fcm_token_available']}');
      if (results['fcm_token_available'] == true) {
        buffer.writeln('📏 Token Length: ${results['fcm_token_length']}\n');
      }

      buffer.writeln('🧪 Test Notification Sent: ${results['test_notification_sent']}');

      if (results['issues'] != null && (results['issues'] as List).isNotEmpty) {
        buffer.writeln('\n⚠️ ISSUES DETECTED:');
        for (final issue in results['issues']) {
          buffer.writeln('  • $issue');
        }
        buffer.writeln('\n💡 SOLUTIONS:');
        buffer.writeln('  • Go to Settings → Notifications → Allow');
        buffer.writeln('  • Check if you received the diagnostic test notification');
        buffer.writeln('  • Restart the app after granting permissions');
      } else {
        buffer.writeln('\n✅ NO ISSUES DETECTED!');
        buffer.writeln('  • Notifications should be working');
        buffer.writeln('  • Check if you received the diagnostic test notification');
      }

      buffer.writeln('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('💡 Next Steps:');
      buffer.writeln('  1. Check if you saw the diagnostic test notification');
      buffer.writeln('  2. If yes → Notifications are working!');
      buffer.writeln('  3. If no → Check Issues section above');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      setState(() {
        _result = buffer.toString();
      });

      if (!mounted) return;
      if (results['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Diagnostic complete! Check results below.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Issues detected! Check results below.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error running diagnostic: $e');
      debugPrint('Stack trace: $stackTrace');

      setState(() {
        _result = '''
❌ Error running diagnostic:
$e

Check console for more details.
''';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Push Notifications'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.notifications_active, size: 48, color: Colors.blue),
                  const SizedBox(height: 8),
                  const Text(
                    '🔔 Test Push Notification',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Send a test notification to your device using Supabase Edge Function',
                    style: TextStyle(color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // User Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '👤 User Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('User ID', _userId ?? 'Not logged in'),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'FCM Token',
                      _fcmToken != null
                          ? '${_fcmToken!.substring(0, 30)}...'
                          : 'No token found',
                    ),
                    if (_fcmToken != null) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow('Token Length', '${_fcmToken!.length} characters'),
                    ],
                    if (_fcmToken != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _fcmToken!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('FCM token copied to clipboard'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy full token'),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Send Button
            ElevatedButton.icon(
              onPressed: _loading ? null : _sendTestNotification,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(
                _loading ? 'Sending...' : '📤 Send Test Notification',
                style: const TextStyle(fontSize: 16),
              ),
            ),

            const SizedBox(height: 16),

            // Test Foreground Notification Button
            ElevatedButton.icon(
              onPressed: _loading ? null : _testForegroundNotification,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.notifications_active),
              label: const Text(
                '📲 Test Foreground Notification',
                style: TextStyle(fontSize: 16),
              ),
            ),

            const SizedBox(height: 16),

            // Run Diagnostic Button
            ElevatedButton.icon(
              onPressed: _loading ? null : _runDiagnostic,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.bug_report),
              label: const Text(
                '🔍 Run Full Diagnostic',
                style: TextStyle(fontSize: 16),
              ),
            ),

            const SizedBox(height: 24),

            // Result Card
            if (_result.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '📋 Result',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _result));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Result copied to clipboard'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          _result,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Instructions
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '💡 Troubleshooting',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('If notification fails:'),
                    const SizedBox(height: 4),
                    const Text('• Check FCM_SERVER_KEY in Supabase Edge Functions'),
                    const Text('• Verify edge function is deployed'),
                    const Text('• Check device notification permissions'),
                    const Text('• View edge function logs in Supabase dashboard'),
                    const Text('• Restart app if no FCM token'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }
}

