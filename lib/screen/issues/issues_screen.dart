import 'package:airline_app/screen/app_widgets/bottom_nav_bar.dart';
import 'package:airline_app/screen/app_widgets/keyboard_dismiss_widget.dart';
import 'package:airline_app/screen/app_widgets/loading_widget.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:airline_app/provider/leaderboard_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IssuesScreen extends ConsumerStatefulWidget {
  const IssuesScreen({super.key});

  @override
  ConsumerState<IssuesScreen> createState() => _IssuesScreenState();
}

class _IssuesScreenState extends ConsumerState<IssuesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    // Load issues data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(leaderboardProvider.notifier).loadLeaderboard();
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _onWillPop() {
    Navigator.pushReplacementNamed(context, AppRoutes.startreviews);
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
            'Realtime Feedback',
            style: AppStyles.textStyle_20_600.copyWith(
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        bottomNavigationBar: const BottomNavBar(
          currentIndex: 3,
        ),
        body: _buildRealtimeFeed(),
      ),
    );
  }

  Widget _buildRealtimeFeed() {
    final leaderboardState = ref.watch(leaderboardProvider);

    if (leaderboardState.isLoading) {
      return const Center(
        child: LoadingWidget(),
      );
    }

    if (leaderboardState.issues.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.feed_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No Feedback Yet',
              style: AppStyles.textStyle_18_600.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Passenger feedback will appear here',
              style: AppStyles.textStyle_14_400.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return KeyboardDismissWidget(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: leaderboardState.issues.length,
        itemBuilder: (context, index) {
          final feedback = leaderboardState.issues[index];
          return FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: _fadeController,
                curve: Interval(
                  (index * 0.1).clamp(0.0, 0.8),
                  ((index * 0.1) + 0.2).clamp(0.0, 1.0),
                  curve: Curves.easeIn,
                ),
              ),
            ),
            child: _buildFeedbackCard(feedback),
          );
        },
      ),
    );
  }

  Widget _buildFeedbackCard(Map<String, dynamic> feedback) {
    return GestureDetector(
      onTap: () => _showFeedbackDetails(context, feedback),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _buildFeedbackCardContent(feedback),
        ),
      ),
    );
  }

  List<Widget> _buildFeedbackCardContent(Map<String, dynamic> feedback) {
    final timestamp = feedback['timestamp'] as DateTime? ?? DateTime.now();
    final flight = feedback['flight'] as String? ?? '';
    final airline = feedback['airline'] as String? ?? 'Unknown Airline';
    final logo = feedback['logo'] as String?;
    final seat = feedback['seat'] as String?;
    final phase = feedback['phase'] as String? ?? 'Unknown';
    final phaseColor = feedback['phaseColor'] as Color? ?? Colors.grey;
    final feedbackType = feedback['feedback_type'] as String?;
    
    // Safely convert likes from List<dynamic> to List<Map<String, dynamic>>
    final likesList = feedback['likes'];
    final likes = (likesList is List)
        ? likesList.map((item) {
            if (item is Map<String, dynamic>) {
              return item;
            } else if (item is Map) {
              return Map<String, dynamic>.from(item);
            } else {
              return <String, dynamic>{};
            }
          }).toList()
        : <Map<String, dynamic>>[];
    
    // Safely convert dislikes from List<dynamic> to List<Map<String, dynamic>>
    final dislikesList = feedback['dislikes'];
    final dislikes = (dislikesList is List)
        ? dislikesList.map((item) {
            if (item is Map<String, dynamic>) {
              return item;
            } else if (item is Map) {
              return Map<String, dynamic>.from(item);
            } else {
              return <String, dynamic>{};
            }
          }).toList()
        : <Map<String, dynamic>>[];
    
    final comments = feedback['comments'] as String? ?? '';

    return [
      // First Row: Timestamp
      Row(
        children: [
          Icon(
            Icons.access_time,
            size: 14,
            color: Colors.grey.shade500,
          ),
          const SizedBox(width: 4),
          Text(
            _formatTimestamp(timestamp),
            style: AppStyles.textStyle_12_400.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),

      // Second Row: Airline Logo + Flight Info with Phase
      Row(
        children: [
          // Airline Logo
          _buildAirlineLogo(logo, size: 40),
          const SizedBox(width: 12),
          // Flight Info: Airline + flight number + phase
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  flight.isNotEmpty 
                      ? '$airline $flight ($phase)'
                      : '$airline ($phase)',
                  style: AppStyles.textStyle_14_600.copyWith(
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),

      // Third Row: Seat Info (if available)
      if (seat != null && seat != 'N/A' && seat.isNotEmpty)
        Row(
          children: [
            Icon(
              Icons.event_seat,
              size: 14,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              'Seat $seat',
              style: AppStyles.textStyle_12_600.copyWith(
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      if (seat != null && seat != 'N/A' && seat.isNotEmpty)
        const SizedBox(height: 12),

      // Fourth Row: Specific Likes and Dislikes
      ...[ 
        // Show likes (top 2 most common)
        if (likes.isNotEmpty) ...[
          for (var i = 0; i < (likes.length > 2 ? 2 : likes.length); i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '👍',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    likes[i]['text'] as String? ?? '',
                    style: AppStyles.textStyle_14_600.copyWith(
                      color: Colors.green.shade700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if ((likes[i]['count'] as int? ?? 0) > 1) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade300, width: 1),
                    ),
                    child: Text(
                      '${likes[i]['count']} ${(likes[i]['count'] as int) == 1 ? 'passenger' : 'passengers'}',
                      style: AppStyles.textStyle_10_500.copyWith(
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (i < (likes.length > 2 ? 1 : likes.length - 1))
              const SizedBox(height: 6),
          ],
          if (likes.length > 2)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${likes.length - 2} more positive',
                style: AppStyles.textStyle_12_400.copyWith(
                  color: Colors.green.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (dislikes.isNotEmpty)
            const SizedBox(height: 12),
        ],
        
        // Show dislikes (top 2 most common)
        if (dislikes.isNotEmpty) ...[
          for (var i = 0; i < (dislikes.length > 2 ? 2 : dislikes.length); i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '👎',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dislikes[i]['text'] as String? ?? '',
                    style: AppStyles.textStyle_14_600.copyWith(
                      color: Colors.red.shade700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if ((dislikes[i]['count'] as int? ?? 0) > 1) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade300, width: 1),
                    ),
                    child: Text(
                      '${dislikes[i]['count']} ${(dislikes[i]['count'] as int) == 1 ? 'passenger' : 'passengers'}',
                      style: AppStyles.textStyle_10_500.copyWith(
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (i < (dislikes.length > 2 ? 1 : dislikes.length - 1))
              const SizedBox(height: 6),
          ],
          if (dislikes.length > 2)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${dislikes.length - 2} more issues',
                style: AppStyles.textStyle_12_400.copyWith(
                  color: Colors.red.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
        
        // Empty state
        if (likes.isEmpty && dislikes.isEmpty && comments.isEmpty)
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.grey.shade400,
              ),
              const SizedBox(width: 8),
              Text(
                'No specific feedback provided',
                style: AppStyles.textStyle_14_400.copyWith(
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        
        const SizedBox(height: 12),
      ],

      // Fifth Row: Phase Badge
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: phaseColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getPhaseIcon(phase),
              size: 12,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              phase,
              style: AppStyles.textStyle_12_600.copyWith(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  String _formatLocation(String phase, String? seat) {
    if (seat != null && seat != 'N/A') {
      return 'Seat $seat';
    }
    
    switch (phase.toLowerCase()) {
      case 'boarding':
        return 'Gate';
      case 'in-flight':
      case 'in-flight':
        return 'In-flight';
      case 'arrival':
        return 'Baggage';
      default:
        return phase;
    }
  }

  IconData _getPhaseIcon(String phase) {
    switch (phase.toLowerCase()) {
      case 'pre-flight':
      case 'boarding':
        return Icons.flight_takeoff;
      case 'in-flight':
        return Icons.flight;
      case 'after flight':
      case 'arrival':
        return Icons.flight_land;
      default:
        return Icons.flight;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    // Convert to local time if timestamp is in UTC
    final localTime = timestamp.isUtc ? timestamp.toLocal() : timestamp;
    final now = DateTime.now();
    final difference = now.difference(localTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} mins ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hrs ago';
    } else {
      // Show actual time for older timestamps (7:01am format)
      final hour = localTime.hour;
      final minute = localTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'pm' : 'am';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute$period';
    }
  }

  /// Build airline logo widget (network or fallback)
  Widget _buildAirlineLogo(String? logoUrl, {double size = 48}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: logoUrl != null && logoUrl.startsWith('http')
            ? Image.network(
                logoUrl,
                width: size,
                height: size,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
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
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.flight,
                    color: Colors.grey.shade600,
                    size: size * 0.5,
                  );
                },
              )
            : Icon(
                Icons.flight,
                color: Colors.grey.shade600,
                size: size * 0.5,
              ),
      ),
    );
  }

  /// Show feedback details modal when card is tapped
  void _showFeedbackDetails(
      BuildContext context, Map<String, dynamic> feedback) {
    final flight = feedback['flight'] as String? ?? 'Unknown Flight';
    final airline = feedback['airline'] as String? ?? 'Unknown Airline';
    final seat = feedback['seat'] as String?;
    final timestamp = feedback['timestamp'] as DateTime? ?? DateTime.now();
    
    // Safely convert likes from List<dynamic> to List<Map<String, dynamic>>
    final likesList = feedback['likes'];
    final likes = (likesList is List)
        ? likesList.map((item) {
            if (item is Map<String, dynamic>) {
              return item;
            } else if (item is Map) {
              return Map<String, dynamic>.from(item);
            } else {
              return <String, dynamic>{};
            }
          }).toList()
        : <Map<String, dynamic>>[];
    
    // Safely convert dislikes from List<dynamic> to List<Map<String, dynamic>>
    final dislikesList = feedback['dislikes'];
    final dislikes = (dislikesList is List)
        ? dislikesList.map((item) {
            if (item is Map<String, dynamic>) {
              return item;
            } else if (item is Map) {
              return Map<String, dynamic>.from(item);
            } else {
              return <String, dynamic>{};
            }
          }).toList()
        : <Map<String, dynamic>>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
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
                        Icons.feedback,
                        color: Colors.black,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$airline ($flight)',
                              style: AppStyles.textStyle_18_600.copyWith(
                                color: Colors.black,
                              ),
                            ),
                            if (seat != null && seat != 'N/A')
                              Text(
                                'Seat $seat',
                                style: AppStyles.textStyle_14_400.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatTimestamp(timestamp),
                    style: AppStyles.textStyle_12_400.copyWith(
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: Colors.grey.shade200),

            // Likes Section
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Likes
                    if (likes.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.thumb_up,
                            color: Colors.green.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'What they liked',
                            style: AppStyles.textStyle_16_600.copyWith(
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...likes.map((like) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.shade200,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '😊',
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    like['text'] as String? ?? '',
                                    style: AppStyles.textStyle_14_600.copyWith(
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 24),
                    ],

                    // Dislikes
                    if (dislikes.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.thumb_down,
                            color: Colors.red.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'What they disliked',
                            style: AppStyles.textStyle_16_600.copyWith(
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...dislikes.map((dislike) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.red.shade200,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '😞',
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    dislike['text'] as String? ?? '',
                                    style: AppStyles.textStyle_14_600.copyWith(
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],

                    // Empty state
                    if (likes.isEmpty && dislikes.isEmpty)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.feedback_outlined,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No detailed feedback available',
                              style: AppStyles.textStyle_14_400.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
