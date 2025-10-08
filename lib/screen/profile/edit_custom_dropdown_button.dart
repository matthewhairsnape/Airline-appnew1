import 'package:airline_app/utils/app_styles.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';

class EditCustomDropdownButton extends StatefulWidget {
  const EditCustomDropdownButton(
      {super.key,
      required this.labelText,
      required this.hintText,
      required this.onChanged,
      required this.airlineNames});

  final String labelText;
  final String hintText;
  final ValueChanged<String> onChanged;
  final List<dynamic> airlineNames;

  @override
  State<EditCustomDropdownButton> createState() =>
      _EditCustomDropdownButtonState();
}

class _EditCustomDropdownButtonState extends State<EditCustomDropdownButton> {
  final TextEditingController textEditingController = TextEditingController();
  String? selectedValue;

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.labelText, style: AppStyles.textStyle_16_600),
        const SizedBox(height: 8),
        DropdownButtonHideUnderline(
          child: DropdownButton2<String>(
            isExpanded: true,
            hint: Text('Select your favorite airline',
                style: AppStyles.textStyle_15_400
                    .copyWith(color: Color(0xFF38433E))),
            items: widget.airlineNames
                .map((item) => DropdownMenuItem<String>(
                      value: item['name'],
                      child: Text(
                        item['name'],
                        style: AppStyles.textStyle_14_600,
                      ),
                    ))
                .toList(),
            value: selectedValue,
            onChanged: (value) {              
              setState(() {
                selectedValue = value;
              });
              widget.onChanged(selectedValue ?? ""); // Call the callback
            },
            buttonStyleData: ButtonStyleData(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: AppStyles.cardDecoration,
              height: 48,
            ),
            dropdownStyleData: DropdownStyleData(
              maxHeight: 200,
              decoration: AppStyles.cardDecoration,
            ),
            menuItemStyleData: const MenuItemStyleData(height: 40),
            dropdownSearchData: DropdownSearchData(
              searchController: textEditingController,
              searchInnerWidgetHeight: 50,
              searchInnerWidget: Container(
                height: 50,
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                padding: const EdgeInsets.only(
                  top: 8,
                  bottom: 4,
                  right: 8,
                  left: 8,
                ),
                child: TextFormField(
                  expands: true,
                  maxLines: null,
                  controller: textEditingController,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    hintText: "Select your favorite airline",
                    hintStyle: AppStyles.textStyle_15_400
                        .copyWith(color: Color(0xFF38433E)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              searchMatchFn: (item, searchValue) {
                return item.value.toString().contains(searchValue);
              },
            ),
            onMenuStateChange: (isOpen) {
              if (!isOpen) {
                textEditingController.clear();
              }
            },
            iconStyleData: IconStyleData(icon: Icon(Icons.expand_more)),
          ),
        )
      ],
    );
  }
}
