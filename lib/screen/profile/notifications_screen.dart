import 'package:airline_app/screen/profile/widget/basic_button.dart';

import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:airline_app/utils/app_localizations.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Map<String, bool> _expandedItems = {
    'points': false,
    'review': true,
    'flight': false,
    'airport': true,
  };

  final List<Map<String, String>> notifications = [
    {
      'id': 'review',
      'title': 'Review was shared by Steve',
      'description': 'The response goes here, creating the second row next.',
    },
    {
      'id': 'flight',
      'title': 'Flight coming up Soon',
      'description': 'The response goes here, creating the second row next.',
    },
    {
      'id': 'airport',
      'title': 'Review your Airport experience',
      'description': 'The response goes here, creating the second row next.',
    },
  ];

  List<bool> isSelected = [false, false, false, false];

  void toggleSelection(int index) {
    setState(() {
      isSelected[index] = !isSelected[index]; // Toggle the selected state
    });
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      toolbarHeight: MediaQuery.of(context).size.height * 0.1,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_sharp, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      title: Text(AppLocalizations.of(context).translate('Notifications'),
          style: AppStyles.textStyle_16_600.copyWith(color: Colors.black)),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(4.0),
        child: Container(color: Colors.black, height: 4.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Text('Type', style: AppStyles.textStyle_16_600),
          ),
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(isSelected.length, (index) {
                return GestureDetector(
                  onTap: () =>
                      toggleSelection(index), // Toggle selection on tap
                  child: BasicButton(
                    mywidth: index == 0 ? 49 : (index == 2 ? 94 : 161),
                    myheight: 40,
                    myColor: isSelected[index]
                        ? AppStyles.mainColor
                        : Colors.white, // Change color based on selection
                    btntext: index == 0
                        ? "All"
                        : "Category goes here", // Update button text accordingly
                  ),
                );
              }),
            ),
          ),
          SizedBox(height: 20),
          Divider(thickness: 2, color: Colors.black),
          // Use ListView.builder for better performance
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final isExpanded =
                  _expandedItems[notification['id'] ?? ''] ?? false;

              return Column(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _expandedItems[notification['id'] ?? ''] = !isExpanded;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notification['title'] ?? '',
                              style: AppStyles.textStyle_16_600,
                            ),
                          ),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isExpanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          notification['description'] ?? '',
                          style: AppStyles.textStyle_14_600
                              .copyWith(color: Colors.grey[600]),
                        ),
                      ),
                    ),
                ],
              );
            },
          )
        ],
      ),
    );
  }
}
