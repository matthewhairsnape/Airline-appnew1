import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';

class ReviewButton extends StatelessWidget {
  final String iconUrl;
  final String label;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback onTap;

  const ReviewButton({super.key, 
    required this.iconUrl,
    required this.label,
    required this.isSelected,
    required this.isLocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: AppStyles.cardDecoration.copyWith(
              color: isSelected ? AppStyles.mainColor : Colors.white,
            ),
            padding: EdgeInsets.only(bottom: 10, top: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: AppStyles.cardDecoration.copyWith(
                    color: isSelected ? Colors.white : AppStyles.mainColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Image.asset(iconUrl, height: 40),
                ),
                SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppStyles.textStyle_14_600.copyWith(
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          if (isLocked)
            Container(
              height: double.infinity,
              width: double.infinity,
              decoration: AppStyles.cardDecoration
                  .copyWith(color: Colors.black.withAlpha(127)),
              child: Center(
                child: Icon(
                  Icons.lock,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
