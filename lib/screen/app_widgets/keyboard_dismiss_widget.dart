import 'package:flutter/material.dart';

class KeyboardDismissWidget extends StatelessWidget {
  final Widget child;

  const KeyboardDismissWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: child,
    );
  }
}
