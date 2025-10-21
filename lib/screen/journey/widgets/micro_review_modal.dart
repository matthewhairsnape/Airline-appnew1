import 'package:flutter/material.dart';
import '../../../utils/app_styles.dart';
import '../../../models/stage_feedback_model.dart';
import '../../app_widgets/main_button.dart';

class MicroReviewModal extends StatefulWidget {
  final JourneyEvent event;
  final Function(int rating, String? comment) onSubmitted;

  const MicroReviewModal({
    Key? key,
    required this.event,
    required this.onSubmitted,
  }) : super(key: key);

  @override
  State<MicroReviewModal> createState() => _MicroReviewModalState();
}

class _MicroReviewModalState extends State<MicroReviewModal> {
  int? _selectedRating;
  final TextEditingController _commentController = TextEditingController();
  final List<String> _sentimentEmojis = ['😞', '😐', '😊', '😄', '🤩'];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        widget.event.icon,
                        color: Colors.blue[600],
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.event.title,
                            style: AppStyles.textStyle_18_600.copyWith(
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            widget.event.description,
                            style: AppStyles.textStyle_14_400.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Divider(height: 1, color: Colors.grey[200]),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rating section
                  Text(
                    'How was your experience?',
                    style: AppStyles.textStyle_16_600.copyWith(
                      color: Colors.black,
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Star rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedRating = index + 1;
                          });
                        },
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            index < (_selectedRating ?? 0) 
                                ? Icons.star 
                                : Icons.star_border,
                            color: index < (_selectedRating ?? 0) 
                                ? Colors.amber 
                                : Colors.grey[400],
                            size: 36,
                          ),
                        ),
                      );
                    }),
                  ),
                  
                  SizedBox(height: 8),
                  
                  // Rating text
                  Center(
                    child: Text(
                      _getRatingText(_selectedRating),
                      style: AppStyles.textStyle_14_500.copyWith(
                        color: _selectedRating != null 
                            ? Colors.grey[700] 
                            : Colors.grey[400],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Quick sentiment emojis
                  Text(
                    'Quick reaction:',
                    style: AppStyles.textStyle_14_500.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  
                  SizedBox(height: 12),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _sentimentEmojis.map((emoji) {
                      return GestureDetector(
                        onTap: () {
                          // Quick rating based on emoji
                          final emojiIndex = _sentimentEmojis.indexOf(emoji);
                          setState(() {
                            _selectedRating = emojiIndex + 1;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _selectedRating == _sentimentEmojis.indexOf(emoji) + 1
                                ? Colors.blue[50]
                                : Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedRating == _sentimentEmojis.indexOf(emoji) + 1
                                  ? Colors.blue[200]!
                                  : Colors.grey[200]!,
                            ),
                          ),
                          child: Text(
                            emoji,
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Optional comment
                  Text(
                    'Add a comment (optional):',
                    style: AppStyles.textStyle_14_500.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  
                  SizedBox(height: 8),
                  
                  TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Tell us more about your experience...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Color(0xFF3B82F6)),
                      ),
                      contentPadding: EdgeInsets.all(12),
                    ),
                    maxLines: 3,
                    maxLength: 200,
                  ),
                ],
              ),
            ),
          ),
          
          // Submit button
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child:             MainButton(
              text: 'Submit Feedback',
              onPressed: _selectedRating != null ? _submitFeedback : () {},
              color: _selectedRating != null 
                  ? Color(0xFF3B82F6) 
                  : Colors.grey[400]!,
            ),
          ),
        ],
      ),
    );
  }

  void _submitFeedback() {
    if (_selectedRating != null) {
      widget.onSubmitted(
        _selectedRating!,
        _commentController.text.isNotEmpty ? _commentController.text : null,
      );
    }
  }

  String _getRatingText(int? rating) {
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
        return 'Tap to rate';
    }
  }
}
