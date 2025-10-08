import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class SubcategoryButtonWidget extends StatelessWidget {
  final String labelName;
  final VoidCallback onTap;
  final bool isSelected;
  final String imagePath;

  const SubcategoryButtonWidget(
      {super.key,
      required this.labelName,
      required this.onTap,
      required this.isSelected,
      required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        width: MediaQuery.of(context).size.width * 0.41,
        height: MediaQuery.of(context).size.width * 0.33,
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF4A4A4A),
                    Color(0xFF2C2C2C),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(127),
              spreadRadius: 2,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        margin: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        padding: EdgeInsets.only(bottom: 5, top: 16, right: 5, left: 5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? Colors.white.withAlpha(76)
                        : Colors.grey.withAlpha(51),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(8),
                child: SvgPicture.asset(
                  imagePath,
                  height: 40,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              labelName,
              textAlign: TextAlign.center,
              style: AppStyles.textStyle_14_600.copyWith(
                color: isSelected ? Colors.white : AppStyles.blackColor,
                letterSpacing: 0.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
