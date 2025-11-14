import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../../../utils/app_styles.dart';
import '../../../models/flight_tracking_model.dart';
import '../../../services/phase_feedback_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/media_service.dart';

class ComprehensiveFeedbackModal extends StatefulWidget {
  final FlightTrackingModel flight;
  final VoidCallback? onSubmitted;

  const ComprehensiveFeedbackModal({
    Key? key,
    required this.flight,
    this.onSubmitted,
  }) : super(key: key);

  @override
  State<ComprehensiveFeedbackModal> createState() =>
      _ComprehensiveFeedbackModalState();
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

  // Media upload and comments
  bool _showLikesCommentBox = false;
  bool _showDislikesCommentBox = false;
  TextEditingController _likesCommentController = TextEditingController();
  TextEditingController _dislikesCommentController = TextEditingController();
  List<String> _likesMediaFiles = [];
  List<String> _dislikesMediaFiles = [];
  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Tabs are now hidden - using unified form, but keeping TabController for compatibility
    _tabController = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _likesCommentController.dispose();
    _dislikesCommentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;
    final isTablet = screenWidth > 600;
    
    // Responsive height: 90% for normal, 95% for small screens, 85% for tablets
    final modalHeight = isSmallScreen 
        ? screenHeight * 0.95 
        : isTablet 
            ? screenHeight * 0.85 
            : screenHeight * 0.9;
    
    // Responsive padding
    final horizontalPadding = isTablet ? 32.0 : 24.0;
    final verticalPadding = isSmallScreen ? 16.0 : 24.0;
    
