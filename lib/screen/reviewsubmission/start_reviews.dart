import 'package:airline_app/screen/app_widgets/appbar_widget.dart';
import 'package:airline_app/screen/app_widgets/bottom_nav_bar.dart';
import 'package:airline_app/screen/app_widgets/main_button.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:airline_app/utils/app_localizations.dart';
import 'package:airline_app/screen/reviewsubmission/wallet_sync_screen.dart';
import 'package:airline_app/screen/reviewsubmission/google_calendar/google_calendar_screen.dart';
import 'package:airline_app/screen/reviewsubmission/scanner_screen/scanner_screen.dart';
import 'package:flutter/material.dart';

class StartReviews extends StatelessWidget {
  const StartReviews({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Powered by Exp Live Feedback"),
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, const Color(0xFFF5F9FF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(24, 40, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Get Live Updates. Share Real.",
                        style: AppStyles.textStyle_24_600.copyWith(
                          letterSpacing: -0.3,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Where premium travel meets real-time intelligence.",
                        style: AppStyles.textStyle_15_400.copyWith(
                          color: const Color(0xFF666666),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey,
                              spreadRadius: 4,
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                "assets/images/pixar2.png",
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Icon(Icons.star_rounded,
                                    color: Colors.amber[600], size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Rate your experience and help others make informed decisions",
                                    style: AppStyles.textStyle_15_400.copyWith(
                                      color: const Color(0xFF4A4A4A),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(Icons.verified_user_rounded,
                                    color: Colors.green[600], size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Your review will be verified for authenticity",
                                    style: AppStyles.textStyle_15_400.copyWith(
                                      color: const Color(0xFF4A4A4A),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            MainButton(
                              text: "Connect Your Flight",
                              color: const Color(0xFF000000),
                              onPressed: () {
                                _showSyncOptionsModal(context);
                              },
                              icon: Icon(
                                Icons.flight_takeoff,
                                color: Colors.white,
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(
        currentIndex: 0,
      ),
    );
  }

  void _showSyncOptionsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppLocalizations.of(context).translate('Choose Sync Option'),
              style: AppStyles.textStyle_24_600,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            MainButton(
              text: AppLocalizations.of(context)
                  .translate('Sync from Your Wallet'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const WalletSyncScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.account_balance_wallet, color: Colors.white),
            ),
            const SizedBox(height: 12),
            MainButton(
              text: AppLocalizations.of(context)
                  .translate('Sync from Google Calendar'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => GoogleCalendarScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.calendar_today, color: Colors.white),
            ),
            const SizedBox(height: 12),
            MainButton(
              text: AppLocalizations.of(context)
                  .translate('Scan Boarding Pass'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ScannerScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
