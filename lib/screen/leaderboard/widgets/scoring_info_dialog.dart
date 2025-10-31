import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';

class ScoringInfoDialog extends StatelessWidget {
  final Offset offset;

  const ScoringInfoDialog({super.key, required this.offset});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: offset.dy + 100,
          right: 28,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 300,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 1,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 1,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'How the scoring works',
                          style: AppStyles.textStyle_14_500
                              .copyWith(color: Colors.black),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.check_outlined,
                            color: Colors.green, size: 20),
                      ],
                    ),
                  ),
                  SizedBox(height: 18),
                  Text(
                    'Realtime updates',
                    style: AppStyles.textStyle_15_600,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'score changes are calculated by analyzing the difference in sentiment scores submitted by users within a set timeframe (e.g, 24 hours or 7 days), reflecting the net improvement or decline in performance of the airline or airport.',
                    style: AppStyles.textStyle_14_500.copyWith(
                      color: Color(0xff38433E),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
