import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/push_notification_service.dart';

class NotificationPermissionWidget extends StatefulWidget {
  final VoidCallback? onPermissionGranted;
  final VoidCallback? onPermissionDenied;

  const NotificationPermissionWidget({
    super.key,
    this.onPermissionGranted,
    this.onPermissionDenied,
  });

  @override
  State<NotificationPermissionWidget> createState() =>
      _NotificationPermissionWidgetState();
}

class _NotificationPermissionWidgetState
    extends State<NotificationPermissionWidget> {
  bool _isLoading = false;
  bool _isEnabled = false;
  AuthorizationStatus _status = AuthorizationStatus.notDetermined;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    setState(() => _isLoading = true);

    try {
      final status = await PushNotificationService.checkPermissionStatus();
      final isEnabled = await PushNotificationService.areNotificationsEnabled();

      setState(() {
        _status = status;
        _isEnabled = isEnabled;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error checking permission status: $e');
    }
  }

  Future<void> _requestPermissions() async {
    setState(() => _isLoading = true);

    try {
      final granted = await PushNotificationService.requestPermissionsAgain();

      setState(() {
        _isEnabled = granted;
        _isLoading = false;
      });

      if (granted) {
        widget.onPermissionGranted?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Notifications enabled!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        widget.onPermissionDenied?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '❌ Notifications denied. You can enable them in Settings.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error requesting permissions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getStatusText() {
    switch (_status) {
      case AuthorizationStatus.authorized:
        return 'Enabled';
      case AuthorizationStatus.denied:
        return 'Denied';
      case AuthorizationStatus.notDetermined:
        return 'Not Requested';
      case AuthorizationStatus.provisional:
        return 'Provisional';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor() {
    switch (_status) {
      case AuthorizationStatus.authorized:
        return Colors.green;
      case AuthorizationStatus.denied:
        return Colors.red;
      case AuthorizationStatus.notDetermined:
        return Colors.orange;
      case AuthorizationStatus.provisional:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isEnabled
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                  color: _getStatusColor(),
                ),
                const SizedBox(width: 8),
                Text(
                  'Push Notifications',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusText(),
                      style: TextStyle(
                        color: _getStatusColor(),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _isEnabled
                  ? 'You will receive flight status updates and important notifications.'
                  : 'Enable notifications to receive flight updates, boarding alerts, and status changes.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 12),
            if (!_isEnabled)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _requestPermissions,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.notifications),
                  label: Text(
                      _isLoading ? 'Requesting...' : 'Enable Notifications'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            if (_isEnabled)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _checkPermissionStatus,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Status'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
