import 'package:airline_app/screen/app_widgets/bottom_nav_bar.dart';
import 'package:airline_app/screen/app_widgets/keyboard_dismiss_widget.dart';
import 'package:airline_app/screen/app_widgets/loading_widget.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:airline_app/provider/leaderboard_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IssuesScreen extends ConsumerStatefulWidget {
  const IssuesScreen({super.key});

  @override
  ConsumerState<IssuesScreen> createState() => _IssuesScreenState();
}

class _IssuesScreenState extends ConsumerState<IssuesScreen> {
  // Track expanded/collapsed state for each flight group
  final Set<String> _expandedFlights = <String>{};

  @override
  void initState() {
    super.initState();
    // Load issues data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(leaderboardProvider.notifier).loadLeaderboard();
    });
  }

  /// Toggle expand/collapse state for a flight
  void _toggleFlightExpansion(String flightKey) {
    setState(() {
      if (_expandedFlights.contains(flightKey)) {
        _expandedFlights.remove(flightKey);
      } else {
        _expandedFlights.add(flightKey);
      }
    });
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
          currentIndex: 3, // Realtime will be the 4th tab (index 3)
        ),
        body: _buildIssuesContent(),
      ),
    );
  }

  Widget _buildIssuesContent() {
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
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No Issues Reported',
              style: AppStyles.textStyle_18_600.copyWith(
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All flights are running smoothly',
              style: AppStyles.textStyle_14_400.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    // Group feedback by flight
    final groupedByFlight = _groupIssuesByFlight(leaderboardState.issues);

    return KeyboardDismissWidget(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: groupedByFlight.length,
        itemBuilder: (context, index) {
          final flightGroup = groupedByFlight[index];
          final flightKey = flightGroup['flightKey'] as String;
          final flightInfo = flightGroup['flightInfo'] as Map<String, dynamic>;
          final feedbackList = flightGroup['feedback'] as List<Map<String, dynamic>>;

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
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
              children: [
                // Flight Header with Logo and Name (Tappable to expand/collapse)
                InkWell(
                  onTap: () => _toggleFlightExpansion(flightKey),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Airline Logo
                        _buildAirlineLogo(flightInfo['logo'], size: 56),
                        const SizedBox(width: 16),
                        // Flight Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                flightInfo['flight'] ?? 'Unknown Flight',
                                style: AppStyles.textStyle_18_600.copyWith(
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                flightInfo['airline'] ?? 'Unknown Airline',
                                style: AppStyles.textStyle_14_400.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Feedback Count Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Text(
                            '${feedbackList.length} ${feedbackList.length == 1 ? 'feedback' : 'feedbacks'}',
                            style: AppStyles.textStyle_12_600.copyWith(
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Expand/Collapse Icon
                        AnimatedRotation(
                          duration: const Duration(milliseconds: 200),
                          turns: _expandedFlights.contains(flightKey) ? 0.5 : 0,
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.grey.shade600,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Feedback Items List (Expandable)
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: _expandedFlights.contains(flightKey)
                      ? Column(
                          children: feedbackList.asMap().entries.map((entry) {
                            final feedbackIndex = entry.key;
                            final issue = entry.value;
                            final isLast = feedbackIndex == feedbackList.length - 1;

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: isLast
                                    ? null
                                    : Border(
                                        bottom: BorderSide(
                                          color: Colors.grey.shade200,
                                          width: 1,
                                        ),
                                      ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Phase Badge and Timestamp
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: issue['phaseColor'] ?? Colors.grey,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          issue['phase'] ?? 'Unknown',
                                          style: AppStyles.textStyle_12_600.copyWith(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatTimestamp(issue['timestamp']),
                                        style: AppStyles.textStyle_12_400.copyWith(
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                      if (issue['seat'] != null &&
                                          issue['seat'] != 'N/A') ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          '• Seat ${issue['seat']}',
                                          style: AppStyles.textStyle_12_400.copyWith(
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  // Score/Rating Display
                                  if (issue['overall_rating'] != null ||
                                      issue['score_value'] != null)
                                    _buildScoreDisplay(issue),

                                  const SizedBox(height: 12),

                                  // Likes Bubble (tappable)
                                  GestureDetector(
                                    onTap: () =>
                                        _showFeedbackDetails(context, issue, 'likes'),
                                    child: _buildCompactLikes(issue['likes'] ?? []),
                                  ),

                                  const SizedBox(height: 8),

                                  // Dislikes Bubble (tappable)
                                  GestureDetector(
                                    onTap: () => _showFeedbackDetails(
                                        context, issue, 'dislikes'),
                                    child: _buildCompactDislikes(issue['dislikes'] ?? []),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Group issues by flight
  List<Map<String, dynamic>> _groupIssuesByFlight(
      List<Map<String, dynamic>> issues) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final issue in issues) {
      // Create a unique key for each flight
      // Use flight number + airline name as key
      final flightKey = '${issue['flight'] ?? 'Unknown'}_${issue['airline'] ?? 'Unknown'}';

      if (!grouped.containsKey(flightKey)) {
        grouped[flightKey] = [];
      }
      grouped[flightKey]!.add(issue);
    }

    // Convert to list format with flight info
    return grouped.entries.map((entry) {
      final flightKey = entry.key;
      final feedbackList = entry.value;

      // Get flight info from the first feedback item
      final firstFeedback = feedbackList.first;
      final flightInfo = {
        'flight': firstFeedback['flight'] ?? 'Unknown Flight',
        'airline': firstFeedback['airline'] ?? 'Unknown Airline',
        'logo': firstFeedback['logo'],
      };

      // Sort feedback by timestamp (most recent first)
      feedbackList.sort((a, b) {
        final timeA = a['timestamp'] as DateTime?;
        final timeB = b['timestamp'] as DateTime?;
        if (timeA == null && timeB == null) return 0;
        if (timeA == null) return 1;
        if (timeB == null) return -1;
        return timeB.compareTo(timeA);
      });

      return {
        'flightKey': flightKey,
        'flightInfo': flightInfo,
        'feedback': feedbackList,
      };
    }).toList()
      ..sort((a, b) {
        // Sort flights by most recent feedback timestamp
        final aFeedback = a['feedback'] as List<Map<String, dynamic>>;
        final bFeedback = b['feedback'] as List<Map<String, dynamic>>;
        if (aFeedback.isEmpty && bFeedback.isEmpty) return 0;
        if (aFeedback.isEmpty) return 1;
        if (bFeedback.isEmpty) return -1;

        final aTime = aFeedback.first['timestamp'] as DateTime?;
        final bTime = bFeedback.first['timestamp'] as DateTime?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
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

  /// Build score/rating display widget
  Widget _buildScoreDisplay(Map<String, dynamic> issue) {
    final score = issue['overall_rating'] ?? issue['score_value'];
    if (score == null) return const SizedBox.shrink();

    // Convert score to display format (handle both 0-5 and 0-1 scales)
    double displayScore;
    double maxScore = 5.0;
    
    if (score is num) {
      displayScore = score.toDouble();
      // If score is less than 1, it might be normalized (0-1 scale)
      if (displayScore <= 1.0) {
        displayScore = displayScore * 5.0;
      }
    } else {
      return const SizedBox.shrink();
    }

    // Determine score color
    Color scoreColor;
    String scoreLabel;
    if (displayScore >= 4.5) {
      scoreColor = Colors.green;
      scoreLabel = 'Excellent';
    } else if (displayScore >= 4.0) {
      scoreColor = Colors.green.shade600;
      scoreLabel = 'Great';
    } else if (displayScore >= 3.5) {
      scoreColor = Colors.blue;
      scoreLabel = 'Good';
    } else if (displayScore >= 3.0) {
      scoreColor = Colors.orange;
      scoreLabel = 'Average';
    } else if (displayScore >= 2.0) {
      scoreColor = Colors.orange.shade700;
      scoreLabel = 'Below Average';
    } else {
      scoreColor = Colors.red;
      scoreLabel = 'Poor';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scoreColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scoreColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            color: scoreColor,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            displayScore.toStringAsFixed(1),
            style: AppStyles.textStyle_14_600.copyWith(
              color: scoreColor,
            ),
          ),
          Text(
            '/${maxScore.toStringAsFixed(0)}',
            style: AppStyles.textStyle_12_400.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            scoreLabel,
            style: AppStyles.textStyle_12_600.copyWith(
              color: scoreColor,
            ),
          ),
        ],
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

  /// Format timestamp for display
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Just now';

    DateTime dateTime;
    if (timestamp is DateTime) {
      dateTime = timestamp;
    } else if (timestamp is String) {
      try {
        dateTime = DateTime.parse(timestamp);
      } catch (e) {
        return 'Just now';
      }
    } else {
      return 'Just now';
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

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
                  Row(
                    children: [
                      Text(
                        '${issue['flight']} – ${issue['airline']}',
                        style: AppStyles.textStyle_14_400.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (issue['seat'] != null && issue['seat'] != 'N/A') ...[
                        Text(
                          ' • Seat ${issue['seat']}',
                          style: AppStyles.textStyle_14_400.copyWith(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Updated ${_formatTimestamp(issue['timestamp'])}',
                    style: AppStyles.textStyle_12_400.copyWith(
                      color: Colors.grey.shade500,
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
}
