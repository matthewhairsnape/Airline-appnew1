import 'package:airline_app/provider/airline_airport_data_provider.dart';
import 'package:airline_app/provider/filter_button_provider.dart';
import 'package:airline_app/screen/app_widgets/appbar_widget.dart';
import 'package:airline_app/screen/app_widgets/bottom_button_bar.dart';
import 'package:airline_app/screen/app_widgets/custom_snackbar.dart';
import 'package:airline_app/screen/app_widgets/filter_button.dart';
import 'package:airline_app/screen/app_widgets/main_button.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:airline_app/utils/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airline_app/controller/leaderboard_service.dart';
import 'package:airline_app/provider/leaderboard_filter_provider.dart';
import 'package:airline_app/screen/app_widgets/loading.dart';

class LeaderboardFilterScreen extends ConsumerStatefulWidget {
  const LeaderboardFilterScreen({super.key});

  @override
  ConsumerState<LeaderboardFilterScreen> createState() =>
      _LeaderboardFilterScreenState();
}

class _LeaderboardFilterScreenState
    extends ConsumerState<LeaderboardFilterScreen> {
  // Declare continents and selectedStates as instance variables
  final LeaderboardService _leaderboardService = LeaderboardService();
  final List<dynamic> airType = [
    "Airline",
    "Airport",
  ];

  final List airlineCategory = [
    "Flight Experience",
    "Comfort",
    "Cleanliness",
    "Onboard",
    "Airline Food",
    "Entertainment & WiFi"
  ];

  final List airportCategory = [
    "Accessibility",
    "Wait Times",
    "Helpfulness",
    "Ambience",
    "Airport Food",
    "Amenities"
  ];

  bool categoryIsExpanded = true;
  final List<dynamic> continent = [
    "Africa",
    "Asia",
    "Europe",
    "Americas",
    "Oceania"
  ];

  bool continentIsExpanded = true;
  List<String> currentCategories = [];
  final List<dynamic> flyerClass = [
    "Business",
    "Premium Economy",
    "Economy",
  ];

  bool flyerClassIsExpanded = true;
  String selectedAirType = "Airline";
  late List<bool> selectedAirTypeStates;
  String selectedCategory = "";
  late List<bool> selectedCategoryStates;
  late List<bool> selectedContinentStates;
  List<dynamic> selectedContinents = [];
  String selectedFlyerClass = "Business";
  late List<bool> selectedFlyerClassStates;
  bool typeIsExpanded = true;

  @override
  void initState() {
    super.initState();
    selectedAirTypeStates =
        List.generate(airType.length, (index) => index == 0);
    selectedFlyerClassStates =
        List.generate(flyerClass.length, (index) => index == 0);
    selectedContinentStates =
        List.generate(continent.length, (index) => index == 0);
    updateCurrentCategories();
  }

  void updateCurrentCategories() {
    if (selectedAirType == "Airport") {
      currentCategories = List<String>.from(airportCategory);
    } else if (selectedAirType == "Airline") {
      currentCategories = List<String>.from(airlineCategory);
    }
    selectedCategoryStates =
        List.generate(currentCategories.length, (index) => false);
  }

  void _toggleOnlyOneFilter(int index, List selectedStates) {
    setState(() {
      // Set all states to false first
      for (int i = 0; i < selectedStates.length; i++) {
        selectedStates[i] = false;
      }
      // Set only the clicked button to true
      selectedStates[index] = true;

      // Update selected values based on which list is being modified
      if (selectedStates == selectedAirTypeStates) {
        selectedAirType = airType[index];
        updateCurrentCategories();
      } else if (selectedStates == selectedFlyerClassStates) {
        selectedFlyerClass = flyerClass[index];
      } else if (selectedStates == selectedCategoryStates) {
        selectedCategory = currentCategories[index];
      }
    });
    // Update the filtered list after selection
  }

  Widget _buildTypeCategory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.of(context).translate('Type'),
                style: AppStyles.textStyle_18_600),
            IconButton(
                onPressed: () {
                  setState(() {
                    typeIsExpanded = !typeIsExpanded;
                  });
                },
                icon: Icon(
                    typeIsExpanded ? Icons.expand_more : Icons.expand_less)),
          ],
        ),
        Visibility(
            visible: typeIsExpanded,
            child: Column(
              children: [
                const SizedBox(height: 17),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(
                      airType.length,
                      (index) => FilterButton(
                            text: AppLocalizations.of(context)
                                .translate(airType[index]),
                            isSelected: selectedAirTypeStates[index],
                            onTap: () => _toggleOnlyOneFilter(
                                index, selectedAirTypeStates),
                          )),
                ),
              ],
            ))
      ],
    );
  }

  Widget _buildFlyerClassLeaderboards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.of(context).translate('Flyer Class'),
                style: AppStyles.textStyle_18_600),
            IconButton(
                onPressed: () {
                  setState(() {
                    flyerClassIsExpanded = !flyerClassIsExpanded;
                  });
                },
                icon: Icon(flyerClassIsExpanded
                    ? Icons.expand_more
                    : Icons.expand_less)),
          ],
        ),
        Visibility(
          visible: flyerClassIsExpanded,
          child: Column(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(
                    flyerClass.length,
                    (index) => FilterButton(
                          text: AppLocalizations.of(context)
                              .translate('${flyerClass[index]}'),
                          isSelected: selectedFlyerClassStates[index],
                          onTap: () => _toggleOnlyOneFilter(
                              index, selectedFlyerClassStates),
                        )),
              ),
            ],
          ),
        ),
      ],
    );
  }

