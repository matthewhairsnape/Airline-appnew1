import 'package:airline_app/screen/app_widgets/bottom_nav_bar.dart';
import 'package:airline_app/screen/app_widgets/keyboard_dismiss_widget.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:airline_app/provider/leaderboard_provider.dart';
import 'package:airline_app/screen/app_widgets/loading_widget.dart';
import 'package:airline_app/models/leaderboard_category_model.dart';
import 'package:airline_app/services/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  bool isExpanded = false;
  static const String _trustCopy =
      'Leaderboard scores are calculated from 11.5K verified passenger reviews.';

  // Get categories from the service
  List<LeaderboardCategory> get metricCategories =>
      LeaderboardCategoryService.getPrimaryCategories();

  List<LeaderboardCategory> get travelClassCategories =>
      LeaderboardCategoryService.getTravelClassCategories();

  List<LeaderboardCategory> get airportCategories =>
      LeaderboardCategoryService.getAirportCategories();

  // Get current categories based on mode
  List<LeaderboardCategory> _getCurrentCategories() {
    final isAirportMode = ref.watch(leaderboardProvider).isAirportMode;
    return isAirportMode ? airportCategories : metricCategories;
  }

  // Rankings data - Top airline for each category
  static const Map<String, String> _categoryRankings = {
    'First Class': 'All Nippon Airways (ANA)',
    'Business Class': 'Wizz Air Abu Dhabi',
    'Premium Economy': 'El Al',
    'Economy': 'Garuda Indonesia',
    'Airport Experience': 'Nordwind Airlines',
    'F&B': 'Jetstar Japan',
    'Seat Comfort': 'Bulgaria Air',
    'IFE and Wifi': 'StarLux',
    'Onboard Service': 'Garuda Indonesia',
    'Cleanliness': 'Garuda Indonesia',
  };

  String? _getTopAirlineForCategory(String categoryTab) {
    return _categoryRankings[categoryTab];
  }

  @override
  void initState() {
    super.initState();
    // Data loads automatically from cache/local seed via provider
  }

  void _onWillPop() {
    Navigator.pushReplacementNamed(context, AppRoutes.startreviews);
  }

  /// Build mode switcher (Airline vs Airport)
  Widget _buildModeSwitcher() {
    final isAirportMode = ref.watch(leaderboardProvider).isAirportMode;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                ref.read(leaderboardProvider.notifier).switchToAirlineMode();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !isAirportMode ? Colors.black : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Airlines',
                  textAlign: TextAlign.center,
                  style: AppStyles.textStyle_14_600.copyWith(
                    color: !isAirportMode ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                ref.read(leaderboardProvider.notifier).switchToAirportMode();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isAirportMode ? Colors.black : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Airports',
                  textAlign: TextAlign.center,
                  style: AppStyles.textStyle_14_600.copyWith(
                    color: isAirportMode ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Convert icon name to Material Icon
  IconData _getIconForCategory(String iconName) {
    switch (iconName) {
      case 'business':
        return Icons.workspace_premium;
      case 'economy':
        return Icons.airline_seat_recline_normal;
      case 'wifi':
        return Icons.wifi;
      case 'people':
        return Icons.people;
      case 'chair':
        return Icons.chair;
      case 'restaurant':
        return Icons.restaurant;
      case 'schedule':
        return Icons.schedule;
      case 'movie':
        return Icons.movie;
      case 'aircraft':
        return Icons.airplanemode_active;
      case 'arrival':
        return Icons.flight_land;
      case 'laptop':
        return Icons.laptop;
      case 'cleaning':
        return Icons.cleaning_services;
      default:
        return Icons.star;
    }
  }

  String _formatLastUpdated(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Last updated just now';
    } else if (difference.inMinutes < 60) {
      return 'Last updated ${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return 'Last updated ${difference.inHours} hr ago';
    } else {
      return 'Last updated on ${timestamp.toLocal().toString().substring(0, 16)}';
    }
  }

  Widget _buildLeaderboardTab() {
    return KeyboardDismissWidget(
      child: Column(
        children: [
          // Mode Switcher (Airline vs Airport)
          _buildModeSwitcher(),

          // Only show travel class filter for airline mode
          if (!ref.watch(leaderboardProvider).isAirportMode)
            _buildTravelClassFilter(),

          // Category Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _getCurrentCategories().asMap().entries.map((entry) {
                  final int index = entry.key;
                  final LeaderboardCategory category = entry.value;
                  final leaderboardState = ref.watch(leaderboardProvider);
                  final bool isSelected =
                      category.tab == leaderboardState.selectedCategory;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        isExpanded = false;
                      });
                      ref
                          .read(leaderboardProvider.notifier)
                          .changeCategory(category.tab);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              isSelected ? Colors.black : Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getIconForCategory(category.icon),
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            category.tab,
                            style: AppStyles.textStyle_14_600.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Consumer(
              builder: (context, ref, child) {
                final leaderboardState = ref.watch(leaderboardProvider);
                final isAirportMode = leaderboardState.isAirportMode;
                final selectedCategory =
                    LeaderboardCategoryService.getCategoryByTab(
                          leaderboardState.selectedCategory,
                        ) ??
                        (isAirportMode ? airportCategories.first : metricCategories.first);
                return Text(
                  selectedCategory.description,
                  style: AppStyles.textStyle_14_400.copyWith(
                    color: Colors.grey.shade600,
                  ),
                );
              },
            ),
          ),

          if (_showTrustBanner)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: _buildTrustIndicator(),
            ),

          Consumer(
            builder: (context, ref, child) {
              final lastUpdated = ref.watch(leaderboardProvider).lastUpdated;
              if (lastUpdated == null) {
                return const SizedBox(height: 8);
              }
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatLastUpdated(lastUpdated),
                      style: AppStyles.textStyle_12_400.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Airlines List
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _buildLeaderboardContent(),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardContent() {
    final leaderboardState = ref.watch(leaderboardProvider);

    if (leaderboardState.isLoading) {
      return const Center(
        child: LoadingWidget(),
      );
    }

    if (leaderboardState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading leaderboard',
              style: AppStyles.textStyle_18_600.copyWith(
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              leaderboardState.error!,
              style: AppStyles.textStyle_14_400.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(leaderboardProvider.notifier).refresh();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    const collapsedCount = 5;
    const expandedCount = 10;

    // Get data based on mode
    final isAirportMode = leaderboardState.isAirportMode;
    final displayedItems = isAirportMode
        ? (isExpanded
            ? leaderboardState.airports.take(expandedCount).toList()
            : leaderboardState.airports.take(collapsedCount).toList())
        : (isExpanded
            ? leaderboardState.airlines.take(expandedCount).toList()
            : leaderboardState.airlines.take(collapsedCount).toList());

    final hasMoreThanCollapsed = isAirportMode
        ? leaderboardState.airports.length > collapsedCount
        : leaderboardState.airlines.length > collapsedCount;

    // Get the selected category to use its icon
    final selectedCategory = LeaderboardCategoryService.getCategoryByTab(
          leaderboardState.selectedCategory,
        ) ??
        (isAirportMode ? airportCategories.first : metricCategories.first);

    return Column(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.decelerate,
            switchOutCurve: Curves.easeIn,
            child: ListView.builder(
              key: ValueKey('${leaderboardState.selectedCategory}-$isExpanded-${isAirportMode}'),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: displayedItems.length,
              itemBuilder: (context, index) {
                final item = displayedItems[index];
                final rank = index + 1;

                // Get medal for top 3
                String? medalEmoji;
                if (rank == 1) {
                  medalEmoji = '🥇';
                } else if (rank == 2) {
                  medalEmoji = '🥈';
                } else if (rank == 3) {
                  medalEmoji = '🥉';
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade100,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Rank Badge or Medal
                      Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 12),
                        child: Center(
                          child: medalEmoji != null
                              ? Text(
                                  medalEmoji,
                                  style: const TextStyle(fontSize: 28),
                                )
                                : Text(
                                    '$rank',
                                    style: AppStyles.textStyle_16_600.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                        ),
                      ),

                      // Logo (Airline or Airport)
                      isAirportMode
                          ? _buildAirportLogo(item)
                          : _buildAirlineLogo(item),

                      const SizedBox(width: 16),

                      // Name and Movement + Score
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    isAirportMode
                                        ? (item['display_name'] ?? item['name'] ?? 'Unknown Airport')
                                        : (item['name'] ?? 'Unknown Airline'),
                                    style:
                                        AppStyles.textStyle_16_600.copyWith(
                                      color: Colors.black,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (item['movement'] != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: item['movement'] == 'up'
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          item['movement'] == 'up'
                                              ? Icons.keyboard_arrow_up
                                              : Icons.keyboard_arrow_down,
                                          color: item['movement'] == 'up'
                                              ? Colors.green
                                              : Colors.red,
                                          size: 16,
                                        ),
                                        Text(
                                          '${item['previousRank']}',
                                          style: AppStyles.textStyle_12_600
                                              .copyWith(
                                            color: item['movement'] == 'up'
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (isAirportMode && item['location'] != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    item['location'],
                                    style: AppStyles.textStyle_12_400.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Category Icon - uses selected category's icon
                      Icon(
                        _getIconForCategory(selectedCategory.icon),
                        color: Colors.black,
                        size: 20,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        // Expand/Collapse Button
        if (!isExpanded && hasMoreThanCollapsed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    isExpanded = true;
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Show More (Top 10)',
                        style: AppStyles.textStyle_14_600.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        else if (isExpanded && hasMoreThanCollapsed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    isExpanded = false;
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Show Top 5',
                        style: AppStyles.textStyle_14_600.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.keyboard_arrow_up,
                        color: Colors.grey.shade700,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Build compact likes widget
  Widget _buildCompactLikes(List<Map<String, dynamic>> likes) {
    if (likes.isEmpty) {
      return const Text(
        'No likes',
        style: TextStyle(
          color: Colors.grey,
          fontSize: 10,
        ),
      );
    }

    // Show only the first like as a compact bubble
    final firstLike = likes.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('😊', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${firstLike['text']} (${firstLike['count']})',
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelClassFilter() {
    final classes = travelClassCategories;
    if (classes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Consumer(
        builder: (context, ref, child) {
          final leaderboardState = ref.watch(leaderboardProvider);
          final selectedTravelClass = leaderboardState.selectedTravelClass;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: classes.map((travelClass) {
                final bool isSelected = travelClass.tab == selectedTravelClass;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      isExpanded = false;
                    });
                    ref
                        .read(leaderboardProvider.notifier)
                        .changeTravelClass(travelClass.tab);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getIconForCategory(travelClass.icon),
                          color:
                              isSelected ? Colors.white : Colors.grey.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          travelClass.tab,
                          style: AppStyles.textStyle_14_600.copyWith(
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  /// Build compact dislikes widget
  Widget _buildCompactDislikes(List<Map<String, dynamic>> dislikes) {
    if (dislikes.isEmpty) {
      return const Text(
        'No dislikes',
        style: TextStyle(
          color: Colors.grey,
          fontSize: 10,
        ),
      );
    }

    // Show only the first dislike as a compact bubble
    final firstDislike = dislikes.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('😞', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${firstDislike['text']} (${firstDislike['count']})',
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _onWillPop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            'Leaderboard',
            style: AppStyles.textStyle_20_600.copyWith(
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        bottomNavigationBar: const BottomNavBar(
          currentIndex: 2,
        ),
        body: _buildLeaderboardTab(),
      ),
    );
  }

  /// Build airline logo widget (network or fallback)
  /// Uses multi-fallback: Supabase URL -> AirHex -> Daisycon -> Placeholder
  Widget _buildAirlineLogo(Map<String, dynamic> airline, {double size = 48}) {
    final logoUrls = _getLogoUrlsWithFallbacks(airline);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: logoUrls.isNotEmpty
            ? _MultiSourceImage(
                urls: logoUrls,
                size: size,
                fallback: _buildFallbackIcon(size),
              )
            : _buildFallbackIcon(size),
      ),
    );
  }

  /// Get list of logo URLs to try in order (with fallbacks)
  List<String> _getLogoUrlsWithFallbacks(Map<String, dynamic> airline) {
    final urls = <String>[];
    
    // Extract IATA and ICAO codes
    final iataCode =
        (airline['iataCode'] ?? airline['iata_code'])?.toString().toUpperCase();
    final icaoCode =
        (airline['icaoCode'] ?? airline['icao_code'])?.toString().toUpperCase();
    
    // 1. Primary: Supabase logo_url (if valid)
    final rawLogo = airline['logo']?.toString() ?? airline['logo_url']?.toString();
    if (rawLogo != null && rawLogo.isNotEmpty && _isValidHttpUrl(rawLogo)) {
      // Replace kiwi.com URLs (404) with AirHex (high quality)
      if (rawLogo.contains('kiwi.com') && iataCode != null && iataCode.length >= 2) {
        urls.add('https://content.airhex.com/content/logos/airlines_${iataCode}_512_512_s.png');
      } else if (!rawLogo.contains('kiwi.com')) {
        urls.add(rawLogo);
      }
    }
    
    // 2. Override map (if available)
    if (iataCode != null && _airlineLogoOverrides.containsKey(iataCode)) {
      final overrideUrl = _airlineLogoOverrides[iataCode];
      if (overrideUrl != null && !urls.contains(overrideUrl)) {
        urls.add(overrideUrl);
      }
    }
    
    // 3. AirHex CDN (_512_512_s.png format - high quality, public, no auth)
    if (iataCode != null && iataCode.length >= 2) {
      final airhexUrl = 'https://content.airhex.com/content/logos/airlines_${iataCode}_512_512_s.png';
      if (!urls.contains(airhexUrl)) {
        urls.add(airhexUrl);
      }
    }
    
    // 4. Daisycon (free public API - high quality)
    if (iataCode != null && iataCode.length >= 2) {
      final daisyconUrl = 'https://images.daisycon.io/airline/?width=600&height=300&color=ffffff&iata=$iataCode';
      if (!urls.contains(daisyconUrl)) {
        urls.add(daisyconUrl);
      }
    }
    
    // 5. Try ICAO-based AirHex as last resort (high quality)
    if (icaoCode != null && icaoCode.length >= 2) {
      final airhexIcaoUrl = 'https://content.airhex.com/content/logos/airlines_${icaoCode}_512_512_s.png';
      if (!urls.contains(airhexIcaoUrl)) {
        urls.add(airhexIcaoUrl);
      }
    }
    
    return urls;
  }

  Widget _buildFallbackIcon(double size) {
    return Icon(
      Icons.flight,
      color: Colors.grey.shade600,
      size: size * 0.5,
    );
  }

  /// Build airport logo widget (simpler than airline - uses icon or placeholder)
  Widget _buildAirportLogo(Map<String, dynamic> airport, {double size = 48}) {
    final logoUrl = airport['logo']?.toString() ?? airport['logo_url']?.toString();
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: logoUrl != null && logoUrl.isNotEmpty && _isValidHttpUrl(logoUrl)
            ? _MultiSourceImage(
                urls: [logoUrl],
                size: size,
                fallback: _buildAirportFallbackIcon(size),
              )
            : _buildAirportFallbackIcon(size),
      ),
    );
  }

  Widget _buildAirportFallbackIcon(double size) {
    return Icon(
      Icons.airplanemode_active,
      color: Colors.grey.shade600,
      size: size * 0.5,
    );
  }


  String? _resolveLogoUrl(Map<String, dynamic> airline) {
    // Check both 'logo' and 'logo_url' fields first
    final rawLogo = airline['logo']?.toString() ?? airline['logo_url']?.toString();
    
    // Extract IATA and ICAO codes first (needed for airhex.com replacement)
    final iataCode =
        (airline['iataCode'] ?? airline['iata_code'])?.toString().toUpperCase();
    final icaoCode =
        (airline['icaoCode'] ?? airline['icao_code'])?.toString().toUpperCase();
    
    // 1. If we already have a valid HTTP URL, use it directly.
    // But replace airhex.com URLs (require auth) with kiwi.com
    if (rawLogo != null && rawLogo.isNotEmpty && rawLogo.trim().isNotEmpty) {
      if (_isValidHttpUrl(rawLogo)) {
        // If it's a kiwi.com URL (404 errors), replace with airhex.com
        if (rawLogo.contains('kiwi.com')) {
          if (iataCode != null && iataCode.length >= 2) {
            final airhexUrl = 'https://content.airhex.com/content/logos/airlines_${iataCode}_512_512_s.png';
            debugPrint('🔄 Replacing kiwi.com URL with airhex.com: $airhexUrl for ${airline['name']}');
            return airhexUrl;
          }
        }
        debugPrint('✅ Using logo from airline data: $rawLogo for ${airline['name']}');
        return rawLogo;
      } else {
        debugPrint('⚠️ Logo is not a valid URL: $rawLogo for ${airline['name']}');
      }
    }
    
    debugPrint('🔍 Resolving logo for airline: ${airline['name']}, IATA: $iataCode, ICAO: $icaoCode, rawLogo: $rawLogo');

    // If it's a storage path, attempt to build a public URL.
    if (rawLogo != null && rawLogo.isNotEmpty && SupabaseService.isInitialized && rawLogo.contains('/')) {
        final parts = rawLogo.split('/');
        if (parts.length >= 2) {
          final bucket = parts.first;
          final path = parts.sublist(1).join('/');
          try {
            final publicUrl =
                SupabaseService.client.storage.from(bucket).getPublicUrl(path);
            if (_isValidHttpUrl(publicUrl)) {
              return publicUrl;
            }
          } catch (_) {
            // Ignore and fall back to CDN below.
          }
        }
      }

    // 2. Use an override map if we have an exact match.
    if (iataCode != null && _airlineLogoOverrides.containsKey(iataCode)) {
      final overrideUrl = _airlineLogoOverrides[iataCode];
      debugPrint('✅ Using logo override for $iataCode: $overrideUrl');
      return overrideUrl;
    }
    if (icaoCode != null && _airlineLogoOverrides.containsKey(icaoCode)) {
      final overrideUrl = _airlineLogoOverrides[icaoCode];
      debugPrint('✅ Using logo override for ICAO $icaoCode: $overrideUrl');
      return overrideUrl;
    }

    // 3. Fall back to a public CDN that serves logos by IATA code.
    // Use airhex.com CDN with _512_512_s.png format (high quality, public, no auth needed)
    if (iataCode != null && iataCode.length >= 2) {
      final cdnUrl = 'https://content.airhex.com/content/logos/airlines_${iataCode}_512_512_s.png';
      debugPrint('✅ Using airhex.com CDN logo for $iataCode: $cdnUrl');
      return cdnUrl;
    }

    // 4. As a last resort, try ICAO on the same CDN.
    if (icaoCode != null && icaoCode.length >= 2) {
      final cdnUrl = 'https://content.airhex.com/content/logos/airlines_${icaoCode}_512_512_s.png';
      debugPrint('✅ Using airhex.com CDN logo for ICAO $icaoCode: $cdnUrl');
      return cdnUrl;
    }

    debugPrint('❌ No logo found for airline: ${airline['name']}');
    return null;
  }

  bool _isValidHttpUrl(String? value) {
    if (value == null) return false;
    return value.startsWith('http://') || value.startsWith('https://');
  }

  // Use airhex.com CDN with _512_512_s.png format (public, no auth needed)
  static const Map<String, String> _airlineLogoOverrides = {
    'EK': 'https://content.airhex.com/content/logos/airlines_EK_512_512_s.png',
    'QR': 'https://content.airhex.com/content/logos/airlines_QR_512_512_s.png',
    'AA': 'https://content.airhex.com/content/logos/airlines_AA_512_512_s.png',
    'UA': 'https://content.airhex.com/content/logos/airlines_UA_512_512_s.png',
    'DL': 'https://content.airhex.com/content/logos/airlines_DL_512_512_s.png',
    'LH': 'https://content.airhex.com/content/logos/airlines_LH_512_512_s.png',
    'BA': 'https://content.airhex.com/content/logos/airlines_BA_512_512_s.png',
    'TK': 'https://content.airhex.com/content/logos/airlines_TK_512_512_s.png',
    'EY': 'https://content.airhex.com/content/logos/airlines_EY_512_512_s.png',
    'AF': 'https://content.airhex.com/content/logos/airlines_AF_512_512_s.png',
    'SQ': 'https://content.airhex.com/content/logos/airlines_SQ_512_512_s.png',
    'CX': 'https://content.airhex.com/content/logos/airlines_CX_512_512_s.png',
    'NH': 'https://content.airhex.com/content/logos/airlines_NH_512_512_s.png',
    'QF': 'https://content.airhex.com/content/logos/airlines_QF_512_512_s.png',
    'AC': 'https://content.airhex.com/content/logos/airlines_AC_512_512_s.png',
    'WN': 'https://content.airhex.com/content/logos/airlines_WN_512_512_s.png',
    'B6': 'https://content.airhex.com/content/logos/airlines_B6_512_512_s.png',
    'VS': 'https://content.airhex.com/content/logos/airlines_VS_512_512_s.png',
    'AZ': 'https://content.airhex.com/content/logos/airlines_AZ_512_512_s.png',
    'IB': 'https://content.airhex.com/content/logos/airlines_IB_512_512_s.png',
    'AY': 'https://content.airhex.com/content/logos/airlines_AY_512_512_s.png',
    'SK': 'https://content.airhex.com/content/logos/airlines_SK_512_512_s.png',
    'KL': 'https://content.airhex.com/content/logos/airlines_KL_512_512_s.png',
    'OS': 'https://content.airhex.com/content/logos/airlines_OS_512_512_s.png',
    'SN': 'https://content.airhex.com/content/logos/airlines_SN_512_512_s.png',
    'TP': 'https://content.airhex.com/content/logos/airlines_TP_512_512_s.png',
    'ET': 'https://content.airhex.com/content/logos/airlines_ET_512_512_s.png',
    'SA': 'https://content.airhex.com/content/logos/airlines_SA_512_512_s.png',
    'MS': 'https://content.airhex.com/content/logos/airlines_MS_512_512_s.png',
    'KQ': 'https://content.airhex.com/content/logos/airlines_KQ_512_512_s.png',
  };

  /// Show feedback details modal
  void _showFeedbackDetails(
      BuildContext context, Map<String, dynamic> issue, String type) {
    final feedbackList =
        type == 'likes' ? (issue['likes'] ?? []) : (issue['dislikes'] ?? []);
    final isLikes = type == 'likes';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isLikes ? Icons.thumb_up : Icons.thumb_down,
                        color: isLikes
                            ? Colors.green.shade600
                            : Colors.red.shade600,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isLikes ? 'All Likes' : 'All Dislikes',
                        style: AppStyles.textStyle_20_600.copyWith(
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${issue['flight']} – ${issue['airline']}',
                    style: AppStyles.textStyle_14_400.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: Colors.grey.shade200),

            // Feedback List
            Expanded(
              child: feedbackList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isLikes
                                ? Icons.thumb_up_outlined
                                : Icons.thumb_down_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isLikes ? 'No likes yet' : 'No dislikes yet',
                            style: AppStyles.textStyle_16_400.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: feedbackList.length,
                      itemBuilder: (context, index) {
                        final feedback = feedbackList[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isLikes
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isLikes
                                  ? Colors.green.shade200
                                  : Colors.red.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isLikes
                                      ? Colors.green.shade100
                                      : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isLikes ? '😊' : '😞',
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      feedback['text'] ?? '',
                                      style:
                                          AppStyles.textStyle_16_600.copyWith(
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${feedback['count'] ?? 0} passengers mentioned this',
                                      style:
                                          AppStyles.textStyle_14_400.copyWith(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  bool _showTrustBanner = true;

  Widget _buildTrustIndicator() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.black.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_outlined,
            color: Colors.black,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _trustCopy,
              style: AppStyles.textStyle_13_500.copyWith(
                color: Colors.black.withOpacity(0.75),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              setState(() {
                _showTrustBanner = false;
              });
            },
            child: Icon(
              Icons.close,
              size: 18,
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget that tries multiple image URLs in sequence until one succeeds
class _MultiSourceImage extends StatefulWidget {
  final List<String> urls;
  final double size;
  final Widget fallback;
  final int currentIndex;

  const _MultiSourceImage({
    required this.urls,
    required this.size,
    required this.fallback,
    this.currentIndex = 0,
  });

  @override
  State<_MultiSourceImage> createState() => _MultiSourceImageState();
}

class _MultiSourceImageState extends State<_MultiSourceImage> {
  @override
  Widget build(BuildContext context) {
    if (widget.currentIndex >= widget.urls.length) {
      return widget.fallback;
    }

    final currentUrl = widget.urls[widget.currentIndex];
    debugPrint('🔄 Trying logo URL ${widget.currentIndex + 1}/${widget.urls.length}: $currentUrl');

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.center,
        child: Image.network(
          currentUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('❌ Image.network failed for $currentUrl: $error');
            // Try next URL in the list
            if (widget.currentIndex + 1 < widget.urls.length) {
              return _MultiSourceImage(
                urls: widget.urls,
                size: widget.size,
                fallback: widget.fallback,
                currentIndex: widget.currentIndex + 1,
              );
            }
            // All URLs failed, show fallback
            return widget.fallback;
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              debugPrint('✅ Image loaded successfully: $currentUrl');
              return child;
            }
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
              ),
            );
          },
        ),
      ),
    );
  }
}
