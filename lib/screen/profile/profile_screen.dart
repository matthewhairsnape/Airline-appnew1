import 'package:airline_app/provider/user_data_provider.dart';
import 'package:airline_app/screen/app_widgets/bottom_nav_bar.dart';
import 'package:airline_app/screen/app_widgets/custom_icon_button.dart';
import 'package:airline_app/screen/profile/widget/card_airport.dart';
import 'package:airline_app/screen/profile/widget/card_notifications.dart';
import 'package:airline_app/utils/app_localizations.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedIndexProvider = StateProvider<int>((ref) => 0);

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool showEditIcon = false;

  void toggleEditIcon() {
    setState(() {
      showEditIcon = !showEditIcon;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedIndexProvider);
    final screenSize = MediaQuery.of(context).size;
    final List<Widget> cardList = [
      SingleChildScrollView(child: CLeaderboardScreen()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            SizedBox(height: 24),
            Container(
              height: 558,
              decoration: AppStyles.cardDecoration,
              child: Container(),
            ),
            SizedBox(height: 13),
          ],
        ),
      ),
      CardNotifications(),
    ];

    final userData = ref.watch(userDataProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pushNamed(context, AppRoutes.startreviews);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(screenSize.height * 0.37),
          child: Stack(children: [
            Container(
              decoration: BoxDecoration(
                  color: AppStyles.appBarColor,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1.0,
                    ),
                  )),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(
                      height: 20,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: toggleEditIcon,
                          child: Container(
                            decoration: AppStyles.avatarDecoration,
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white,
                              backgroundImage:
                                  userData?['userData']['profilePhoto'] != null
                                      ? NetworkImage(
                                          userData?['userData']['profilePhoto'],
                                        )
                                      : const AssetImage(
                                          "assets/images/avatar_1.png",
                                        ) as ImageProvider,
                            ),
                          ),
                        ),
                        CustomIconButton(
                          onTap: () {
                            ref.read(selectedIndexProvider.notifier).state = 2;
                          },
                          icon: Icons.settings,
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${(userData?['userData']['name'] ?? '').length > 20 ? '${userData?['userData']['name']?.substring(0, 20)}...' : userData?['userData']['name']}',
                        style: AppStyles.textStyle_24_600,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${(userData?['userData']['bio'] ?? '').length > 50 ? '${userData?['userData']['bio']?.substring(0, 50)}...' : userData?['userData']['bio']}',
                        style: AppStyles.textStyle_14_400,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Text(
                            AppLocalizations.of(context)
                                .translate('My favorite Airline is'),
                            style: AppStyles.textStyle_15_400,
                          ),
                          Text(
                            ' ${userData?['userData']['favoriteAirlines']}',
                            style: AppStyles.textStyle_15_600,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 227,
                        height: 40,
                        decoration: AppStyles.cardDecoration.copyWith(
                            borderRadius: BorderRadius.circular(24),
                            color: Colors.white),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Row(
                              children: [
                                Icon(Icons.rocket_sharp),
                                SizedBox(
                                  width: 4,
                                ),
                                Expanded(
                                  child: Text(
                                    '${AppLocalizations.of(context).translate('Flyer type')}: ${userData?['userData']['flyertype']}',
                                    style: AppStyles.textStyle_15_500,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showEditIcon)
              Positioned(
                top: screenSize.height * 0.12,
                left: screenSize.width * 0.21,
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.eidtprofilescreen);
                    toggleEditIcon();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppStyles.customIconColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(51),
                          spreadRadius: 2,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.edit,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
          ]),
        ),
        bottomNavigationBar: BottomNavBar(currentIndex: 1),
        body: ListView(children: [
          Column(
            children: [
              Column(
                children: [
                  SizedBox(
                    height: 28,
                  ),
                  if (selectedIndex < cardList.length)
                    cardList[selectedIndex]
                  else
                    cardList[0]
                ],
              ),
            ],
          ),
        ]),
      ),
    );
  }
}
