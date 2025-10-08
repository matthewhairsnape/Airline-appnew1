import 'package:airline_app/screen/leaderboard/widgets/category_rating_options.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:airline_app/utils/global_variable.dart';
import 'package:airline_app/screen/app_widgets/loading.dart';

class CategoryButtonsWidget extends StatefulWidget {
  const CategoryButtonsWidget(
      {super.key, required this.isAirline, required this.airportData});

  final Map airportData;
  final bool isAirline;

  @override
  State<CategoryButtonsWidget> createState() => _CategoryButtonsWidgetState();
}

class _CategoryButtonsWidgetState extends State<CategoryButtonsWidget> {
  bool isExpanded = false;
  bool isLoading = true;
  Map<String, dynamic> response = {};

  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    fetchCategoryRatings();
  }

  Future<void> fetchCategoryRatings() async {
    setState(() {
      isLoading = true;
    });

    try {
      final result = await _dio.get(
        '$apiUrl/api/v2/category-ratings',
        queryParameters: {
          'type': widget.isAirline ? 'airline' : 'airport',
          'id': widget.airportData['_id'],
        },
      );

      setState(() {
        response = result.data['data'];
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching category ratings: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget buildCategoryRow(String iconUrl, String label, String badgeScore) {
    return Expanded(
      child: CategoryRatingOptions(
        iconUrl: iconUrl,
        label: label,
        badgeScore: badgeScore,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print("------------------------------");
    print(response);
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    widget.isAirline
                        ? buildCategoryRow(
                            'assets/icons/review_icon_boarding.svg',
                            'Boarding and\nArrival Experience',
                            response['departureArrival']?.toStringAsFixed(1) ??
                                '0')
                        : buildCategoryRow(
                            'assets/icons/review_icon_access.svg',
                            'Accessibility',
                            response['accessibility']?.toStringAsFixed(1) ??
                                '0'),
                    const SizedBox(width: 16),
                    widget.isAirline
                        ? buildCategoryRow(
                            'assets/icons/review_icon_comfort.svg',
                            'Comfort',
                            response['comfort']?.toStringAsFixed(1) ?? '0')
                        : buildCategoryRow(
                            'assets/icons/review_icon_wait.svg',
                            'Wait Times',
                            response['waitTimes']?.toStringAsFixed(1) ?? '0'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    widget.isAirline
                        ? buildCategoryRow(
                            'assets/icons/review_icon_cleanliness.svg',
                            'Cleanliness',
                            response['cleanliness']?.toStringAsFixed(1) ?? '0')
                        : buildCategoryRow(
                            'assets/icons/review_icon_help.svg',
                            'Helpfulness/Easy Travel',
                            response['helpfulness']?.toStringAsFixed(1) ?? '0'),
                    const SizedBox(width: 16),
                    widget.isAirline
                        ? buildCategoryRow(
                            'assets/icons/review_icon_onboard.svg',
                            'Onboard Service',
                            response['onboardService']?.toStringAsFixed(1) ??
                                '0')
                        : buildCategoryRow(
                            'assets/icons/review_icon_ambience.svg',
                            'Ambience/Comfort',
                            response['ambienceComfort']?.toStringAsFixed(1) ??
                                '0'),
                  ],
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      widget.isAirline
                          ? buildCategoryRow(
                              'assets/icons/review_icon_food.svg',
                              'Airline Food',
                              response['foodBeverage'].toStringAsFixed(1) ??
                                  '0')
                          : buildCategoryRow(
                              'assets/icons/review_icon_food.svg',
                              'Airport Food and Shopping',
                              response['foodBeverage'].toStringAsFixed(1) ??
                                  '0'),
                      const SizedBox(width: 16),
                      widget.isAirline
                          ? buildCategoryRow(
                              'assets/icons/review_icon_entertainment.svg',
                              'In-Flight\nEntertainment',
                              response['entertainmentWifi']
                                      .toStringAsFixed(1) ??
                                  '0')
                          : buildCategoryRow(
                              'assets/icons/review_icon_entertainment.svg',
                              'Amenities and Facilities',
                              response['amenities']
                                      .toStringAsFixed(1) ??
                                  '0'),
                    ],
                  ),
                ],
                const SizedBox(height: 19),
                InkWell(
                  onTap: () {
                    setState(() {
                      isExpanded = !isExpanded;
                    });
                  },
                  child: IntrinsicWidth(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                            isExpanded
                                ? "Show less categories"
                                : "Show more categories",
                            style: AppStyles.textStyle_18_600
                                .copyWith(fontSize: 15)),
                        const SizedBox(width: 8),
                        Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ],
        ),
        if (isLoading)
          Container(
            color: Colors.grey.withAlpha(51),
            child: const Center(
              child: LoadingWidget(),
            ),
          ),
      ],
    );
  }
}
