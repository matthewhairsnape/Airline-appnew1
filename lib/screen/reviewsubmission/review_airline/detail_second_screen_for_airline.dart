import 'package:airline_app/provider/aviation_info_provider.dart';
import 'package:airline_app/provider/review_feedback_provider_for_airline.dart';
import 'package:airline_app/provider/review_feedback_provider_for_airport.dart';
import 'package:airline_app/screen/app_widgets/bottom_button_bar.dart';
import 'package:airline_app/screen/app_widgets/main_button.dart';
import 'package:airline_app/screen/reviewsubmission/review_airline/build_question_header_for_airline.dart';
import 'package:airline_app/screen/reviewsubmission/widgets/subcategory_button_widget.dart';
import 'package:airline_app/utils/airport_list_json.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DetailSecondScreenForAirline extends ConsumerWidget {
  const DetailSecondScreenForAirline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selections = ref.watch(reviewFeedBackProviderForAirline);
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final int singleIndex = args?['singleAspect'] ?? '';
    List<dynamic> mainCategoryNames = [];
    for (var category in mainCategoryAndSubcategoryForAirline) {
      mainCategoryNames.add(category['mainCategory'] as String);
    }
    final Map<String, dynamic> subCategoryList =
        mainCategoryAndSubcategoryForAirline[singleIndex]['subCategory'];

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: MediaQuery.of(context).size.height * 0.34,
        flexibleSpace: BuildQuestionHeaderForAirline(
          title: "What didn't you like about your airline experience?",
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${selections[singleIndex]['mainCategory']}",
                style: AppStyles.textStyle_18_600,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: subCategoryList.length,
              itemBuilder: (context, index) {
                Map<String, dynamic> items =
                    selections[singleIndex]['subCategory'];
                String imagePath = selections[singleIndex]['iconUrl'];
                List itemkeys = items.keys.toList();
                List itemValues = items.values.toList();
                String key = itemkeys[index];
                dynamic value = itemValues[index];
                return Opacity(
                  opacity: value == true ? 0.5 : 1,
                  child: SubcategoryButtonWidget(
                    labelName: itemkeys[index],
                    isSelected: value == false ? true : false,
                    onTap: () {
                      value == true
                          ? debugPrint("Value is false, no action performed.")
                          : ref
                              .read(reviewFeedBackProviderForAirline.notifier)
                              .selectDislike(singleIndex, key);
                    },
                    imagePath: imagePath,
                  ),
                );
              },
            ),
          ),
        ),
      ]),
      bottomNavigationBar: BottomButtonBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: MainButton(
                text: "Back",
                onPressed: () {
                  Navigator.pop(context);
                  // ref.read(aviationInfoProvider.notifier).resetState();
                  // ref
                  //     .read(reviewFeedBackProviderForAirline.notifier)
                  //     .resetState();
                  // ref
                  //     .read(reviewFeedBackProviderForAirport.notifier)
                  //     .resetState();
                },
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: MainButton(
                text: "Next",
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
