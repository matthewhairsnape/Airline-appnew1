import 'package:flutter/material.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:airline_app/utils/app_styles.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
        child: SizedBox(
      width: 30,
      height: 30,
      child: LoadingIndicator(
        indicatorType: Indicator.lineSpinFadeLoader,
        colors: [AppStyles.blackColor],
        strokeWidth: 1,
        backgroundColor: Colors.transparent,
      ),
    ));
  }
}

class LoadingBallWidget extends StatelessWidget {
  const LoadingBallWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
        child: SizedBox(
      width: 40,
      height: 40,
      child: LoadingIndicator(
        indicatorType: Indicator.ballPulse,
        colors: [AppStyles.blackColor],
        strokeWidth: 1,
        backgroundColor: Colors.transparent,
      ),
    ));
  }
}
