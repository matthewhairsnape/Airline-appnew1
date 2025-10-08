import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';

class MainButton extends StatelessWidget {
  const MainButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.width = double.infinity,
    this.height = 56.0,
    this.isLoading = false,
    this.icon,
    this.color=const Color(0xFF757575),
  });

  final String text;
  final VoidCallback onPressed;
  final double width;
  final double height;
  final bool isLoading;
  final Widget? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: color == Colors.white ? const BorderSide(
            color: Colors.black87,
            width: 1.0,
          ) : null,
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: animation,
                child: child,
              ),
            );
          },
          child: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.grey[100]!),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      icon!,
                      const SizedBox(width: 12),
                    ],
                    Text(
                      text,
                      style: AppStyles.textStyle_18_600.copyWith(
                        color: color == Colors.white ? Colors.black : Colors.white,
                      )
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}