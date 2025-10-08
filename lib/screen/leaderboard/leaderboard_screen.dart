import 'package:airline_app/screen/app_widgets/bottom_nav_bar.dart';
import 'package:airline_app/screen/app_widgets/custom_search_appbar.dart';
import 'package:airline_app/screen/app_widgets/keyboard_dismiss_widget.dart';
import 'package:airline_app/screen/app_widgets/loading.dart';
import 'package:airline_app/screen/leaderboard/widgets/airport_list.dart';
import 'package:airline_app/screen/leaderboard/widgets/feedback_card.dart';
import 'package:airline_app/screen/leaderboard/widgets/scoring_info_dialog.dart';
import 'package:airline_app/utils/app_localizations.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airline_app/provider/airline_airport_data_provider.dart';
import 'package:airline_app/provider/filter_button_provider.dart';
import 'package:airline_app/provider/leaderboard_filter_provider.dart';
import 'package:airline_app/controller/leaderboard_service.dart';
import 'package:airline_app/controller/top_review_controller.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  List airlineDataSortedByCleanliness = [];
  List airlineDataSortedByOnboardSevice = [];
  List<dynamic> trendingReviews = [];
  bool hasMore = true;
  bool isLoading = false;
  Map<String, bool> buttonStates = {
    "Airline": false,
    "Airport": false,
  };

  int expandedItems = 5;
  String filterType = 'Airline';
  bool isLeaderboardLoading = true;
  List<Map<String, dynamic>> leaderBoardList = [];
  double leftPadding = 24.0;

  final TopReviewService _topReviewService = TopReviewService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _mounted = true;

  @override
  void dispose() {
    _mounted = false;
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void toggleButton(String buttonText) {
    setState(() {
      buttonStates.updateAll((key, value) => false);
      buttonStates[buttonText] = true;
      filterType = buttonText;
      expandedItems = 5;
    });

    // Update filter type in providers
    ref.read(filterButtonProvider.notifier).setFilterType(buttonText);
    ref.read(leaderboardFilterProvider.notifier).setFilters(
          airType: buttonText,
          flyerClass: ref.read(leaderboardFilterProvider).flyerClass,
          category: ref.read(leaderboardFilterProvider).category,
          continents: ref.read(leaderboardFilterProvider).continents,
        );

    // Fetch new data with updated filter
    fetchLeaderboardData(page: 1);
  }

  Future<void> fetchLeaderboardData({int? page}) async {
    if (!_mounted) return;

    setState(() {
      isLoading = true;
    });

    final LeaderboardService leaderboardService = LeaderboardService();
    final filterState = ref.read(leaderboardFilterProvider);

    try {
      final result = await leaderboardService.getFilteredLeaderboard(
        airType: filterState.airType,
        flyerClass: filterState.flyerClass,
        category: filterState.category,
        searchQuery: _searchQuery,
        continents: filterState.continents,
        page: page ?? filterState.currentPage,
      );

      if (!_mounted) return;

      if (page == 1) {
        ref.read(airlineAirportProvider.notifier).setData(result);
      } else {
        ref.read(airlineAirportProvider.notifier).appendData(result);
      }

      setState(() {
        hasMore = result['hasMore'];
        isLoading = false;
      });
    } catch (e) {
      if (!_mounted) return;

      debugPrint('Error fetching leaderboard data: $e');
      setState(() {
        hasMore = false;
        isLoading = false;
      });
    }
  }

  void _handleSearchSubmit() {
    fetchLeaderboardData(page: 1);
  }

  Future<void> _initializeData() async {
    if (!_mounted) return;

    await Future.wait([
      fetchLeaderboardData(page: 1),
      fetchTrendingReviews(),
    ]);

    if (_mounted) {
      setState(() {
        isLeaderboardLoading = false;
      });
    }
  }

  // Handle load more data
  void loadMoreData() {
    if (hasMore) {
      // Increment page in provider
      ref.read(leaderboardFilterProvider.notifier).incrementPage();
      fetchLeaderboardData();
    }
  }

  Future<void> fetchTrendingReviews() async {
    try {
      final result = await _topReviewService.getTopReviews();
      setState(() {
        trendingReviews = result['data'];
      });
    } catch (e) {
      debugPrint('Error fetching trending reviews: $e');
    }
  }

  Future<bool> _onWillPop() async {
    return (await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Are you sure?'),
            content: Text('Do you want to exit the app?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('No'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                  SystemNavigator.pop(animated: true);
                  _goToHomeScreen();
                },
                child: Text('Yes'),
              ),
            ],
          ),
        )) ??
        false;
  }

  void _goToHomeScreen() {
    SystemNavigator.pop();
    SystemChannels.platform.invokeMethod('SystemNavigator.home');
  }

  void _handleSearchChanged(String value) {
    setState(() {
      _searchQuery = value.toLowerCase();
    });
    fetchLeaderboardData(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevents the default pop action
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _onWillPop;
        }
      },
      child: Scaffold(
        appBar: CustomSearchAppBar(
          searchController: _searchController,
          filterType: filterType,
          onSearchChanged: _handleSearchChanged,
          buttonStates: buttonStates,
          onButtonToggle: toggleButton,
          selectedFilterButton: ref.watch(filterButtonProvider),
        ),
        backgroundColor: Colors.white,
        bottomNavigationBar: const BottomNavBar(
          currentIndex: 0,
        ),
        body: Stack(
          children: [
            KeyboardDismissWidget(
              child: Column(
                children: [
                  Expanded(
                    child: isLeaderboardLoading
                        ? const Center(
                            child: LoadingWidget(),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            AppLocalizations.of(context)
                                                .translate(
                                                    'Top Ranked  Airlines'),
                                            style: AppStyles.textStyle_16_600
                                                .copyWith(
                                              color: const Color(0xff38433E),
                                            ),
                                          ),
                                          IconButton(
                                            icon:
                                                const Icon(Icons.info_outline),
                                            onPressed: () {
                                              final RenderBox button =
                                                  context.findRenderObject()
                                                      as RenderBox;
                                              final Offset offset = button
                                                  .localToGlobal(Offset.zero);
                                              showDialog(
                                                context: context,
                                                barrierColor:
                                                    Colors.transparent,
                                                builder:
                                                    (BuildContext context) {
                                                  return ScoringInfoDialog(
                                                      offset: offset);
                                                },
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                      _AirportListSection(
                                        leaderBoardList: ref
                                            .watch(airlineAirportProvider)
                                            .allData,
                                        expandedItems: expandedItems,
                                        onExpand: () {
                                          setState(() {
                                            expandedItems += 5;
                                          });
                                        },
                                        hasMore: hasMore,
                                        loadMoreData: loadMoreData,
                                      ),
                                      const SizedBox(height: 28),
                                      // Text(
                                      //   AppLocalizations.of(context)
                                      //       .translate('Trending Feedback'),
                                      //   style:
                                      //       AppStyles.textStyle_16_600.copyWith(
                                      //     color: const Color(0xff38433E),
                                      //   ),
                                      // ),
                                      // const SizedBox(height: 17),
                                    ],
                                  ),
                                ),
                                // NotificationListener<ScrollNotification>(
                                //   onNotification: (scrollNotification) {
                                //     if (scrollNotification
                                //         is ScrollUpdateNotification) {
                                //       setState(() {
                                //         leftPadding =
                                //             scrollNotification.metrics.pixels >
                                //                     0
                                //                 ? 0
                                //                 : 24.0;
                                //       });
                                //     }
                                //     return true;
                                //   },
                                //   child: Padding(
                                //     padding: EdgeInsets.only(left: leftPadding),
                                //     child: SingleChildScrollView(
                                //       scrollDirection: Axis.horizontal,
                                //       child: Row(
                                //         crossAxisAlignment:
                                //             CrossAxisAlignment.start,
                                //         children: trendingReviews.map(
                                //           (singleFeedback) {
                                //             return Padding(
                                //               padding: const EdgeInsets.only(
                                //                   right: 16),
                                //               child: Container(
                                //                 width: 299,
                                //                 decoration: BoxDecoration(
                                //                   borderRadius:
                                //                       BorderRadius.circular(8),
                                //                 ),
                                //                 child: ClipRRect(
                                //                   borderRadius:
                                //                       BorderRadius.circular(8),
                                //                   child: FeedbackCard(
                                //                     thumbnailHeight: 189,
                                //                     singleFeedback:
                                //                         singleFeedback,
                                //                   ),
                                //                 ),
                                //               ),
                                //             );
                                //           },
                                //         ).toList(),
                                //       ),
                                //     ),
                                //   ),
                                // ),
                                // const SizedBox(
                                //   height: 18,
                                // ),
                                // InkWell(
                                //   onTap: () {
                                //     Navigator.pushNamed(
                                //         context, AppRoutes.feedscreen);
                                //   },
                                //   child: Row(
                                //     mainAxisAlignment: MainAxisAlignment.center,
                                //     children: [
                                //       Text(
                                //         AppLocalizations.of(context)
                                //             .translate('See all feedback'),
                                //         style: AppStyles.textStyle_15_600,
                                //       ),
                                //       const Icon(Icons.arrow_forward)
                                //     ],
                                //   ),
                                // ),
                                // const SizedBox(
                                //   height: 16,
                                // ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              Container(
                color: Colors.grey.withAlpha(25),
                child: const Center(
                  child: LoadingWidget(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AirportListSection extends StatelessWidget {
  const _AirportListSection({
    required this.leaderBoardList,
    required this.expandedItems,
    required this.onExpand,
    required this.hasMore,
    required this.loadMoreData,
  });

  final int expandedItems;
  final List<Map<String, dynamic>> leaderBoardList;
  final VoidCallback onExpand;
  final bool hasMore;
  final VoidCallback loadMoreData;

  // In the _AirportListSection widget, update the build method:

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (leaderBoardList.isEmpty)
          Center(
            child: Text(
              "No data found",
              style: AppStyles.textStyle_16_600.copyWith(
                color: const Color(0xff38433E),
              ),
            ),
          )
        else
          Column(
            children: [
              Column(
                children: leaderBoardList.asMap().entries.map((entry) {
                  final int index = entry.key;
                  final Map<String, dynamic> singleAirport = entry.value;
                  return AirportList(
                    airportData: singleAirport,
                    rank: index + 1,
                  );
                }).toList(),
              ),
              const SizedBox(height: 19),
              if (hasMore)
                Center(
                  child: GestureDetector(
                    onTap: loadMoreData,
                    child: IntrinsicWidth(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                              AppLocalizations.of(context)
                                  .translate('Expand more'),
                              style: AppStyles.textStyle_18_600
                                  .copyWith(fontSize: 15)),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_downward),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
