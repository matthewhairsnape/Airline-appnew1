import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../../utils/app_styles.dart';
import '../../../services/media_service.dart';
import '../../../services/phase_feedback_service.dart';
import '../../../services/supabase_service.dart';
import '../../../models/flight_tracking_model.dart';

class SectionFeedbackModal extends StatefulWidget {
  final String sectionName;
  final List<String> likes;
  final List<String> dislikes;
  final VoidCallback? onSubmitted;
  final FlightTrackingModel? flight;

  const SectionFeedbackModal({
    Key? key,
    required this.sectionName,
    required this.likes,
    required this.dislikes,
    this.onSubmitted,
    this.flight,
  }) : super(key: key);

  @override
  State<SectionFeedbackModal> createState() => _SectionFeedbackModalState();
}

class _SectionFeedbackModalState extends State<SectionFeedbackModal>
    with TickerProviderStateMixin {
  int _rating = 0;
  Set<String> _selectedLikes = {};
  Set<String> _selectedDislikes = {};
  late AnimationController _animationController;
  late AnimationController _floatingController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _floatingAnimation;

  // New state for Tell Us More and Media
  bool _showLikesCommentBox = false;
  bool _showDislikesCommentBox = false;
  TextEditingController _likesCommentController = TextEditingController();
  TextEditingController _dislikesCommentController = TextEditingController();
  List<String> _likesMediaFiles = [];
  List<String> _dislikesMediaFiles = [];
  ScrollController _scrollController = ScrollController();
  FocusNode _likesFocusNode = FocusNode();
  FocusNode _dislikesFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _floatingController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _floatingAnimation = Tween<double>(
      begin: -0.02,
      end: 0.02,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
    _floatingController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _floatingController.dispose();
    _likesCommentController.dispose();
    _dislikesCommentController.dispose();
    _scrollController.dispose();
    _likesFocusNode.dispose();
    _dislikesFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24,
                      keyboardPadding > 0 ? keyboardPadding + 24 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header image with animation
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: AnimatedBuilder(
                            animation: _floatingAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, _floatingAnimation.value * 5),
                                child: Container(
                                  height: 180,
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
                                      _getSectionImage(widget.sectionName),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      SizedBox(height: 24),

                      // Title
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${widget.sectionName} Feedback',
                              style: AppStyles.textStyle_24_600,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.grey[600]),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),

                      SizedBox(height: 8),

                      // Subtitle
                      Text(
                        'Rate your ${widget.sectionName.toLowerCase()} experience',
                        style: AppStyles.textStyle_16_400
                            .copyWith(color: Colors.grey[600]),
                      ),

                      SizedBox(height: 24),

                      // Star rating
                      _buildRatingSection(),

                      SizedBox(height: 32),

                      // Feedback tags and comments
                      _buildFeedbackContent(),
                    ],
                  ),
                ),
              ),
            ),

            // Sticky submit button with safe area
            SafeArea(
              top: false,
              child: Container(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _canSubmit() ? _submitFeedback : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    disabledBackgroundColor: Colors.grey[300],
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.feedback, color: Colors.white, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'Submit Feedback',
                        style: AppStyles.textStyle_16_600
                            .copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // What stands out section
        _buildFeedbackSection(
          'What Stands Out',
          widget.likes,
          _selectedLikes,
          Icons.thumb_up,
          Colors.green,
          (value) {
            setState(() {
              if (_selectedLikes.contains(value)) {
                _selectedLikes.remove(value);
              } else {
                _selectedLikes.add(value);
                _selectedDislikes.remove(value);
              }
            });
            HapticFeedback.selectionClick();
          },
          true,
        ),

        SizedBox(height: 32),

        // What could be improved section
        _buildFeedbackSection(
          'What could be improved?',
          widget.dislikes,
          _selectedDislikes,
          Icons.thumb_down,
          Colors.red,
          (value) {
            setState(() {
              if (_selectedDislikes.contains(value)) {
                _selectedDislikes.remove(value);
              } else {
                _selectedDislikes.add(value);
                _selectedLikes.remove(value);
              }
            });
            HapticFeedback.selectionClick();
          },
          false,
        ),

        SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRatingSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  _rating = index + 1;
                });
                HapticFeedback.selectionClick();
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  index < _rating
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: index < _rating ? Colors.amber : Colors.grey[300],
                  size: 44,
                ),
              ),
            );
          }),
        ),
        if (_rating > 0) ...[
          SizedBox(height: 12),
          Text(
            _getRatingText(_rating),
            style: AppStyles.textStyle_16_600.copyWith(color: Colors.grey[700]),
          ),
        ],
      ],
    );
  }

  Widget _buildFeedbackSection(
    String title,
    List<String> options,
    Set<String> selected,
    IconData icon,
    Color color,
    Function(String) onTap,
    bool isLikes,
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

        // Regular feedback options
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return GestureDetector(
              onTap: () => onTap(option),
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
                  focusNode: isLikes ? _likesFocusNode : _dislikesFocusNode,
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
                    counterText:
                        '${(isLikes ? _likesCommentController : _dislikesCommentController).text.length}/250',
                  ),
                  onChanged: (value) {
                    setState(() {}); // Refresh to show live preview
                  },
                  onTap: () {
                    // Scroll to the text field when tapped
                    Future.delayed(Duration(milliseconds: 300), () {
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent * 0.8,
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    });
                  },
                ),
                // Live preview of comment
                if ((isLikes
                        ? _likesCommentController
                        : _dislikesCommentController)
                    .text
                    .isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(top: 8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: color.withOpacity(0.3), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preview:',
                          style:
                              AppStyles.textStyle_12_600.copyWith(color: color),
                        ),
                        SizedBox(height: 4),
                        Text(
                          (isLikes
                                  ? _likesCommentController
                                  : _dislikesCommentController)
                              .text,
                          style: AppStyles.textStyle_14_400
                              .copyWith(color: Colors.black87),
                        ),
                      ],
                    ),
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
                        icon: Icon(Icons.camera_alt,
                            color: Colors.white, size: 16),
                        label: Text('Upload Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _recordVideo(isLikes),
                        icon:
                            Icon(Icons.videocam, color: Colors.white, size: 16),
                        label: Text('Record Clip'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Media thumbnails preview
        if ((isLikes && _likesMediaFiles.isNotEmpty) ||
            (!isLikes && _dislikesMediaFiles.isNotEmpty))
          Container(
            margin: EdgeInsets.only(top: 12),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[300]!, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Media Added Successfully',
                      style: AppStyles.textStyle_14_600
                          .copyWith(color: Colors.green[700]),
                    ),
                    Spacer(),
                    Text(
                      '${(isLikes ? _likesMediaFiles : _dislikesMediaFiles).length} file(s)',
                      style: AppStyles.textStyle_12_500
                          .copyWith(color: Colors.green[600]),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                // Thumbnails grid
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (isLikes ? _likesMediaFiles : _dislikesMediaFiles)
                      .map((mediaPath) {
                    return _buildMediaThumbnail(mediaPath, isLikes);
                  }).toList(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  bool _canSubmit() {
    return _rating > 0;
  }

  Future<void> _submitFeedback() async {
    debugPrint('${widget.sectionName} Feedback:');
    debugPrint('Rating: $_rating');
    debugPrint('Likes: $_selectedLikes');
    debugPrint('Dislikes: $_selectedDislikes');
    debugPrint('Likes Comment: ${_likesCommentController.text}');
    debugPrint('Dislikes Comment: ${_dislikesCommentController.text}');
    debugPrint('Likes Media: $_likesMediaFiles');
    debugPrint('Dislikes Media: $_dislikesMediaFiles');

    // Save to database if flight data is available
    if (widget.flight != null) {
      try {
        // Get current user
        final session = SupabaseService.client.auth.currentSession;
        if (session?.user.id == null) {
          _showErrorDialog('User not authenticated. Please log in again.');
          return;
        }

        final userId = session!.user.id;
        final flightId = widget.flight!.flightId;
        final journeyId = widget.flight!.journeyId ?? widget.flight!.pnr; // Use journeyId if available, fallback to PNR
        final seat = widget.flight!.seatNumber ?? 'Unknown';

        // Prevent "At the Airport" feedback when flight is in flight, landed, or completed
        if (widget.sectionName.toLowerCase() == 'at the airport' &&
            (widget.flight?.currentPhase == FlightPhase.inFlight ||
             widget.flight?.currentPhase == FlightPhase.landed ||
             widget.flight?.currentPhase == FlightPhase.completed)) {
          _showErrorDialog(
              'Airport feedback is not available at this stage of your journey.');
          return;
        }
        
        // Prevent "During the Flight" feedback when flight is landed or completed
        if (widget.sectionName.toLowerCase() == 'during the flight' &&
            (widget.flight?.currentPhase == FlightPhase.landed ||
             widget.flight?.currentPhase == FlightPhase.completed)) {
          _showErrorDialog(
              'In-flight feedback is not available after the flight has landed.');
          return;
        }

        debugPrint(
            '📝 Submitting ${widget.sectionName} feedback for user: $userId, flight: $flightId, journey: $journeyId');

        // Convert selected likes/dislikes to the format expected by PhaseFeedbackService
        final Map<String, Set<String>> likesMap = {
          'likes': _selectedLikes,
        };
        final Map<String, Set<String>> dislikesMap = {
          'dislikes': _selectedDislikes,
        };

        // Add comments to the maps
        if (_likesCommentController.text.isNotEmpty) {
          likesMap['comments'] = {_likesCommentController.text};
        }
        if (_dislikesCommentController.text.isNotEmpty) {
          dislikesMap['comments'] = {_dislikesCommentController.text};
        }

        final success = await PhaseFeedbackService.submitPhaseFeedback(
          userId: userId,
          journeyId: journeyId,
          flightId: flightId,
          seat: seat,
          phase: widget.sectionName,
          overallRating: _rating,
          likes: likesMap,
          dislikes: dislikesMap,
        );

        if (success) {
          debugPrint('✅ ${widget.sectionName} feedback submitted successfully');
        } else {
          debugPrint('❌ Failed to submit ${widget.sectionName} feedback');
        }
      } catch (e) {
        debugPrint('❌ Error submitting ${widget.sectionName} feedback: $e');
      }
    } else {
      debugPrint(
          '⚠️ No flight data available for ${widget.sectionName} feedback');
    }

    // Close the feedback modal
    Navigator.pop(context);

    // Show confirmation dialog
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

  String _getSectionImage(String sectionName) {
    switch (sectionName.toLowerCase()) {
      case 'at the airport':
        return 'assets/images/Airport 2.png';
      case 'during the flight':
        return 'assets/images/Flight 2.png';
      case 'overall experience':
        return 'assets/images/End of Flight.png';
      default:
        return 'assets/images/Airport 2.png';
    }
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
          ],
        ),
      ),
    );
  }

  void _uploadImage(bool isLikes) async {
    try {
      // Show source selection dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Select Image Source'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.camera_alt),
                  title: Text('Camera'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImageFromSource(true, isLikes);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library),
                  title: Text('Gallery'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImageFromSource(false, isLikes);
                  },
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('❌ Error showing image source dialog: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image source'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImageFromSource(bool fromCamera, bool isLikes) async {
    try {
      final String? imagePath =
          await MediaService.pickImage(fromCamera: fromCamera);

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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No image selected'),
            backgroundColor: Colors.orange,
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

  void _recordVideo(bool isLikes) async {
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
            content: Text('Video recorded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video recording cancelled'),
            backgroundColor: Colors.orange,
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

  Widget _buildMediaThumbnail(String mediaPath, bool isLikes) {
    final String fileName = mediaPath.split('/').last;
    final bool isImage = fileName.toLowerCase().endsWith('.jpg') ||
        fileName.toLowerCase().endsWith('.jpeg') ||
        fileName.toLowerCase().endsWith('.png');
    final bool isVideo = fileName.toLowerCase().endsWith('.mp4') ||
        fileName.toLowerCase().endsWith('.mov') ||
        fileName.toLowerCase().endsWith('.avi');

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Media preview
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Container(
              width: 80,
              height: 80,
              color: Colors.grey[100],
              child: isImage
                  ? Image.file(
                      File(mediaPath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.image,
                            color: Colors.grey[400], size: 32);
                      },
                    )
                  : isVideo
                      ? Container(
                          color: Colors.black.withOpacity(0.8),
                          child: Icon(Icons.play_circle_filled,
                              color: Colors.white, size: 32),
                        )
                      : Icon(Icons.insert_drive_file,
                          color: Colors.grey[400], size: 32),
            ),
          ),
          // Remove button
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (isLikes) {
                    _likesMediaFiles.remove(mediaPath);
                  } else {
                    _dislikesMediaFiles.remove(mediaPath);
                  }
                });
              },
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: Colors.white, size: 12),
              ),
            ),
          ),
          // Media type indicator
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isImage
                    ? 'IMG'
                    : isVideo
                        ? 'VID'
                        : 'FILE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
