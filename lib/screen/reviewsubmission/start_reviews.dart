import 'package:airline_app/screen/app_widgets/appbar_widget.dart';
import 'package:airline_app/screen/app_widgets/bottom_nav_bar.dart';
import 'package:airline_app/screen/app_widgets/main_button.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';

class StartReviews extends StatelessWidget {
  const StartReviews({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Reviews"),
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
                        "Share Your Travel Experience",
                        style: AppStyles.textStyle_24_600.copyWith(
                          letterSpacing: -0.3,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Your feedback helps improve travel for everyone",
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
                                "assets/images/start_review.jpg",
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
                              text: "Begin Your Review",
                              color: const Color(0xFF000000),
                              onPressed: () {
                                Navigator.pushNamed(
                                    context, AppRoutes.reviewsubmissionscreen);
                              },
                              icon: Icon(
                                Icons.rate_review_rounded,
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
}
