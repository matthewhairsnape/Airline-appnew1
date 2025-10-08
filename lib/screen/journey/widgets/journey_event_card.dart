import 'package:flutter/material.dart';
import '../../../utils/app_styles.dart';
import '../../../models/stage_feedback_model.dart';

class JourneyEventCard extends StatelessWidget {
  final JourneyEvent event;
  final VoidCallback? onFeedbackTap;
  final bool isActive;

  const JourneyEventCard({
    Key? key,
    required this.event,
    this.onFeedbackTap,
    this.isActive = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: event.isCompleted ? Colors.green[200]! : Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: event.isCompleted 
                      ? Colors.green[100] 
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  event.icon,
                  color: event.isCompleted 
                      ? Colors.green[600] 
                      : Colors.grey[600],
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: AppStyles.textStyle_16_600.copyWith(
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      event.description,
                      style: AppStyles.textStyle_14_400.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(event.timestamp),
                    style: AppStyles.textStyle_12_500.copyWith(
                      color: Colors.grey[500],
                    ),
                  ),
                  if (event.isCompleted)
                    Container(
                      margin: EdgeInsets.only(top: 4),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Completed',
                        style: AppStyles.textStyle_10_500.copyWith(
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (event.hasFeedback && !event.isCompleted && isActive) ...[
            SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.touch_app,
                  size: 16,
                  color: Colors.grey[500],
                ),
                SizedBox(width: 4),
                Text(
                  'Tap to provide feedback',
                  style: AppStyles.textStyle_12_400.copyWith(
                    color: Colors.grey[500],
                  ),
                ),
                Spacer(),
                GestureDetector(
                  onTap: onFeedbackTap,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'FEEDBACK',
                      style: AppStyles.textStyle_12_600.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (event.hasFeedback && !isActive) ...[
            SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.history,
                  size: 16,
                  color: Colors.grey[500],
                ),
                SizedBox(width: 4),
                Text(
                  'Flight completed - feedback no longer available',
                  style: AppStyles.textStyle_12_400.copyWith(
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

