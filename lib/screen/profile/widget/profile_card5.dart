import 'package:flutter/material.dart';

class ProfileCard5 extends StatefulWidget {
  final String iconPath;
  final bool isActive;
  final VoidCallback myfun;
  final int count;

  const ProfileCard5({
    super.key,
    required this.iconPath,
    required this.isActive,
    required this.count,
    required this.myfun,
  });

  @override
  State<ProfileCard5> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard5> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.myfun, // Call the passed function when tapped
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black,
              offset: Offset(2, 2),
            ),
          ],
          color: Colors.white, // Change color based on active state
          borderRadius: BorderRadius.circular(36),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                widget.iconPath,
                height: 24,
                width: 24,
              ),
              // Space between icon and count
            ],
          ),
        ),
      ),
    );
  }
}
