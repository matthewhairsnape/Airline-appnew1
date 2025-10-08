import 'package:airline_app/screen/reviewsubmission/widgets/emphasize_widget.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class ProgressWidget extends StatelessWidget {
  const ProgressWidget({super.key, required this.parent});

  final int parent;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        parent == 0
            ? EmphasizeWidget(number: 1)
            : Text("1",
                style:
                    AppStyles.textStyle_18_600.copyWith(color: Colors.white)),
        SvgPicture.asset(
          "assets/icons/progress_flight.svg",
          width: screenSize.width * 0.3,
          fit: BoxFit.fitWidth,
        ),
        parent == 1
            ? EmphasizeWidget(number: 2)
            : Text("2",
                style:
                    AppStyles.textStyle_18_600.copyWith(color: Colors.white)),
        SvgPicture.asset(
          "assets/icons/progress_trunk.svg",
          width: screenSize.width * 0.3,
          fit: BoxFit.fitWidth,
        ),
        parent == 2
            ? EmphasizeWidget(number: 3)
            : Text("3",
                style:
                    AppStyles.textStyle_18_600.copyWith(color: Colors.white)),
      ],
    );
  }
}
