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
                Navigator.of(context).pop();
                await ref.read(authProvider.notifier).signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, AppRoutes.skipscreen);
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLanguageButton('English', 'en'),
          _buildLanguageButton('中文', 'zh'),
          _buildLanguageButton('Español', 'es'),
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
            ref.read(localeProvider.notifier).state = Locale(code);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('selectedLanguageSym', code);
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
                title: 'App Language',
                onTap: () => setState(() {
                  showLanguageButtons = !showLanguageButtons;
                }),
              ),
              if (showLanguageButtons) _buildLanguageButtons(),
              const SizedBox(height: 8),
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

