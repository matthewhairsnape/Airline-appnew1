import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';

class ReviewScoreIcon extends StatefulWidget {
  const ReviewScoreIcon({super.key, required this.iconUrl});
  final String iconUrl;

  @override
  State<ReviewScoreIcon> createState() => __ReviewScoreIconState();
}

class __ReviewScoreIconState extends State<ReviewScoreIcon> {
  bool _isSelected = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _isSelected = !_isSelected),
      child: Container(
        height: 40,
        decoration: AppStyles.circleDecoration
            .copyWith(color: _isSelected ? AppStyles.mainColor : Colors.white),
        child: Image.asset(widget.iconUrl),
      ),
    );
  }
}
