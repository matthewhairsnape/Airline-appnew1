import 'package:flutter/material.dart';
import 'package:airline_app/utils/app_styles.dart';

class MediaUploadWidget extends StatelessWidget {
  final VoidCallback onTap;
  final String title;

  const MediaUploadWidget({
    super.key,
    required this.onTap,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.17,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(25),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.file_upload_outlined,
                size: 28,
                color: Colors.green,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Choose your $title media for upload",
            style: AppStyles.textStyle_15_600.copyWith(
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}
