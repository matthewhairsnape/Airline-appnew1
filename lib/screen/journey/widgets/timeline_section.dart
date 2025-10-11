import 'package:flutter/material.dart';
import '../../../models/flight_tracking_model.dart';
import '../../../utils/app_styles.dart';
import 'timeline_event_card.dart';
import 'section_feedback_modal.dart';

class TimelineSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<TimelineEvent> events;
  final bool isExpanded;
  final VoidCallback? onToggle;

  const TimelineSection({
    Key? key,
    required this.title,
    required this.icon,
    required this.events,
    this.isExpanded = false,
    this.onToggle,
  }) : super(key: key);

  @override
  State<TimelineSection> createState() => _TimelineSectionState();
}

class _TimelineSectionState extends State<TimelineSection> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Section Header
          InkWell(
            onTap: widget.onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getIconColor().withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.icon,
                      color: _getIconColor(),
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppStyles.textStyle_18_600.copyWith(
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Icon(
                    widget.isExpanded 
                        ? Icons.keyboard_arrow_up 
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey[600],
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded Content
          if (widget.isExpanded) ...[
            Divider(height: 1, color: Colors.grey[200]),
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  ...widget.events.map((event) => 
                    Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: TimelineEventCard(event: event),
                    ),
                  ).toList(),
                  
                  // Feedback Button
                  SizedBox(height: 16),
                  _buildFeedbackButton(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getIconColor() {
    // Use black for uniformed branding
    return Colors.black;
  }

  Widget _buildFeedbackButton() {
    return GestureDetector(
      onTap: _showFeedbackModal,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withAlpha(30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.feedback_outlined,
              color: Colors.black,
              size: 16,
            ),
            SizedBox(width: 8),
            Text(
              'Share ${widget.title} Feedback',
              style: AppStyles.textStyle_14_500.copyWith(color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  void _showFeedbackModal() {
    final feedbackData = _getFeedbackData();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SectionFeedbackModal(
        sectionName: widget.title,
        likes: feedbackData['likes'] ?? [],
        dislikes: feedbackData['dislikes'] ?? [],
        onSubmitted: () {
          // TODO: Submit feedback to backend
          debugPrint('${widget.title} feedback submitted');
        },
      ),
    );
  }

  Map<String, List<String>> _getFeedbackData() {
    switch (widget.title) {
      case 'At The Airport':
        return {
          'likes': [
            'Check-in process',
            'Security line wait time',
            'Boarding process',
            'Airport Facilities and Shops',
            'Smooth Airport experience',
            'Airline Lounge',
            'Something else',
          ],
          'dislikes': [
            'Check-in process',
            'Security line wait time',
            'Boarding process',
            'Airport Facilities and Shops',
            'Smooth Airport experience',
            'Airline Lounge',
            'Something else',
          ],
        };
      case 'In The Air':
        return {
          'likes': [
            'Seat comfort',
            'Cabin cleanliness',
            'Cabin crew',
            'In-flight entertainment',
            'Wi-Fi',
            'Food and beverage',
            'Something else',
          ],
          'dislikes': [
            'Seat comfort',
            'Cabin cleanliness',
            'Cabin crew',
            'In-flight entertainment',
            'Wi-Fi',
            'Food and beverage',
            'Something else',
          ],
        };
      case 'Touched Down':
        return {
          'likes': [
            'Friendly and helpful service',
            'Smooth and troublefree flight',
            'Onboard Comfort',
            'Food and Beverage',
            'Wi-Fi and IFE',
            'Communication from airline',
            'Baggage delivery or ease of connection',
            'Something else',
          ],
          'dislikes': [
            'Wi-Fi',
            'Friendly and helpful service',
            'Stressful and uneasy flight',
            'Onboard Comfort',
            'Food and Beverage',
            'Wi-Fi and IFE',
            'Communication from airline',
            'Baggage delivery or ease of connection',
            'Something else',
          ],
        };
      default:
        return {'likes': [], 'dislikes': []};
    }
  }
}

class TimelineEvent {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final IconData icon;
  final String? location;
  final bool isCompleted;
  final bool hasFeedback;

  TimelineEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.icon,
    this.location,
    this.isCompleted = true,
    this.hasFeedback = false,
  });
}
