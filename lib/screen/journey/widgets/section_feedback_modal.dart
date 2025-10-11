import 'package:flutter/material.dart';
import '../../../utils/app_styles.dart';
import '../../../models/flight_tracking_model.dart';

class SectionFeedbackModal extends StatefulWidget {
  final String sectionName;
  final List<String> likes;
  final List<String> dislikes;
  final VoidCallback? onSubmitted;

  const SectionFeedbackModal({
    Key? key,
    required this.sectionName,
    required this.likes,
    required this.dislikes,
    this.onSubmitted,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
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
          
          // Animated header with stage-specific image
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
                      height: 200,
                      margin: EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 15,
                            offset: Offset(0, 5),
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
          
          SizedBox(height: 20),
          
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
                    '${widget.sectionName} Feedback',
                    style: AppStyles.textStyle_20_600.copyWith(color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(width: 48), // Balance the close button
              ],
            ),
          ),
          
          SizedBox(height: 24),
          
          // Rating Section
          _buildRatingSection(),
          
          SizedBox(height: 32),
          
          // Feedback Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // What stands out section
                  _buildFeedbackSection(
                    'What stands out?',
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
                          // Remove from dislikes if it was selected there
                          _selectedDislikes.remove(value);
                        }
                      });
                    },
                    true, // isLikes
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
                          // Remove from likes if it was selected there
                          _selectedLikes.remove(value);
                        }
                      });
                    },
                    false, // isLikes
                  ),
                ],
              ),
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

  Widget _buildRatingSection() {
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
            'Rate Your ${widget.sectionName} Experience',
            style: AppStyles.textStyle_18_600.copyWith(color: Colors.black),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _rating = index + 1;
                  });
                },
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: index < _rating ? Colors.amber : Colors.grey[400],
                    size: 32,
                  ),
                ),
              );
            }),
          ),
          SizedBox(height: 8),
          Text(
            _getRatingText(_rating),
            style: AppStyles.textStyle_14_500.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
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
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
                        style: AppStyles.textStyle_14_500.copyWith(color: Colors.white),
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
                        style: AppStyles.textStyle_14_500.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        
        // Comment box (if enabled)
        if ((isLikes && _showLikesCommentBox) || (!isLikes && _showDislikesCommentBox))
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
                  style: AppStyles.textStyle_14_500.copyWith(color: Colors.grey[600]),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: isLikes ? _likesCommentController : _dislikesCommentController,
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
                    counterText: '${(isLikes ? _likesCommentController : _dislikesCommentController).text.length}/250',
                  ),
                ),
              ],
            ),
          ),
        
        // Media upload section (if enabled)
        if ((isLikes && _likesMediaFiles.isNotEmpty) || (!isLikes && _dislikesMediaFiles.isNotEmpty))
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
                  style: AppStyles.textStyle_14_600.copyWith(color: Colors.black),
                ),
                SizedBox(height: 8),
                Text(
                  'Add photo or video (optional)',
                  style: AppStyles.textStyle_12_400.copyWith(color: Colors.grey[600]),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _uploadImage(isLikes),
                        icon: Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        label: Text('Upload Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
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
                        icon: Icon(Icons.videocam, color: Colors.white, size: 16),
                        label: Text('Record Clip'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
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
      ],
    );
  }

  bool _canSubmit() {
    return _rating > 0;
  }

  void _submitFeedback() {
    debugPrint('${widget.sectionName} Feedback:');
    debugPrint('Rating: $_rating');
    debugPrint('Likes: $_selectedLikes');
    debugPrint('Dislikes: $_selectedDislikes');
    debugPrint('Likes Comment: ${_likesCommentController.text}');
    debugPrint('Dislikes Comment: ${_dislikesCommentController.text}');
    debugPrint('Likes Media: $_likesMediaFiles');
    debugPrint('Dislikes Media: $_dislikesMediaFiles');
    
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

  String _getSectionImage(String sectionName) {
    switch (sectionName.toLowerCase()) {
      case 'at the airport':
        return 'assets/images/Airport 2.png';
      case 'in the air':
        return 'assets/images/Flight 2.png';
      case 'touched down':
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

  void _uploadImage(bool isLikes) {
    // TODO: Implement image picker
    // For now, just add a placeholder
    setState(() {
      if (isLikes) {
        _likesMediaFiles.add('image_${DateTime.now().millisecondsSinceEpoch}.jpg');
      } else {
        _dislikesMediaFiles.add('image_${DateTime.now().millisecondsSinceEpoch}.jpg');
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Image upload functionality coming soon!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _recordVideo(bool isLikes) {
    // TODO: Implement video recording
    // For now, just add a placeholder
    setState(() {
      if (isLikes) {
        _likesMediaFiles.add('video_${DateTime.now().millisecondsSinceEpoch}.mp4');
      } else {
        _dislikesMediaFiles.add('video_${DateTime.now().millisecondsSinceEpoch}.mp4');
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Video recording functionality coming soon!'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
