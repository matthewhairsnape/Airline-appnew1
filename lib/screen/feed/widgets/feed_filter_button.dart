import 'package:airline_app/utils/app_localizations.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';

class FeedFilterButton extends StatefulWidget {
  const FeedFilterButton({
    super.key,
    required this.text,
    required this.onSelectionChanged,
  });

  final String text;
  final Function(bool) onSelectionChanged;

  @override
  State<FeedFilterButton> createState() => _FeedFilterButtonState();
}

class _FeedFilterButtonState extends State<FeedFilterButton> {
  late bool _isSelected = false;
  @override
  void initState() {
    super.initState();
    // Initialize _isSelected based on the text
    _isSelected = widget.text == "All"; // Set to true if text is "All"
  }

  // final Color color;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isSelected = !_isSelected;
        });
        widget.onSelectionChanged(_isSelected);
      },
      child: Container(
        // Diameter of the circular avatar
        height: 48, // Diameter of the circular avatar
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: widget.text == "All"
              ? AppStyles.mainColor
              : (_isSelected
                  ? AppStyles.mainColor
                  : Colors.white), // Background color
          border: Border.all(width: 2, color: Colors.black), // Border color
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(2, 2))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            child: Text(
              AppLocalizations.of(context).translate(widget.text),
              style: AppStyles.textStyle_14_600,
            ),
          ),
        ),
      ),
    );
  }
}
