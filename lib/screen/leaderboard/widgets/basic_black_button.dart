import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';

class BasicBlackButton extends StatelessWidget {
  final double mywidth;
  final double myheight;
  final Color myColor;

  final String btntext;

  const BasicBlackButton(
      {super.key,
      required this.mywidth,
      required this.myheight,
      required this.myColor,
      required this.btntext});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: mywidth,
      height: myheight,
      decoration: BoxDecoration(
        border: Border.all(),
        color: myColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Center(
          child: Text(
            btntext,
            style: AppStyles.textStyle_14_600.copyWith(color: Colors.white),
          ),
        ),
        // ),
      ),
    );
  }
}
