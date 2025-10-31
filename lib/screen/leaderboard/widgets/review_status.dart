import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';

class ReviewStatus extends StatefulWidget {
  const ReviewStatus({
    super.key,
    required this.reviewStatus,
    required this.overallScore,
    required this.totalReviews,
  });

  final bool reviewStatus;
  final num overallScore;
  final int totalReviews;

  @override
  State<ReviewStatus> createState() => _ReviewStatusState();
}

class _ReviewStatusState extends State<ReviewStatus> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          width: 1.5,
          color: widget.reviewStatus
              ? const Color(0xFF4CAF50)
              : const Color(0xFFFF5252),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.reviewStatus ? Icons.trending_up : Icons.trending_down,
            size: 18,
            color: widget.reviewStatus
                ? const Color(0xFF4CAF50)
                : const Color(0xFFFF5252),
          ),
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              style: AppStyles.textStyle_14_600.copyWith(color: Colors.black87),
              children: [
                TextSpan(
                  text: widget.overallScore.toStringAsFixed(1),
                  style: AppStyles.textStyle_14_600.copyWith(
                    color: widget.reviewStatus
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF5252),
                  ),
                ),
                const TextSpan(text: ' /10 • '),
                TextSpan(text: '${widget.totalReviews} reviews'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
