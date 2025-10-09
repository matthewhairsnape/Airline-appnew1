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

class _SectionFeedbackModalState extends State<SectionFeedbackModal> {
  int _rating = 0;
  Set<String> _selectedLikes = {};
  Set<String> _selectedDislikes = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
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
                        }
                      });
                    },
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
                        }
                      });
                    },
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
    
    Navigator.pop(context);
    widget.onSubmitted?.call();
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
}
