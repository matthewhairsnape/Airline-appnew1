import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';

class VerifiedButton extends StatelessWidget {
  const VerifiedButton({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 24,
      decoration: BoxDecoration(
          color: const Color(0xff181818),
          borderRadius: BorderRadius.circular(12)),
      child: Center(
          child: Text(
        "Verified",
        style: AppStyles.textStyle_14_600.copyWith(color: Colors.white),
      )),
    );
  }
}
