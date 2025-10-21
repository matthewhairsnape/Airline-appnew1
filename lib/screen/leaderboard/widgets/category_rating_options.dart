import 'package:airline_app/screen/reviewsubmission/widgets/subcategory_button_widget.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';

class CategoryRatingOptions extends StatefulWidget {
  final String iconUrl;
  final String label;
  final String? badgeScore;

  const CategoryRatingOptions(
      {super.key, required this.iconUrl, required this.label, this.badgeScore});

  @override
  // ignore: library_private_types_in_public_api
  _CategoryRatingOptionsState createState() => _CategoryRatingOptionsState();
}

class _CategoryRatingOptionsState extends State<CategoryRatingOptions> {
  bool _isClicked = false;

  void _toggleClick() {
    setState(() {
      _isClicked = !_isClicked; // Toggle the click state
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      SubcategoryButtonWidget(
          labelName: widget.label,
          onTap: _toggleClick,
          isSelected: _isClicked,
          imagePath: widget.iconUrl),
      if (widget.badgeScore != null)
        Positioned(
            top: 12,
            right: 16,
            child: Container(
              height: 20,
              width: 45,
              decoration: BoxDecoration(
                  color: _isClicked ? Colors.black : Colors.white,
                  border: Border.all(
                      color: _isClicked ? Colors.white : Colors.black,
                      width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(104),
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                  borderRadius: BorderRadius.circular(20)),
              child: Center(
                child: Text(
                  "${widget.badgeScore}/10",
                  style: AppStyles.textStyle_12_600.copyWith(
                    color: _isClicked ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ))
    ]);
  }
}
