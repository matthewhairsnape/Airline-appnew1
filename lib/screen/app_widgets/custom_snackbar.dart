import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';

class CustomSnackBar {
  static void show({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
    Color backgroundColor = const Color(0xFF323232),
    Color textColor = Colors.white,
    double elevation = 8,
    EdgeInsetsGeometry margin = const EdgeInsets.all(8.0),
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    ShapeBorder shape = const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  }) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: AppStyles.textStyle_16_600.copyWith(color: textColor),
      ),
      duration: duration,
      backgroundColor: backgroundColor,
      elevation: elevation,
      margin: margin,
      padding: padding,
      shape: shape,
      action: action,
      behavior: SnackBarBehavior.floating,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // Add these methods to the CustomSnackBar class
  static void success(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      backgroundColor: Colors.green,
      action: SnackBarAction(
        label: 'OK',
        textColor: Colors.white,
        onPressed: () {Navigator.of(context).pop();},
      ),
    );
  }

  static void error(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    );
  }

  static void info(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      backgroundColor: Colors.blue,
    );
  }
}
