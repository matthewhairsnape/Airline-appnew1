import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';

class CommentInputField extends StatelessWidget {
  final TextEditingController commentController;
  final String title;
  final ValueChanged<String> onChange;
  final String hintText;
  const CommentInputField(
      {super.key,
      required this.commentController,
      required this.title,
      required this.onChange,
      required this.hintText});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppStyles.textStyle_14_600),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height * 0.08,
          ),
          decoration: AppStyles.cardDecoration.copyWith(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(25),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            onChanged: onChange,
            controller: commentController,
            maxLines: null,
            style: AppStyles.textStyle_15_600,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle:
                  AppStyles.textStyle_14_500.copyWith(color: Colors.grey[400]),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: const OutlineInputBorder(borderSide: BorderSide.none),
              focusedBorder:
                  const OutlineInputBorder(borderSide: BorderSide.none),
              enabledBorder:
                  const OutlineInputBorder(borderSide: BorderSide.none),
            ),
          ),
        ),
      ],
    );
  }
}
