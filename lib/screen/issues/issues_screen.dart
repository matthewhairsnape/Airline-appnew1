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
  @override
  void initState() {
    super.initState();
    // Load issues data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(leaderboardProvider.notifier).loadLeaderboard();
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

    return KeyboardDismissWidget(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: leaderboardState.issues.length,
        itemBuilder: (context, index) {
          final issue = leaderboardState.issues[index];
          final rank = index + 1;

          return Container(
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
            child: Row(
              children: [
                // Rank Badge
                Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: AppStyles.textStyle_16_600.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),

                // Airline Logo
                _buildAirlineLogo(issue['logo']),

                const SizedBox(width: 16),

                // Flight Info and Feedback
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Flight Number, Stage Badge, and Timestamp
                      Row(
                        children: [
                          Text(
                            issue['flight'] ?? 'Unknown Flight',
                            style: AppStyles.textStyle_16_600.copyWith(
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: issue['phaseColor'],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              issue['phase'] ?? 'Unknown',
                              style: AppStyles.textStyle_12_600.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatTimestamp(issue['timestamp']),
                            style: AppStyles.textStyle_12_400.copyWith(
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Airline Name and Seat Number
                      Row(
                        children: [
                          Text(
                            issue['airline'] ?? 'Unknown Airline',
                            style: AppStyles.textStyle_14_400.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (issue['seat'] != null &&
                              issue['seat'] != 'N/A') ...[
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

                      const SizedBox(height: 8),

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
                        onTap: () =>
                            _showFeedbackDetails(context, issue, 'dislikes'),
                        child: _buildCompactDislikes(issue['dislikes'] ?? []),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
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
