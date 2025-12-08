import 'package:flutter/material.dart';
import '../../../models/flight_tracking_model.dart';
import '../../../utils/app_styles.dart';
import 'timeline_event_card.dart';
import 'section_feedback_modal.dart';
import 'comprehensive_feedback_modal.dart';

class TimelineSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<TimelineEvent> events;
  final bool isExpanded;
  final VoidCallback? onToggle;
  final FlightTrackingModel? flight;

  const TimelineSection({
    Key? key,
    required this.title,
    required this.icon,
    required this.events,
    this.isExpanded = false,
    this.onToggle,
    this.flight,
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
                  ...widget.events
                      .map(
                        (event) => Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: TimelineEventCard(
                            event: event,
                            showTime: widget.title == 'At the Airport', // Only show time for "At the Airport" section
                          ),
                        ),
                      )
                      .toList(),

                  // Feedback Button
                  // Hide feedback button for:
                  // - "At the Airport" when flight is in flight, landed, or completed
                  // - "During the Flight" when flight is landed or completed
                  if (!_shouldHideFeedbackButton()) ...[
                    SizedBox(height: 16),
                    _buildFeedbackButton(),
                  ],
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

  /// Check if feedback button should be hidden based on flight phase
  bool _shouldHideFeedbackButton() {
    // Hide "At the Airport" feedback button when flight is landed or completed
    if (widget.title == 'At the Airport' &&
        (widget.flight?.currentPhase == FlightPhase.landed ||
         widget.flight?.currentPhase == FlightPhase.completed)) {
      return true;
    }
    
    // Hide "During the Flight" feedback button when flight is landed or completed
    if (widget.title == 'During the Flight' &&
        (widget.flight?.currentPhase == FlightPhase.landed ||
         widget.flight?.currentPhase == FlightPhase.completed)) {
      return true;
    }
    
    return false;
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
    // Prevent opening modal for "At the Airport" when flight is landed or completed
    if (widget.title == 'At the Airport' &&
        (widget.flight?.currentPhase == FlightPhase.landed ||
         widget.flight?.currentPhase == FlightPhase.completed)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Airport feedback is not available at this stage of your journey.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Prevent opening modal for "During the Flight" when flight is landed or completed
    if (widget.title == 'During the Flight' &&
        (widget.flight?.currentPhase == FlightPhase.landed ||
         widget.flight?.currentPhase == FlightPhase.completed)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('In-flight feedback is not available after the flight has landed.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Use ComprehensiveFeedbackModal for "Overall Experience" to match Review Flight form
    if (widget.title == 'Overall Experience' && widget.flight != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        enableDrag: true,
        isDismissible: true,
        useSafeArea: false,
        builder: (context) => ComprehensiveFeedbackModal(
          flight: widget.flight!,
          onSubmitted: () {
            debugPrint('Overall Experience feedback submitted');
            Navigator.pop(context);
          },
        ),
      );
      return;
    }

    // Use SectionFeedbackModal for other sections (At the Airport, During the Flight)
    final feedbackData = _getFeedbackData();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      useSafeArea: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SectionFeedbackModal(
          sectionName: widget.title,
          likes: feedbackData['likes'] ?? [],
          dislikes: feedbackData['dislikes'] ?? [],
          flight: widget.flight,
          onSubmitted: () {
            debugPrint('${widget.title} feedback submitted');
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Map<String, List<String>> _getFeedbackData() {
    switch (widget.title) {
      case 'At the Airport':
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
      case 'During the Flight':
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
      case 'Overall Experience':
        return {
          'likes': [
            'Friendly and helpful service',
            'Smooth and troublefree Flight',
            'Cleanliness of the cabin',
            'Flight is on-time',
            'Accessiblity',
            'Fast Baggage Delivery',
            'Something Else',
          ],
          'dislikes': [
            'Service and Communication',
            'Unattended problems during flight',
            'Ontime performance',
            'Cleanliness of the cabin',
            'Accessibility',
            'Slow Baggage delivery',
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
