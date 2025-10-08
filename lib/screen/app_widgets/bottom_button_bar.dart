import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';

class BottomButtonBar extends StatelessWidget {
  const BottomButtonBar({super.key, required this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Container(
      height: screenSize.height * 0.1,
      decoration: BoxDecoration(
          color: AppStyles.appBarColor,
          border: Border(
            top: BorderSide(
              color: Colors.grey.shade300,
              width: 1.0,
            ),
          )),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        child: child,
      ),
    );
  }
}