Widget _buildCategoryLeaderboards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.of(context).translate('Categories'),
                style: AppStyles.textStyle_18_600),
            IconButton(
                onPressed: () {
                  setState(() {
                    categoryIsExpanded = !categoryIsExpanded;
                  });
                },
                icon: Icon(categoryIsExpanded
                    ? Icons.expand_more
                    : Icons.expand_less)),
          ],
        ),
        Visibility(
          visible: categoryIsExpanded,
          child: Column(
            children: [
              selectedAirType == "All"
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "To access this feature, please select an airline or airport.",
                        style: AppStyles.textStyle_15_600,
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(
                          currentCategories.length,
                          (index) => FilterButton(
                                text: AppLocalizations.of(context)
                                    .translate(currentCategories[index]),
                                isSelected: selectedCategoryStates[index],
                                onTap: () => _toggleOnlyOneFilter(
                                    index, selectedCategoryStates),
                              )),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppbarWidget(
          title: "Filter",
          onBackPressed: () => Navigator.pop(context),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
                        _buildTypeCategory(),
                        const SizedBox(height: 17),
                        selectedAirType == "Airport" 
                            ? Text(
                                "",
                                style: AppStyles.textStyle_15_400.copyWith(color: Color(0xff38433E)),
                              )
                            : _buildFlyerClassLeaderboards(),
                        const SizedBox(height: 17),              _buildCategoryLeaderboards(),
              const SizedBox(height: 17),
            ],
          ),
        ),
        bottomNavigationBar: BottomButtonBar(
          child: MainButton(
            text: AppLocalizations.of(context).translate('Apply'),
            onPressed: () async {
              try {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: LoadingWidget()),
                );

                // Save filter options and reset page to 1
                ref.read(leaderboardFilterProvider.notifier).setFilters(
                      airType: selectedAirType,
                      flyerClass: selectedFlyerClass ,
                      category:
                          selectedCategory.isEmpty ? null : selectedCategory,
                      continents: selectedContinents.isEmpty ||
                              selectedContinents[0] == "All"
                          ? ["Africa", "Asia", "Europe", "Americas", "Oceania"]
                          : selectedContinents.cast<String>(),
                    );

                final result = await _leaderboardService.getFilteredLeaderboard(
                  airType: selectedAirType,
                  flyerClass: selectedFlyerClass,
                  category: selectedCategory.isEmpty ? null : selectedCategory,
                  continents: selectedContinents.isEmpty ||
                          selectedContinents[0] == "All"
                      ? ["Africa", "Asia", "Europe", "Americas", "Oceania"]
                      : selectedContinents.cast<String>(),
                  page: 1,
                );
                ref
                    .read(filterButtonProvider.notifier)
                    .setFilterType(selectedAirType);
                ref.read(airlineAirportProvider.notifier).setData(result);
                if (!context.mounted) return;
                Navigator.pop(context);
                Navigator.pop(context);
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context);
                CustomSnackBar.error(
                    context, 'Failed to fetch filtered data: ${e.toString()}');
              }
            },
            // color: AppStyles.backgroundColor,
          ),
        ));
  }
}
