import 'package:airline_app/provider/auth_provider.dart';
import 'package:airline_app/utils/app_localizations.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:airline_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool showLanguageButtons = false;

  Future<void> _showSignOutConfirmation(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Sign Out',
            style: AppStyles.textStyle_18_600.copyWith(
              color: Colors.black,
            ),
          ),
          content: Text(
            'Are you sure you want to sign out?',
            style: AppStyles.textStyle_14_400.copyWith(
              color: Colors.grey.shade700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: AppStyles.textStyle_14_600.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close confirmation dialog
                
                // Show loading indicator
                if (context.mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                
                try {
                  await ref.read(authProvider.notifier).signOut();
                  
                  // Close loading dialog and navigate
                  if (context.mounted) {
                    Navigator.of(context).pop(); // Close loading dialog
                    Navigator.pushNamedAndRemoveUntil(
                      context, 
                      AppRoutes.skipscreen, 
                      (route) => false
                    );
                  }
                } catch (e) {
                  // Close loading dialog and show error
                  if (context.mounted) {
                    Navigator.of(context).pop(); // Close loading dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Sign out failed: $e'),
                        duration: const Duration(seconds: 3),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(
                'Sign Out',
                style: AppStyles.textStyle_14_600.copyWith(
                  color: Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLanguageButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLanguageButton('English', 'en'),
              _buildLanguageButton('中文', 'zh'),
              _buildLanguageButton('Español', 'es'),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLanguageButton(String label, String code) {
    return Consumer(
      builder: (context, ref, child) {
        final currentLocale = ref.watch(localeProvider);
        final isSelected = currentLocale.languageCode == code;

        return ElevatedButton(
          onPressed: () async {
            try {
              // Save to SharedPreferences first
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('selectedLanguageSym', code);
              
              // Update the locale provider
              ref.read(localeProvider.notifier).state = Locale(code);
              
              // Show success feedback
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Language changed to $label. Restart app to see changes.'),
                    duration: const Duration(seconds: 3),
                    backgroundColor: Colors.green,
                    action: SnackBarAction(
                      label: 'Restart',
                      textColor: Colors.white,
                      onPressed: () {
                        // Force app restart by navigating to skip screen
                        Navigator.pushNamedAndRemoveUntil(
                          context, 
                          AppRoutes.skipscreen, 
                          (route) => false
                        );
                      },
                    ),
                  ),
                );
              }
            } catch (e) {
              // Show error feedback
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to change language: $e'),
                    duration: const Duration(seconds: 3),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? AppStyles.mainColor : Colors.grey[200],
            foregroundColor: isSelected ? Colors.white : Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: Text(
            label,
            style: AppStyles.textStyle_14_600.copyWith(
              color: isSelected ? Colors.white : Colors.black,
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserProfileSection() {
    return Consumer(
      builder: (context, ref, child) {
        final authState = ref.watch(authProvider);
        final user = authState.user.value;
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              // Profile Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppStyles.mainColor,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    user?.displayName?.isNotEmpty == true 
                        ? user!.displayName![0].toUpperCase()
                        : user?.email?.isNotEmpty == true 
                            ? user!.email![0].toUpperCase()
                            : 'U',
                    style: AppStyles.textStyle_24_600.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? 'User',
                      style: AppStyles.textStyle_18_600.copyWith(
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? 'No email',
                      style: AppStyles.textStyle_14_400.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Member since ${user?.createdAt != null ? _formatDate(user!.createdAt!) : 'Unknown'}',
                      style: AppStyles.textStyle_12_400.copyWith(
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 16),
      child: Row(
        children: [
          Text(
            title,
            style: AppStyles.textStyle_14_600.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Widget _buildSettingsItem({
    required BuildContext context,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: AppStyles.textStyle_16_600.copyWith(
                color: textColor ?? Colors.black,
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: AppStyles.textStyle_20_600.copyWith(
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            children: [
              // User Profile Section
              _buildUserProfileSection(),
              const SizedBox(height: 24),
              
              // App Settings Section
              _buildSectionHeader('App Settings'),
              _buildSettingsItem(
                context: context,
                title: 'App Language',
                onTap: () => setState(() {
                  showLanguageButtons = !showLanguageButtons;
                }),
              ),
              if (showLanguageButtons) _buildLanguageButtons(),
              const SizedBox(height: 8),
              
              // Information Section
              _buildSectionHeader('Information'),
              _buildSettingsItem(
                context: context,
                title: 'About the app',
                onTap: () => Navigator.pushNamed(context, AppRoutes.aboutapp),
              ),
              _buildSettingsItem(
                context: context,
                title: 'Terms of Service',
                onTap: () => Navigator.pushNamed(context, AppRoutes.termsofservice),
              ),
              _buildSettingsItem(
                context: context,
                title: 'Help & FAQ',
                onTap: () => Navigator.pushNamed(context, AppRoutes.helpFaqs),
              ),
              const SizedBox(height: 8),
              
              // Account Section
              _buildSectionHeader('Account'),
              _buildSettingsItem(
                context: context,
                title: 'Sign Out',
                onTap: () => _showSignOutConfirmation(context),
                textColor: Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

