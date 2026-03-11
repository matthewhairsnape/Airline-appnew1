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

    switch (index) {
      case 0:
        if (ModalRoute.of(context)?.settings.name !=
            AppRoutes.leaderboardscreen) {
          Navigator.pushReplacementNamed(context, AppRoutes.leaderboardscreen);
        }
        break;
      case 1:
        if (ModalRoute.of(context)?.settings.name != AppRoutes.feedscreen) {
          Navigator.pushReplacementNamed(context, AppRoutes.feedscreen);
        }
        break;
      case 2:
        if (ModalRoute.of(context)?.settings.name != AppRoutes.startreviews) {
          Navigator.pushReplacementNamed(context, AppRoutes.startreviews);
        }
        break;
      case 3:
        if (ModalRoute.of(context)?.settings.name != AppRoutes.profilescreen) {
          Navigator.pushReplacementNamed(context, AppRoutes.profilescreen);
          ref.read(selectedIndexProvider.notifier).state = 0;
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
            icon: Icon(
              Icons.leaderboard,
              color: _selectedIndex == 0
                  ? Colors.black
                  : theme.colorScheme.onSurface.withAlpha(153),
            ),
            title: 'Ranking',
          ),
          TabItem(
            icon: Icon(
              Icons.feed,
              color: _selectedIndex == 1
                  ? Colors.black
                  : theme.colorScheme.onSurface.withAlpha(153),
            ),
            title: 'Feed',
          ),
          TabItem(
            icon: Container(
              decoration: BoxDecoration(
                color: _selectedIndex == 2
                    ? Colors.black
                    : theme.colorScheme.onSurface.withAlpha(153),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add,
                size: 24,
                color: Colors.white,
              ),
            ),
            title: 'Review',
          ),
          TabItem(
            icon: Container(
              decoration: AppStyles.avatarDecoration.copyWith(
                border: Border.all(width: 2, color: Colors.white),
              ),
              child: CircleAvatar(
                radius: 13,
                backgroundColor: Colors.white,
                backgroundImage: userData?['userData']['profilePhoto'] != null
                    ? NetworkImage(userData?['userData']['profilePhoto'])
                    : const AssetImage("assets/images/avatar_1.png")
                        as ImageProvider,
              ),
            ),
            title: 'Profile',
          ),
        ],
        initialActiveIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
