import 'package:flutter/material.dart';
import '../services/notification_manager.dart';

/// Production-ready notification settings widget
class NotificationSettingsWidget extends StatefulWidget {
  final VoidCallback? onPermissionChanged;
  
  const NotificationSettingsWidget({
    super.key,
    this.onPermissionChanged,
  });

  @override
  State<NotificationSettingsWidget> createState() => _NotificationSettingsWidgetState();
}

class _NotificationSettingsWidgetState extends State<NotificationSettingsWidget> {
  final NotificationManager _notificationManager = NotificationManager();
  bool _isLoading = false;
  bool _isEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    setState(() => _isLoading = true);
    
    try {
      final isEnabled = await _notificationManager.areNotificationsEnabled();
      setState(() {
        _isEnabled = isEnabled;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleNotifications() async {
    if (_isEnabled) {
      // Notifications are enabled, show info about disabling
      _showDisableInfo();
    } else {
      // Notifications are disabled, request permission
      setState(() => _isLoading = true);
      
      try {
        final granted = await _notificationManager.requestPermissions();
        setState(() {
          _isEnabled = granted;
          _isLoading = false;
        });
        
        if (granted) {
          widget.onPermissionChanged?.call();
          _showSuccessMessage('Notifications enabled successfully!');
        } else {
          _showErrorMessage('Failed to enable notifications. Please check your settings.');
        }
      } catch (e) {
        setState(() => _isLoading = false);
        _showErrorMessage('Error enabling notifications: $e');
      }
    }
  }

  void _showDisableInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable Notifications'),
        content: const Text(
          'To disable notifications, please go to your device Settings > Apps > [App Name] > Notifications and turn off notifications.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          _isEnabled ? Icons.notifications : Icons.notifications_off,
          color: _isEnabled ? Colors.green : Colors.grey,
        ),
        title: const Text('Push Notifications'),
        subtitle: Text(
          _isEnabled 
            ? 'Receive flight updates and important notifications'
            : 'Enable to receive flight updates and important notifications',
        ),
        trailing: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch(
              value: _isEnabled,
              onChanged: (_) => _toggleNotifications(),
            ),
        onTap: _isLoading ? null : _toggleNotifications,
      ),
    );
  }
}
