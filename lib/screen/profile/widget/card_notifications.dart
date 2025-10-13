import 'package:airline_app/main.dart';
import 'package:airline_app/provider/auth_provider.dart';
import 'package:airline_app/provider/selected_language_provider.dart';
import 'package:airline_app/screen/profile/widget/show_modal_widget.dart';
import 'package:airline_app/utils/app_localizations.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CardNotifications extends ConsumerStatefulWidget {
  const CardNotifications({super.key});

  @override
  ConsumerState<CardNotifications> createState() => _CardNotificationsState();
}

class _CardNotificationsState extends ConsumerState<CardNotifications> {
  String _selectedLanguage = 'English';
  String _selectedLanguageSym = 'en';
  bool showLanguageButtons = false;
  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
  }

  void _loadLanguagePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('selectedLanguage') ?? 'English';
      _selectedLanguageSym = prefs.getString('selectedLanguageSym') ?? 'en';
    });
  }

  Future<void> _showSignOutConfirmation(BuildContext context) async {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return ShowModalWidget(
            title: AppLocalizations.of(context).translate("Sign Out"),
            content: AppLocalizations.of(context)
                .translate("Are you sure you want to sign out?"),
            cancelText: AppLocalizations.of(context).translate("Cancel"),
            confirmText: AppLocalizations.of(context).translate("Sign Out"),
            onPressed: () async {
              // Close the modal bottom sheet first
              if (!context.mounted) {
                return;
              }
              Navigator.pop(context);

              // Use the auth provider to sign out
              await ref.read(authProvider.notifier).signOut();
              
              // The AuthWrapper will automatically redirect to login screen
            });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0),
          child: Column(
            children: [
              _buildProfileItem(
                context: context,
                title: 'Edit Profile',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.eidtprofilescreen),
              ),
              _buildProfileItem(
                context: context,
                title: 'Help & FAQs',
                onTap: () => Navigator.pushNamed(context, AppRoutes.helpFaqs),
              ),
              _buildProfileItem(
                context: context,
                title: 'About the app',
                onTap: () => Navigator.pushNamed(context, AppRoutes.aboutapp),
              ),
              _buildProfileItem(
                context: context,
                title: 'Terms of Service',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.termsofservice),
              ),
              _buildProfileItem(
                  context: context,
                  title: 'App Language',
                  onTap: () => setState(() {
                        showLanguageButtons = !showLanguageButtons;
                      })),
              if (showLanguageButtons) _buildLanguageButtons(),
              _buildProfileItem(
                context: context,
                title: 'Sign Out',
                onTap: () => _showSignOutConfirmation(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileItem({
    required BuildContext context,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey[200]!,
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context).translate(title),
              style: AppStyles.textStyle_18_600,
            ),
            Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildLanguageButton(context, 'English', 'en'),
          _buildLanguageButton(context, 'Chinese', 'zh'),
          _buildLanguageButton(context, 'Spanish', 'es'),
        ],
      ),
    );
  }

  Widget _buildLanguageButton(
      BuildContext context, String language, String sym) {
    bool isSelected = _selectedLanguage == language;
    return InkWell(
      onTap: () => _changeLanguage(context, language, sym),
      child: Container(
        width: 103,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey[300]!,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(51),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            AppLocalizations.of(context).translate(language),
            style: AppStyles.textStyle_14_600.copyWith(
              color: isSelected ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changeLanguage(
      BuildContext context, String language, String lSym) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return ShowModalWidget(
          title: "Change to $language",
          content: AppLocalizations.of(context).translate(
              "Change to $language? Are you sure you want to change to $language?"),
          cancelText: "No, leave",
          onPressed: () async {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            setState(() {
              _selectedLanguage = language;
              _selectedLanguageSym = lSym;
            });
            await prefs.setString('selectedLanguage', language);
            await prefs.setString('selectedLanguageSym', lSym);

            ref.read(localeProvider.notifier).state =
                Locale(_selectedLanguageSym, '');
            ref
                .read(selectedLanguageProvider.notifier)
                .changeLanguage(_selectedLanguage);

            await prefs.setString('selectedLanguage', _selectedLanguage);
            await prefs.setString('selectedLanguageSym', _selectedLanguageSym);
            if (!context.mounted) {
              return;
            }
            Navigator.pop(context);
          },
          confirmText: 'Yes, change',
        );
      },
    );
  }
}
