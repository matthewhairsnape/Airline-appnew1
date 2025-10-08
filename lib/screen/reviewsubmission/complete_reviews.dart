import 'package:airline_app/screen/app_widgets/appbar_widget.dart';
import 'package:airline_app/screen/app_widgets/bottom_button_bar.dart';
import 'package:airline_app/screen/app_widgets/main_button.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CompleteReviews extends ConsumerWidget {
  const CompleteReviews({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenSize = MediaQuery.of(context).size;
    var scores = ModalRoute.of(context)!.settings.arguments as Map;

    final airlineScore = scores['airlineScore'];
    final airportScore = scores['airportScore'];

    return PopScope(
      canPop: false, // Prevents the default pop action
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pushNamed(context, AppRoutes.startreviews);
        }
      },
      child: Scaffold(
          appBar: AppbarWidget(title: "Review Completed"),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.grey.shade100, Colors.white],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: Container(
                    width: screenSize.width,
                    height: screenSize.height * 0.42,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(25),
                          spreadRadius: 5,
                          blurRadius: 15,
                        ),
                      ],
                      image: const DecorationImage(
                        image: AssetImage("assets/images/attendant.jpg"),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withAlpha(25),
                        spreadRadius: 2,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text("Thank You for Your Feedback!",
                          style: AppStyles.textStyle_24_600.copyWith(
                            color: Colors.black,
                          )),
                      const SizedBox(height: 10),
                      Text(
                        "Your valuable insights help us create better travel experiences for everyone",
                        style: AppStyles.textStyle_16_600.copyWith(
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildScoreCard(
                            "Airline Score",
                            (airlineScore ?? 0).toStringAsFixed(1),
                            Icons.flight,
                          ),
                          _buildScoreCard(
                            "Airport Score",
                            (airportScore ?? 0).toStringAsFixed(1),
                            Icons.airplane_ticket,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: BottomButtonBar(
              child: MainButton(
            text: "Home",
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.leaderboardscreen,
            ),
          ))),
    );
  }

  Widget _buildScoreCard(String title, String score, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, size: 30, color: Colors.blue.shade700),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(title,
                  style: AppStyles.textStyle_16_600
                      .copyWith(color: Colors.grey.shade700)),
              const SizedBox(height: 5),
              Text(score,
                  style: AppStyles.textStyle_16_600
                      .copyWith(color: Colors.grey.shade700)),
            ],
          ),
        ],
      ),
    );
  }
}
