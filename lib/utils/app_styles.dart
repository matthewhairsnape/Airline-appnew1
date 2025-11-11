import 'package:flutter/material.dart';

class AppStyles {
  ///Color style
  static Color mainColor = const Color(0xFFB3FFB5);
  static Color warnningColor = const Color(0xF7E74C4C);
  static Color notifyColor = Colors.lightBlue;
  static Color littleBlackColor = const Color(0xff181818);
  static Color backgroundColor = const Color(0xFFf5f5f5);
  static Color blackColor = const Color(0xFF000000);
  static Color mainButtonColor = const Color(0xFF2C3E50);
  static Color appBarColor = Colors.grey.shade100;
  static Color customIconColor = Colors.green.shade600;

  ///Text style
  static TextStyle textStyle_12_600 = const TextStyle(
    fontFamily: 'SF Pro',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.black,
    fontStyle: FontStyle.normal,
  );
  static TextStyle textStyle_12_500 = const TextStyle(
    fontFamily: 'SF Pro',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Colors.black,
    fontStyle: FontStyle.normal,
  );
  static TextStyle textStyle_12_400 = const TextStyle(
    fontFamily: 'SF Pro',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: Colors.black,
    fontStyle: FontStyle.normal,
  );
  static TextStyle textStyle_13_500 = const TextStyle(
    fontFamily: 'SF Pro',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: Colors.black,
    fontStyle: FontStyle.normal,
  );
  static TextStyle textStyle_10_500 = const TextStyle(
    fontFamily: 'SF Pro',
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: Colors.black,
    fontStyle: FontStyle.normal,
  );
  static TextStyle textStyle_16_400 = const TextStyle(
    fontFamily: 'SF Pro',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: Colors.black,
    fontStyle: FontStyle.normal,
  );
  static TextStyle textStyle_16_500 = const TextStyle(
    fontFamily: 'SF Pro',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Colors.black,
    fontStyle: FontStyle.normal,
  );
  static TextStyle textStyle_20_600 = const TextStyle(
    fontFamily: 'SF Pro',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: Colors.black,
    fontStyle: FontStyle.normal,
  );
  static TextStyle textStyle_14_400 = const TextStyle(
    fontFamily: 'SF Pro',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Colors.black,
    fontStyle: FontStyle.normal,
  );

  static TextStyle textStyle_14_500 = const TextStyle(
    fontFamily: 'SF Pro',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Color(0xff38433E),
    fontStyle: FontStyle.normal,
  );
  static TextStyle textStyle_14_600 = const TextStyle(
    fontFamily: 'SF Pro',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Color(0xFF000000),
    fontStyle: FontStyle.normal,
  );
  static TextStyle textStyle_15_400 = const TextStyle(
    fontFamily: 'SF Pro',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: Colors.black,
    fontStyle: FontStyle.normal,
  );
  static TextStyle textStyle_15_600 = const TextStyle(
    fontFamily: 'SF Pro',
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: Color(0xFF000000),
    fontStyle: FontStyle.normal,
  );
  static TextStyle textStyle_15_500 = const TextStyle(
    fontFamily: 'SF Pro',
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: Color(0xFF000000),
    fontStyle: FontStyle.normal,
  );

  static TextStyle textStyle_16_600 = const TextStyle(
    fontFamily: 'SF Pro',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Color(0xFF000000),
    fontStyle: FontStyle.normal,
  );
  static TextStyle textStyle_18_600 = const TextStyle(
    fontFamily: 'SF Pro',
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: Colors.black,
    fontStyle: FontStyle.normal,
  );
  static TextStyle textStyle_24_600 = const TextStyle(
    fontFamily: 'SF Pro',
    fontSize: 24,
    fontWeight: FontWeight.w500,
    color: Colors.black,
    fontStyle: FontStyle.normal,
  );
  static TextStyle textStyle_32_600 = const TextStyle(
    fontFamily: 'SF Pro',
    fontSize: 32,
    fontWeight: FontWeight.w600,
    color: Colors.black,
    fontStyle: FontStyle.normal,
  );
  static TextStyle textStyle_40_700 = const TextStyle(
    fontFamily: 'SF Pro',
    fontSize: 40,
    fontWeight: FontWeight.w700,
    color: Colors.black,
    fontStyle: FontStyle.normal,
  );

  static TextStyle italicTextStyle = TextStyle(
    fontFamily: 'SF Pro',
    fontWeight: FontWeight.bold,
    fontStyle: FontStyle.italic,
    color: Colors.white,
    fontSize: 16,
  );

  /// Box style
  static BoxDecoration circleDecoration = BoxDecoration(
    shape: BoxShape.circle,
    color: Colors.white,
    border: Border.all(
      color: Colors.grey.shade100,
      width: 1.0,
    ),
  );
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.grey.shade50,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: Colors.grey.shade100,
      width: 2,
    ),
  );
  static BoxDecoration avatarDecoration = BoxDecoration(
    shape: BoxShape.circle,
    border: Border.all(
      color: Colors.white,
      width: 4,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withAlpha(25),
        spreadRadius: 2,
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}