    return Container(
      height: modalHeight,
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
            margin: EdgeInsets.only(
              top: isSmallScreen ? 8 : 12, 
              bottom: isSmallScreen ? 16 : 20,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header - Responsive
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close, 
                    color: Colors.black,
                    size: isSmallScreen ? 20 : 24,
                  ),
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                ),
                Expanded(
                  child: Text(
                    'Share Your Experience',
                    style: AppStyles.textStyle_20_600.copyWith(
                      color: Colors.black,
                      fontSize: isSmallScreen ? 18 : 20,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 40 : 48), // Balance the close button
              ],
            ),
          ),

          SizedBox(height: isSmallScreen ? 16 : 24),

          // Pixar Image Header - Responsive
          _buildPixarImageHeader(isSmallScreen, horizontalPadding),

          SizedBox(height: isSmallScreen ? 16 : 24),

          // Overall Rating Section - Responsive
          _buildOverallRatingSection(isSmallScreen, horizontalPadding),

          SizedBox(height: isSmallScreen ? 16 : 24),

          // Unified Feedback Form - Responsive
          Expanded(
            child: _buildUnifiedFeedback(horizontalPadding),
          ),

          // Submit Button - Responsive
          Container(
            padding: EdgeInsets.all(horizontalPadding),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSubmit() ? _submitFeedback : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(
                    vertical: isSmallScreen ? 14 : 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Submit Feedback',
                  style: AppStyles.textStyle_16_600.copyWith(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 14 : 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPixarImageHeader(bool isSmallScreen, double horizontalPadding) {
    final imageHeight = isSmallScreen ? 140.0 : 180.0;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
      height: imageHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/images/End of Flight.png',
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      ),
    );
  }

  Widget _buildOverallRatingSection(bool isSmallScreen, double horizontalPadding) {
    final starSize = isSmallScreen ? 28.0 : 32.0;
    final padding = isSmallScreen ? 16.0 : 20.0;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Text(
            'Overall Experience',
            style: AppStyles.textStyle_18_600.copyWith(
              color: Colors.black,
              fontSize: isSmallScreen ? 16 : 18,
            ),
          ),
          SizedBox(height: isSmallScreen ? 10 : 12),
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
                  margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 3 : 4),
                  child: Icon(
                    index < _overallRating ? Icons.star : Icons.star_border,
                    color: index < _overallRating
                        ? Colors.amber
                        : Colors.grey[400],
                    size: starSize,
                  ),
                ),
              );
            }),
          ),
          SizedBox(height: isSmallScreen ? 6 : 8),
          Text(
            _getRatingText(_overallRating),
            style: AppStyles.textStyle_14_500.copyWith(
              color: Colors.grey[600],
              fontSize: isSmallScreen ? 12 : 14,
            ),
          ),
        ],
      ),
    );
  }

  // Unified feedback form - combines all categories into one view
  Widget _buildUnifiedFeedback(double horizontalPadding) {
    // Use unified options for all phases (backend still processes by phase)
    final unifiedLikes = <String, Set<String>>{};
    final unifiedDislikes = <String, Set<String>>{};
    
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // What stands out? section
          _buildCategorySection(
            'What stands out?',
            unifiedLikes,
            _getUnifiedLikes(),
            Icons.thumb_up,
            Colors.green,
            true,
            horizontalPadding,
          ),
          SizedBox(height: horizontalPadding),
          
          // What can be better? section
          _buildCategorySection(
            'What can be better?',
            unifiedDislikes,
            _getUnifiedDislikes(),
            Icons.thumb_down,
            Colors.red,
            false,
            horizontalPadding,
          ),
          SizedBox(height: horizontalPadding),
        ],
      ),
    );
  }
  
  // Store selections in all phase maps for backend compatibility
  void _updateAllPhaseSelections(String category, String option, bool isLike) {
    setState(() {
      if (isLike) {
        // Check if already selected in likes
        final isAlreadySelected = _preFlightLikes.values.any((set) => set.contains(option)) ||
                                  _inFlightLikes.values.any((set) => set.contains(option)) ||
                                  _postFlightLikes.values.any((set) => set.contains(option));
        
        // Remove from dislikes if it was there
        _preFlightDislikes.values.forEach((set) => set.remove(option));
        _inFlightDislikes.values.forEach((set) => set.remove(option));
        _postFlightDislikes.values.forEach((set) => set.remove(option));
        
        if (isAlreadySelected) {
          // Toggle off - remove from likes
          _preFlightLikes.values.forEach((set) => set.remove(option));
          _inFlightLikes.values.forEach((set) => set.remove(option));
          _postFlightLikes.values.forEach((set) => set.remove(option));
        } else {
          // Toggle on - add to all phase likes maps
          if (_preFlightLikes[category] == null) _preFlightLikes[category] = <String>{};
          if (_inFlightLikes[category] == null) _inFlightLikes[category] = <String>{};
          if (_postFlightLikes[category] == null) _postFlightLikes[category] = <String>{};
          
          _preFlightLikes[category]!.add(option);
          _inFlightLikes[category]!.add(option);
          _postFlightLikes[category]!.add(option);
        }
      } else {
        // Check if already selected in dislikes
        final isAlreadySelected = _preFlightDislikes.values.any((set) => set.contains(option)) ||
                                  _inFlightDislikes.values.any((set) => set.contains(option)) ||
                                  _postFlightDislikes.values.any((set) => set.contains(option));
        
        // Remove from likes if it was there
        _preFlightLikes.values.forEach((set) => set.remove(option));
        _inFlightLikes.values.forEach((set) => set.remove(option));
        _postFlightLikes.values.forEach((set) => set.remove(option));
        
        if (isAlreadySelected) {
          // Toggle off - remove from dislikes
          _preFlightDislikes.values.forEach((set) => set.remove(option));
          _inFlightDislikes.values.forEach((set) => set.remove(option));
          _postFlightDislikes.values.forEach((set) => set.remove(option));
        } else {
          // Toggle on - add to all phase dislikes maps
          if (_preFlightDislikes[category] == null) _preFlightDislikes[category] = <String>{};
          if (_inFlightDislikes[category] == null) _inFlightDislikes[category] = <String>{};
          if (_postFlightDislikes[category] == null) _postFlightDislikes[category] = <String>{};
          
          _preFlightDislikes[category]!.add(option);
          _inFlightDislikes[category]!.add(option);
          _postFlightDislikes[category]!.add(option);
        }
      }
    });
  }

  // Keep these methods for backend compatibility (not used in UI anymore)
  Widget _buildPreFlightFeedback() {
    return _buildUnifiedFeedback(24.0); // Default padding
  }

  Widget _buildInFlightFeedback() {
    return _buildUnifiedFeedback(24.0); // Default padding
  }

  Widget _buildPostFlightFeedback() {
    return _buildUnifiedFeedback(24.0); // Default padding
  }

  Widget _buildCategorySection(
    String title,
    Map<String, Set<String>> selections,
    List<String> options,
    IconData icon,
    Color color,
    bool isLikes,
    double horizontalPadding,
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
            // Check if selected in the appropriate section (likes or dislikes)
            final isSelected = isLikes
                ? (_preFlightLikes.values.any((set) => set.contains(option)) ||
                   _inFlightLikes.values.any((set) => set.contains(option)) ||
                   _postFlightLikes.values.any((set) => set.contains(option)))
                : (_preFlightDislikes.values.any((set) => set.contains(option)) ||
                   _inFlightDislikes.values.any((set) => set.contains(option)) ||
                   _postFlightDislikes.values.any((set) => set.contains(option)));
            
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                // Use the option as the category key
                final category = option;
                _updateAllPhaseSelections(category, option, isLikes);
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
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        SizedBox(height: 12),

        // Tell Us More and Media buttons
        Row(
          children: [
            // Tell Us More button
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (isLikes) {
                      _showLikesCommentBox = !_showLikesCommentBox;
                    } else {
                      _showDislikesCommentBox = !_showDislikesCommentBox;
                    }
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[600]!, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Tell Us More',
                        style: AppStyles.textStyle_14_500
                            .copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(width: 8),

            // Media button
            Expanded(
              child: GestureDetector(
                onTap: () => _showMediaOptions(isLikes),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[600]!, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Media',
                        style: AppStyles.textStyle_14_500
                            .copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // Comment box (if enabled)
        if ((isLikes && _showLikesCommentBox) ||
            (!isLikes && _showDislikesCommentBox))
          Container(
            margin: EdgeInsets.only(top: 12),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share more about what you ${isLikes ? 'liked' : 'disliked'}...',
                  style: AppStyles.textStyle_14_500
                      .copyWith(color: Colors.grey[600]),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: isLikes
                      ? _likesCommentController
                      : _dislikesCommentController,
                  maxLines: 3,
                  maxLength: 250,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: color),
                    ),
                    contentPadding: EdgeInsets.all(12),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ],
            ),
          ),

        // Media upload section (if enabled)
        if ((isLikes && _showLikesCommentBox) ||
            (!isLikes && _showDislikesCommentBox))
          Container(
            margin: EdgeInsets.only(top: 12),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Media Upload',
                  style:
                      AppStyles.textStyle_14_600.copyWith(color: Colors.black),
                ),
                SizedBox(height: 8),
                Text(
                  'Add photo or video (optional)',
                  style: AppStyles.textStyle_12_400
                      .copyWith(color: Colors.grey[600]),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _uploadImage(isLikes),
                        icon: Icon(Icons.camera_alt, color: Colors.white),
                        label: Text('Upload Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _recordVideo(isLikes),
                        icon: Icon(Icons.videocam, color: Colors.white),
                        label: Text('Record Video'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Display uploaded media
                if ((isLikes ? _likesMediaFiles : _dislikesMediaFiles).isNotEmpty) ...[
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (isLikes ? _likesMediaFiles : _dislikesMediaFiles)
                        .map((file) => _buildMediaPreview(file, isLikes))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMediaPreview(String filePath, bool isLikes) {
    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: filePath.endsWith('.mp4') || filePath.endsWith('.mov')
                ? Container(
                    color: Colors.black,
                    child: Icon(Icons.videocam, color: Colors.white, size: 32),
                  )
                : Image.file(
                    File(filePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.image, color: Colors.grey[400]);
                    },
                  ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () {
              setState(() {
                if (isLikes) {
                  _likesMediaFiles.remove(filePath);
                } else {
                  _dislikesMediaFiles.remove(filePath);
                }
              });
            },
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  void _showMediaOptions(bool isLikes) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add Media',
              style: AppStyles.textStyle_20_600,
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _uploadImage(isLikes);
                    },
                    icon: Icon(Icons.camera_alt, color: Colors.white),
                    label: Text('Upload Image'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _recordVideo(isLikes);
                    },
                    icon: Icon(Icons.videocam, color: Colors.white),
                    label: Text('Record Video'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadImage(bool isLikes) async {
    try {
      final String? imagePath = await MediaService.pickImage(fromCamera: false);

      if (imagePath != null) {
        setState(() {
          if (isLikes) {
            _likesMediaFiles.add(imagePath);
          } else {
            _dislikesMediaFiles.add(imagePath);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding image'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _recordVideo(bool isLikes) async {
    try {
      final String? videoPath = await MediaService.recordVideo();

      if (videoPath != null) {
        setState(() {
          if (isLikes) {
            _likesMediaFiles.add(videoPath);
          } else {
            _dislikesMediaFiles.add(videoPath);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error recording video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error recording video'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
      final journeyId = widget.flight.journeyId ?? widget.flight.pnr; // Use journeyId if available, fallback to PNR
      final seat = widget.flight.seatNumber ?? 'Unknown';

      debugPrint(
          '📝 Submitting feedback for user: $userId, flight: $flightId, journey: $journeyId');

      // Submit feedback for each phase to the correct table
      // - Completed/Landed flights: Only submit "Post-Flight" (overall experience)
      // - In Flight: Only submit "In-Flight" and "Post-Flight" (hide Pre-Flight/At Airport)
      // - Other phases: Submit all phases (Pre-Flight, In-Flight, Post-Flight)
      final isCompleted = widget.flight.currentPhase == FlightPhase.completed;
      final isLanded = widget.flight.currentPhase == FlightPhase.landed;
      final isInFlight = widget.flight.currentPhase == FlightPhase.inFlight;
      
      final phases = (isCompleted || isLanded)
          ? [
              // Only Post-Flight for completed/landed flights
              {
                'phase': 'Post-Flight',
                'likes': _postFlightLikes,
                'dislikes': _postFlightDislikes,
              },
            ]
          : isInFlight
              ? [
                  // Hide Pre-Flight when flight is in flight
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
                ]
              : [
                  // All phases for other active flight phases
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
      List<String> failedPhases = [];
      
      for (final phaseData in phases) {
        final phase = phaseData['phase'] as String;
        final likes = phaseData['likes'] as Map<String, Set<String>>;
        final dislikes = phaseData['dislikes'] as Map<String, Set<String>>;

        debugPrint('🔄 Processing phase: $phase');
        debugPrint('   Likes: $likes');
        debugPrint('   Dislikes: $dislikes');
        debugPrint('   Likes comment: ${_likesCommentController.text}');
        debugPrint('   Dislikes comment: ${_dislikesCommentController.text}');

        // Combine text comments with selections
        // Add comments to the appropriate map so they're included in submission
        final likesWithComments = Map<String, Set<String>>.from(likes);
        final dislikesWithComments = Map<String, Set<String>>.from(dislikes);
        
        // Include text comments in the feedback
        if (_likesCommentController.text.isNotEmpty) {
          if (!likesWithComments.containsKey('Additional Comments')) {
            likesWithComments['Additional Comments'] = <String>{};
          }
          likesWithComments['Additional Comments']!.add(_likesCommentController.text);
        }
        
        if (_dislikesCommentController.text.isNotEmpty) {
          if (!dislikesWithComments.containsKey('Additional Comments')) {
            dislikesWithComments['Additional Comments'] = <String>{};
          }
          dislikesWithComments['Additional Comments']!.add(_dislikesCommentController.text);
        }

        // Check if there's any feedback to submit (at minimum, we have the overall rating)
        final hasLikes = likesWithComments.values.any((set) => set.isNotEmpty);
        final hasDislikes = dislikesWithComments.values.any((set) => set.isNotEmpty);
        final hasComments = _likesCommentController.text.isNotEmpty || _dislikesCommentController.text.isNotEmpty;
        
        if (!hasLikes && !hasDislikes && !hasComments) {
          debugPrint('⚠️ No feedback selections for phase: $phase, but submitting with overall rating only');
        }

        try {
          final success = await PhaseFeedbackService.submitPhaseFeedback(
            userId: userId,
            journeyId: journeyId,
            flightId: flightId,
            seat: seat,
            phase: phase,
            overallRating: _overallRating,
            likes: likesWithComments,
            dislikes: dislikesWithComments,
          );

          if (!success) {
            allSuccess = false;
            failedPhases.add(phase);
            debugPrint('❌ Failed to submit feedback for phase: $phase');
          } else {
            debugPrint('✅ Successfully submitted feedback for phase: $phase');
          }
        } catch (e, stackTrace) {
          allSuccess = false;
          failedPhases.add(phase);
          debugPrint('❌ Exception submitting feedback for phase: $phase');
          debugPrint('   Error: $e');
          debugPrint('   Stack trace: $stackTrace');
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
        final errorMessage = failedPhases.isEmpty
            ? 'Some feedback failed to submit. Please try again.'
            : 'Failed to submit feedback for: ${failedPhases.join(', ')}. Please try again.';
        _showErrorDialog(errorMessage);
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
                  style:
                      AppStyles.textStyle_24_600.copyWith(color: Colors.black),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 12),

                // Description
                Text(
                  'Thank you! Your feedback has been recorded and sent to the airline.',
                  style: AppStyles.textStyle_16_400
                      .copyWith(color: Colors.grey[600]),
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
                      style: AppStyles.textStyle_16_600
                          .copyWith(color: Colors.white),
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
                  style:
                      AppStyles.textStyle_24_600.copyWith(color: Colors.black),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 12),

                // Description
                Text(
                  message,
                  style: AppStyles.textStyle_16_400
                      .copyWith(color: Colors.grey[600]),
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
                      style: AppStyles.textStyle_16_600
                          .copyWith(color: Colors.white),
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
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return 'Rate your experience';
    }
  }

  // Unified categories for all phases
  List<String> _getUnifiedLikes() {
    return [
      'Airport Experience (Departure and Arrival)',
      'F&B',
      'Seat Comfort',
      'Entertainment',
      'Wi-Fi',
      'Onboard Service',
      'Cleanliness',
    ];
  }

  List<String> _getUnifiedDislikes() {
    return [
      'Airport Experience (Departure and Arrival)',
      'F&B',
      'Seat Comfort',
      'Entertainment',
      'Wi-Fi',
      'Onboard Service',
      'Cleanliness',
    ];
  }

  // Keep old methods for backward compatibility (not used in UI)
  List<String> _getPreFlightLikes() => _getUnifiedLikes();
  List<String> _getPreFlightDislikes() => _getUnifiedDislikes();
  String _getPreFlightCategory(String option) => option;
  List<String> _getInFlightLikes() => _getUnifiedLikes();
  List<String> _getInFlightDislikes() => _getUnifiedDislikes();
  String _getInFlightCategory(String option) => option;
  List<String> _getPostFlightLikes() => _getUnifiedLikes();
  List<String> _getPostFlightDislikes() => _getUnifiedDislikes();
  String _getPostFlightCategory(String option) => option;
}
