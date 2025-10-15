import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../utils/app_styles.dart';
import '../../../models/flight_tracking_model.dart';
import '../../../services/phase_feedback_service.dart';
import '../../../services/supabase_service.dart';

class ComprehensiveFeedbackModal extends StatefulWidget {
  final FlightTrackingModel flight;
  final VoidCallback? onSubmitted;

  const ComprehensiveFeedbackModal({
    Key? key,
    required this.flight,
    this.onSubmitted,
  }) : super(key: key);

  @override
  State<ComprehensiveFeedbackModal> createState() => _ComprehensiveFeedbackModalState();
}

class _ComprehensiveFeedbackModalState extends State<ComprehensiveFeedbackModal>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _overallRating = 0;
  
  // Feedback selections for each category
  Map<String, Set<String>> _preFlightLikes = {};
  Map<String, Set<String>> _preFlightDislikes = {};
  Map<String, Set<String>> _inFlightLikes = {};
  Map<String, Set<String>> _inFlightDislikes = {};
  Map<String, Set<String>> _postFlightLikes = {};
  Map<String, Set<String>> _postFlightDislikes = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.black),
                ),
                Expanded(
                  child: Text(
                    'Share Your Experience',
                    style: AppStyles.textStyle_20_600.copyWith(color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(width: 48), // Balance the close button
              ],
            ),
          ),
          
          SizedBox(height: 24),
          
          // Overall Rating Section
          _buildOverallRatingSection(),
          
          SizedBox(height: 24),
          
          // Tab Bar
          Container(
            margin: EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[600],
              labelStyle: AppStyles.textStyle_14_600,
              tabs: [
                Tab(text: 'Pre-Flight'),
                Tab(text: 'In-Flight'),
                Tab(text: 'After Flight'),
              ],
            ),
          ),
          
          SizedBox(height: 16),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPreFlightFeedback(),
                _buildInFlightFeedback(),
                _buildPostFlightFeedback(),
              ],
            ),
          ),
          
          // Submit Button
          Padding(
            padding: EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed: _canSubmit() ? _submitFeedback : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Submit Feedback',
                style: AppStyles.textStyle_16_600.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallRatingSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Text(
            'Overall Experience',
            style: AppStyles.textStyle_18_600.copyWith(color: Colors.black),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _overallRating = index + 1;
                  });
                },
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    index < _overallRating ? Icons.star : Icons.star_border,
                    color: index < _overallRating ? Colors.amber : Colors.grey[400],
                    size: 32,
                  ),
                ),
              );
            }),
          ),
          SizedBox(height: 8),
          Text(
            _getRatingText(_overallRating),
            style: AppStyles.textStyle_14_500.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPreFlightFeedback() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategorySection(
            'What stands out?',
            _preFlightLikes,
            _getPreFlightLikes(),
            Icons.thumb_up,
            Colors.green,
          ),
          SizedBox(height: 24),
          _buildCategorySection(
            'What could be improved?',
            _preFlightDislikes,
            _getPreFlightDislikes(),
            Icons.thumb_down,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildInFlightFeedback() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategorySection(
            'What stands out?',
            _inFlightLikes,
            _getInFlightLikes(),
            Icons.thumb_up,
            Colors.green,
          ),
          SizedBox(height: 24),
          _buildCategorySection(
            'What could be improved?',
            _inFlightDislikes,
            _getInFlightDislikes(),
            Icons.thumb_down,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildPostFlightFeedback() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategorySection(
            'What stands out?',
            _postFlightLikes,
            _getPostFlightLikes(),
            Icons.thumb_up,
            Colors.green,
          ),
          SizedBox(height: 24),
          _buildCategorySection(
            'What could be improved?',
            _postFlightDislikes,
            _getPostFlightDislikes(),
            Icons.thumb_down,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    String title,
    Map<String, Set<String>> selections,
    List<String> options,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(width: 8),
            Text(
              title,
              style: AppStyles.textStyle_16_600.copyWith(color: Colors.black),
            ),
          ],
        ),
        SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selections.values.any((set) => set.contains(option));
            return GestureDetector(
              onTap: () {
                setState(() {
                  // Find which category this option belongs to
                  String category = '';
                  if (options == _getPreFlightLikes() || options == _getPreFlightDislikes()) {
                    category = _getPreFlightCategory(option);
                  } else if (options == _getInFlightLikes() || options == _getInFlightDislikes()) {
                    category = _getInFlightCategory(option);
                  } else {
                    category = _getPostFlightCategory(option);
                  }
                  
                  if (selections[category] == null) {
                    selections[category] = <String>{};
                  }
                  
                  if (isSelected) {
                    selections[category]!.remove(option);
                  } else {
                    selections[category]!.add(option);
                  }
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? color.withAlpha(25) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? color : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  option,
                  style: AppStyles.textStyle_14_500.copyWith(
                    color: isSelected ? color : Colors.black,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  bool _canSubmit() {
    return _overallRating > 0;
  }

  Future<void> _submitFeedback() async {
    try {
      // Get current user
      final session = SupabaseService.client.auth.currentSession;
      if (session?.user.id == null) {
        _showErrorDialog('User not authenticated. Please log in again.');
        return;
      }

      final userId = session!.user.id;
      final flightId = widget.flight.flightId;
      final journeyId = widget.flight.pnr; // Using PNR as journey ID
      final seat = widget.flight.seatNumber ?? 'Unknown';

      debugPrint('📝 Submitting feedback for user: $userId, flight: $flightId, journey: $journeyId');

      // Submit feedback for each phase to the correct table
      final phases = [
        {
          'phase': 'Pre-Flight',
          'likes': _preFlightLikes,
          'dislikes': _preFlightDislikes,
        },
        {
          'phase': 'In-Flight',
          'likes': _inFlightLikes,
          'dislikes': _inFlightDislikes,
        },
        {
          'phase': 'Post-Flight',
          'likes': _postFlightLikes,
          'dislikes': _postFlightDislikes,
        },
      ];

      bool allSuccess = true;
      for (final phaseData in phases) {
        final phase = phaseData['phase'] as String;
        final likes = phaseData['likes'] as Map<String, Set<String>>;
        final dislikes = phaseData['dislikes'] as Map<String, Set<String>>;

        debugPrint('🔄 Processing phase: $phase');
        debugPrint('   Likes: $likes');
        debugPrint('   Dislikes: $dislikes');

        final success = await PhaseFeedbackService.submitPhaseFeedback(
          userId: userId,
          journeyId: journeyId,
          flightId: flightId,
          seat: seat,
          phase: phase,
          overallRating: _overallRating,
          likes: likes,
          dislikes: dislikes,
        );

        if (!success) {
          allSuccess = false;
          debugPrint('❌ Failed to submit feedback for phase: $phase');
        } else {
          debugPrint('✅ Successfully submitted feedback for phase: $phase');
        }
      }

      if (allSuccess) {
        // Close the feedback modal
        Navigator.pop(context);
        
        // Show success confirmation
        _showSuccessDialog();
        
        // Call the callback
        widget.onSubmitted?.call();
      } else {
        _showErrorDialog('Some feedback failed to submit. Please try again.');
      }
    } catch (e) {
      debugPrint('❌ Error submitting feedback: $e');
      _showErrorDialog('An error occurred while submitting feedback.');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 50,
                  ),
                ),
                
                SizedBox(height: 24),
                
                // Title
                Text(
                  'Feedback Submitted!',
                  style: AppStyles.textStyle_24_600.copyWith(color: Colors.black),
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: 12),
                
                // Description
                Text(
                  'Thank you! Your feedback has been recorded and sent to the airline.',
                  style: AppStyles.textStyle_16_400.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: 32),
                
                // Done Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onSubmitted?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Done',
                      style: AppStyles.textStyle_16_600.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Error Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error,
                    color: Colors.red,
                    size: 50,
                  ),
                ),
                
                SizedBox(height: 24),
                
                // Title
                Text(
                  'Error',
                  style: AppStyles.textStyle_24_600.copyWith(color: Colors.black),
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: 12),
                
                // Description
                Text(
                  message,
                  style: AppStyles.textStyle_16_400.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: 32),
                
                // OK Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'OK',
                      style: AppStyles.textStyle_16_600.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Very Good';
      case 5: return 'Excellent';
      default: return 'Rate your experience';
    }
  }

  // Pre-Flight Categories
  List<String> _getPreFlightLikes() {
    return [
      'Check-in process',
      'Security line wait time',
      'Boarding process',
      'Airport Facilities and Shops',
      'Smooth Airport experience',
      'Airline Lounge',
      'Something else',
    ];
  }

  List<String> _getPreFlightDislikes() {
    return [
      'Check-in process',
      'Security line wait time',
      'Boarding process',
      'Airport Facilities and Shops',
      'Smooth Airport experience',
      'Airline Lounge',
      'Something else',
    ];
  }

  String _getPreFlightCategory(String option) {
    // For simplicity, we'll use the option as the category key
    return option;
  }

  // In-Flight Categories
  List<String> _getInFlightLikes() {
    return [
      'Seat comfort',
      'Cabin cleanliness',
      'Cabin crew',
      'In-flight entertainment',
      'Wi-Fi',
      'Food and beverage',
      'Something else',
    ];
  }

  List<String> _getInFlightDislikes() {
    return [
      'Seat comfort',
      'Cabin cleanliness',
      'Cabin crew',
      'In-flight entertainment',
      'Wi-Fi',
      'Food and beverage',
      'Something else',
    ];
  }

  String _getInFlightCategory(String option) {
    return option;
  }

  // Post-Flight Categories
  List<String> _getPostFlightLikes() {
    return [
      'Friendly and helpful service',
      'Smooth and troublefree flight',
      'Onboard Comfort',
      'Food and Beverage',
      'Wi-Fi and IFE',
      'Communication from airline',
      'Baggage delivery or ease of connection',
      'Something else',
    ];
  }

  List<String> _getPostFlightDislikes() {
    return [
      'Wi-Fi',
      'Friendly and helpful service',
      'Stressful and uneasy flight',
      'Onboard Comfort',
      'Food and Beverage',
      'Wi-Fi and IFE',
      'Communication from airline',
      'Baggage delivery or ease of connection',
      'Something else',
    ];
  }

  String _getPostFlightCategory(String option) {
    return option;
  }
}
