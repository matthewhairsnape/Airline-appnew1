import 'package:airline_app/screen/app_widgets/main_button.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';

class ShowModalWidget extends StatelessWidget {
  const ShowModalWidget({
    super.key,
    required this.title,
    required this.content,
    required this.cancelText,
    required this.confirmText,
    required this.onPressed,
  });
  final String title;
  final String content;
  final String cancelText;
  final String confirmText;
  final Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 10,
              spreadRadius: 0,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8),
            Center(
              child: Container(
                height: 4,
                width: 40,
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                title,
                style: AppStyles.textStyle_24_600.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
              child: Text(
                content,
                style: AppStyles.textStyle_14_400.copyWith(
                  color: Color(0xFF666666),
                  height: 1.4,
                ),
              ),
            ),
            Divider(
              thickness: 2,
              color: Colors.grey[200],
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                      child: MainButton(
                          text: cancelText,
                          onPressed: () => Navigator.pop(context))),
                  SizedBox(width: 10),
                  Expanded(
                      child:
                          MainButton(text: confirmText, onPressed: onPressed)),
                ],
              ),
            ),
          ],
        ),
      ),
    ]);
  }
}
