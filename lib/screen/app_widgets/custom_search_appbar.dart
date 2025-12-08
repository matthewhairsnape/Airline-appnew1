import 'package:airline_app/screen/app_widgets/filter_button.dart';
import 'package:airline_app/screen/app_widgets/custom_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_localizations.dart';
import 'package:airline_app/screen/app_widgets/search_field.dart';

class CustomSearchAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final TextEditingController searchController;
  final String filterType;
  final Function(String) onSearchChanged;
  final Map<String, bool> buttonStates;
  final Function(String) onButtonToggle;
  final String selectedFilterButton;

  const CustomSearchAppBar(
      {super.key,
      required this.searchController,
      required this.filterType,
      required this.onSearchChanged,
      required this.buttonStates,
      required this.onButtonToggle,
      required this.selectedFilterButton,
      s});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenSize = MediaQuery.of(context).size;

    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
            color: AppStyles.appBarColor,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.shade300,
                width: 1.0,
              ),
            )
            // boxShadow: [
            //   BoxShadow(
            //     color: Colors.black.withAlpha(0.1),
            //     spreadRadius: 5,
            //     blurRadius: 15,
            //   ),
            // ],
            ),
      ),
      title: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SearchBarWidget(
                searchController: searchController,
                filterType: filterType,
                onSearchChanged: onSearchChanged,
              ),
              CustomIconButton(
                icon: Icons.tune_rounded,
                onTap: () {
                  if (ModalRoute.of(context)?.settings.name ==
                      AppRoutes.leaderboardscreen) {
                    Navigator.pushNamed(context, AppRoutes.filterscreen);
                  } else if (ModalRoute.of(context)?.settings.name ==
                      AppRoutes.feedscreen) {
                    Navigator.pushNamed(context, AppRoutes.feedfilterscreen);
                  }
                },
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenSize.height * 0.02),
              Text(
                AppLocalizations.of(context).translate('Filter by category'),
                style: AppStyles.textStyle_18_600,
              ),
              SizedBox(height: screenSize.height * 0.015),
              Row(
                children: buttonStates.keys.map((buttonText) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterButton(
                      text: buttonText,
                      isSelected: buttonText == selectedFilterButton,
                      onTap: () => onButtonToggle(buttonText),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
      toolbarHeight: screenSize.height * 0.18,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight * 2.8);
}
