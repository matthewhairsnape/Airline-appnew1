import 'dart:convert';
import 'package:airline_app/provider/user_data_provider.dart';
import 'package:airline_app/screen/app_widgets/bottom_button_bar.dart';
import 'package:airline_app/screen/app_widgets/loading.dart';
import 'package:airline_app/screen/app_widgets/main_button.dart';
import 'package:airline_app/screen/leaderboard/widgets/category_buttons_widget.dart';
import 'package:airline_app/screen/leaderboard/widgets/feedback_card.dart';
import 'package:airline_app/screen/leaderboard/widgets/review_status.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:airline_app/utils/global_variable.dart';

class DetailAirport extends ConsumerStatefulWidget {
  const DetailAirport({super.key});

  @override
  ConsumerState<DetailAirport> createState() => _DetailAirportState();
}

class _DetailAirportState extends ConsumerState<DetailAirport> {
  bool _clickedBookmark = false;
  Map<String, List<dynamic>> _bookmarkItems = {};
  late SharedPreferences _prefs;
  final dio = Dio();
  List<dynamic> airlineReviewLists = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initPrefs();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)!.settings.arguments as Map;
      fetchReviews(args['_id'], args['isAirline']);
    });
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadBookmarks();
  }

  void _loadBookmarks() {
    final String? bookmarksJson = _prefs.getString('bookmarks');
    if (bookmarksJson != null) {
      setState(() {
        _bookmarkItems = Map<String, List<dynamic>>.from(
          jsonDecode(bookmarksJson).map(
            (key, value) => MapEntry(key, List<dynamic>.from(value)),
          ),
        );
      });
    }
  }

  Future<void> _saveBookmarks() async {
    await _prefs.setString('bookmarks', json.encode(_bookmarkItems));
  }

  Future<void> _sharedBookMarkSaved(String bookMarkId) async {
    final userId = ref.watch(userDataProvider)?['userData']['_id'];

    if (userId != null) {
      setState(() {
        if (!_bookmarkItems.containsKey(userId)) {
          _bookmarkItems[userId] = [];
        }

        if (_clickedBookmark) {
          if (!_bookmarkItems[userId]!.contains(bookMarkId)) {
            _bookmarkItems[userId]!.add(bookMarkId);
          }
        } else {
          _bookmarkItems[userId]!.remove(bookMarkId);
          if (_bookmarkItems[userId]!.isEmpty) {
            _bookmarkItems.remove(userId);
          }
        }
      });

      await _saveBookmarks();
    }
  }

  Future<void> fetchReviews(String id, bool isAirline) async {
    try {
      final response = await dio.get(
        '$apiUrl/api/v2/entity-reviews',
        queryParameters: {'id': id, 'type': isAirline ? 'airline' : 'airport'},
      );

      if (response.statusCode == 200) {
        setState(() {
          airlineReviewLists = response.data['data'];

          print("Reviews: $airlineReviewLists");
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(userDataProvider)?['userData']['_id'];
    var args = ModalRoute.of(context)!.settings.arguments as Map;
    final String name = args['name'];
    final bool isAirline = args['isAirline'];
    final String descriptionBio = args['descriptionBio'];
    final String perksBio = args['perksBio'];
    final String trendingBio = args['trendingBio'];
    final String backgroundImage = args['backgroundImage'] ?? "";
    final String bookMarkId = args['_id'];

    final int totalReviews = args['totalReviews'];
    final bool isIncreasing = args['isIncreasing'];
    final num overallScore = args['overall'];

    if (userId != null &&
        _bookmarkItems[userId]?.contains(bookMarkId) == true) {
      _clickedBookmark = true;
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 315,
            leading: Padding(
              padding: const EdgeInsets.only(left: 24),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  Positioned.fill(
                    child: backgroundImage.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: backgroundImage,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Stack(
                              children: [
                                Positioned.fill(
                                  child: Image.asset(
                                    'assets/images/loading_image.jpg',
                                    fit: BoxFit.cover,
                                    opacity: const AlwaysStoppedAnimation(0.6),
                                  ),
                                ),
                                const Center(
                                  child: LoadingWidget(),
                                ),
                              ],
                            ),
                            errorWidget: (context, url, error) => Image.asset(
                              'assets/images/airline_background.jpg',
                              fit: BoxFit.cover,
                            ),
                          )
                        : Image.asset(
                            'assets/images/airline_background.jpg',
                            fit: BoxFit.cover,
                          ),
                  ),
                  Positioned(
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withAlpha(204),
                            Colors.transparent,
                          ],
                          stops: const [0.1, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 67,
                    right: 12,
                    child: Column(
                      children: [
                        IconButton(
                          onPressed: () async {
                            Share.share(
                                "Hey! 👋 Check out this amazing app that helps you discover and share travel experiences!\nJoin me on Airshiare and let's explore together! 🌟✈️\n\nDownload now: https://beta.itunes.apple.com/v1/app/6739448029",
                                subject:
                                    'Join me on Airshiare - Your Travel Companion!');
                          },
                          icon: SvgPicture.asset(
                            'assets/icons/share_white.svg',
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: IconButton(
                            onPressed: () {
                              setState(() {
                                _clickedBookmark = !_clickedBookmark;
                              });
                              _sharedBookMarkSaved(bookMarkId);
                            },
                            iconSize: 30,
                            icon: Icon(
                              _clickedBookmark
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              color: Colors.white,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ReviewStatus(
                        reviewStatus: isIncreasing,
                        overallScore: overallScore,
                        totalReviews: totalReviews),
                    SizedBox(height: 9),
                    Text(
                      name,
                      style: AppStyles.textStyle_24_600,
                      overflow: TextOverflow.visible,
                      softWrap: true,
                    ),
                    SizedBox(height: 2),
                    Text(
                      descriptionBio,
                      style: AppStyles.textStyle_15_400
                          .copyWith(color: Color(0xff38433E)),
                    ),
                    SizedBox(height: 14),
                    Text(
                      "Trending now:",
                      style: AppStyles.textStyle_14_600,
                    ),
                    Text(
                      trendingBio,
                      style: AppStyles.textStyle_14_400
                          .copyWith(color: Color(0xff38433E)),
                    ),
                    SizedBox(height: 14),
                    Text(
                      "Perks you'll love:",
                      style: AppStyles.textStyle_14_600,
                    ),
                    Text(
                      perksBio,
                      style: AppStyles.textStyle_14_400
                          .copyWith(color: Color(0xff38433E)),
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Category Ratings',
                          style: AppStyles.textStyle_18_600,
                        ),
                        IconButton(
                            onPressed: () {},
                            icon: Icon(Icons.switch_access_shortcut_sharp))
                      ],
                    ),
                    SizedBox(
                      height: 12,
                    ),
                    CategoryButtonsWidget(
                      isAirline: isAirline,
                      airportData: args,
                    ),
                  ],
                ),
              ),
              isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: LoadingWidget(),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: airlineReviewLists.asMap().entries.map((entry) {
                        final index = entry.key;
                        final singleReview = entry.value;
                        final reviewer = singleReview['reviewer'];

                        if (reviewer != null) {
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0),
                                child: FeedbackCard(
                                  thumbnailHeight: 189,
                                  singleFeedback: singleReview,
                                ),
                              ),
                              if (index != airlineReviewLists.length - 1)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24.0),
                                  child: Column(
                                    children: [
                                      SizedBox(height: 16),
                                      Divider(
                                          thickness: 1,
                                          color: Colors.grey.shade300),
                                      SizedBox(height: 24)
                                    ],
                                  ),
                                ),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      }).toList(),
                    )
            ]),
          )
        ],
      ),
      bottomNavigationBar: BottomButtonBar(
          child: MainButton(
        text: "Leave a review",
        onPressed: () =>
            Navigator.pushNamed(context, AppRoutes.reviewsubmissionscreen),
        icon: Icon(
          Icons.edit_outlined,
          color: Colors.white,
        ),
      )),
    );
  }
}
