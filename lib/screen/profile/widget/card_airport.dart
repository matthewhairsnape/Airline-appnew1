import 'package:airline_app/provider/user_data_provider.dart';
import 'package:airline_app/screen/leaderboard/widgets/feedback_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:airline_app/controller/get_user_review_controller.dart';
import 'package:airline_app/screen/app_widgets/loading.dart';

class CLeaderboardScreen extends ConsumerStatefulWidget {
  const CLeaderboardScreen({super.key});

  @override
  ConsumerState<CLeaderboardScreen> createState() => _CLeaderboardScreenState();
}

class _CLeaderboardScreenState extends ConsumerState<CLeaderboardScreen> {
  bool isLoading = true;
  List<dynamic> userReviews = [];
  bool _mounted = true;

  final UserReviewService _userReviewService = UserReviewService();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  Future<void> _initializeData() async {
    final userData = ref.read(userDataProvider);
    if (userData != null) {
      final userId = userData['userData']['_id'].toString();
      try {
        final reviews = await _userReviewService.getUserReviews(userId);
        if (_mounted) {
          setState(() {
            userReviews = reviews;
            isLoading = false;
          });
        }
      } catch (e) {
        debugPrint('Error fetching user reviews: $e');
        if (_mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
        }
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider);

    if (userData == null) {
      return const Center(child: LoadingWidget());
    }

    return Column(
      children: [
        if (isLoading)
          const Center(child: LoadingWidget())
        else if (userReviews.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 2.0),
            child: Center(child: Text("No reviews found")),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: userReviews.map((singleReview) {
              final reviewer = singleReview['reviewer'];
              final airline = singleReview['airline'];

              if (reviewer != null && airline != null) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: FeedbackCard(
                        thumbnailHeight: 260,
                        singleFeedback: singleReview,
                      ),
                    ),
                    Divider(
                      indent: 24,
                      endIndent: 24,
                      thickness: 2,
                      color: Colors.grey.shade100,
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            }).toList(),
          ),
      ],
    );
  }
}
