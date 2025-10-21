import 'package:airline_app/provider/aviation_info_provider.dart';
import 'package:airline_app/provider/review_feedback_provider_for_airline.dart';
import 'package:airline_app/provider/review_feedback_provider_for_airport.dart';
import 'package:airline_app/screen/app_widgets/bottom_button_bar.dart';
import 'package:airline_app/screen/app_widgets/main_button.dart';
import 'package:airline_app/screen/reviewsubmission/review_airline/build_question_header_for_airline.dart';
import 'package:airline_app/screen/reviewsubmission/widgets/feedback_option_for_airline.dart';
import 'package:airline_app/utils/airport_list_json.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuestionFirstScreenForAirline extends ConsumerWidget {
  const QuestionFirstScreenForAirline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectionsForAirline = ref.watch(reviewFeedBackProviderForAirline);
    final List<Map<String, dynamic>> feedbackOptionsForAirline =
        mainCategoryAndSubcategoryForAirline;

    return PopScope(
      canPop: false, // Prevents the default pop action
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pushNamed(context, AppRoutes.reviewsubmissionscreen);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: MediaQuery.of(context).size.height * 0.34,
          automaticallyImplyLeading: false,
          flexibleSpace: BuildQuestionHeaderForAirline(
            title: "What did you like about your airline experience?",
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select positive aspects',
                    style: AppStyles.textStyle_18_600,
                  ),
                  // SizedBox(height: 2),
                  Divider(height: 1, color: Colors.grey.withAlpha(51)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: SingleChildScrollView(
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: feedbackOptionsForAirline.length,
                    itemBuilder: (context, index) => FeedbackOptionForAirline(
                      numForIdentifyOfParent: 1,
                      iconUrl: feedbackOptionsForAirline[index]['iconUrl'],
                      label: index,
                      selectedNumberOfSubcategory: selectionsForAirline[index]
                              ['subCategory']
                          .values
                          .where((s) => s == true)
                          .length,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomButtonBar(
            child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: MainButton(
                color: Colors.white,
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
            SizedBox(width: 10),
            Expanded(
              child: MainButton(
                color: Colors.white,
                text: "Next",
                onPressed: () {
                  Navigator.pushNamed(
                      context, AppRoutes.questionsecondscreenforairline);
                },
              ),
            ),
          ],
        )),
      ),
    );
  }
}
