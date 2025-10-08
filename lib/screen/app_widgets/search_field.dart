import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchBarWidget extends ConsumerWidget {
  final TextEditingController searchController;
  final String filterType;
  final Function(String) onSearchChanged;

  const SearchBarWidget({
    super.key,
    required this.searchController,
    required this.filterType,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenSize = MediaQuery.of(context).size;

    return Container(
      width: screenSize.width * 0.7,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        border: Border.all(
          color: Colors.grey.withAlpha(51),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            offset: Offset(0, 4),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          style: AppStyles.textStyle_16_600.copyWith(color: Colors.black87),
          decoration: InputDecoration(
            hintText: 'Search...',
            hintStyle: AppStyles.textStyle_16_600
                .copyWith(color: Colors.grey.withAlpha(179)),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.grey.withAlpha(179),
              size: 22,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
