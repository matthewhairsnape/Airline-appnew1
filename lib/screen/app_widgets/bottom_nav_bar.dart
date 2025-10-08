import 'package:airline_app/screen/profile/profile_screen.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:airline_app/provider/user_data_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:convex_bottom_bar/convex_bottom_bar.dart';

class BottomNavBar extends ConsumerStatefulWidget {
  const BottomNavBar({super.key, required this.currentIndex});

  final int currentIndex;

  @override
  ConsumerState<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends ConsumerState<BottomNavBar> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.currentIndex;
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return; // Prevent re-navigation to same screen

    setState(() {
      _selectedIndex = index;
    });

    // Navigation for Review and My Journey tabs
    switch (index) {
      case 0:
        if (ModalRoute.of(context)?.settings.name != AppRoutes.startreviews) {
          Navigator.pushReplacementNamed(context, AppRoutes.startreviews);
        }
        break;
      case 1:
        if (ModalRoute.of(context)?.settings.name != AppRoutes.myJourney) {
          Navigator.pushReplacementNamed(context, AppRoutes.myJourney);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Colors.grey.shade300,
              width: 1.0,
            ),
          )
          // boxShadow: [
          //   BoxShadow(
          //     color: Colors.black.withAlpha(0.4),
          //     blurRadius: 10,
          //     offset: const Offset(0, -2),
          //   ),
          // ],
          ),
      child: ConvexAppBar(
        style: TabStyle.react,
        backgroundColor: AppStyles.appBarColor,
        color: Colors.grey.shade500,
        activeColor: Colors.black,
        elevation: 0,
        height: 70,
        curveSize: 100,
        top: -20,
        items: [
          TabItem(
            icon: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add,
                size: 24,
                color: Colors.white,
              ),
            ),
            title: 'Connect',
          ),
          TabItem(
            icon: Icon(
              Icons.timeline,
              size: 24,
              color: _selectedIndex == 1 ? Colors.black : Colors.grey.shade500,
            ),
            title: 'My Journey',
          ),
        ],
        initialActiveIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
