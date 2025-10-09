import 'package:flutter/material.dart';
import '../../../models/flight_tracking_model.dart';
import '../../../utils/app_styles.dart';
import 'timeline_event_card.dart';

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
                children: widget.events.map((event) => 
                  Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: TimelineEventCard(event: event),
                  ),
                ).toList(),
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
