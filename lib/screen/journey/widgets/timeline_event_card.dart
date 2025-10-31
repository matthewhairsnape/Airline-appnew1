import 'package:flutter/material.dart';
import '../../../utils/app_styles.dart';
import 'timeline_section.dart';

class TimelineEventCard extends StatelessWidget {
  final TimelineEvent event;

  const TimelineEventCard({
    Key? key,
    required this.event,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              event.icon,
              color: event.isCompleted ? Colors.black : Colors.grey[400],
              size: 20,
            ),
          ),

          SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: AppStyles.textStyle_14_600.copyWith(
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  event.description,
                  style: AppStyles.textStyle_12_500.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                if (event.location != null) ...[
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.grey[500],
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        event.location!,
                        style: AppStyles.textStyle_12_500.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Time
          Text(
            _formatTime(event.timestamp),
            style: AppStyles.textStyle_12_500.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}
