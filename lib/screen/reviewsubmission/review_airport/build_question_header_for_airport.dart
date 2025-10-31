import 'package:airline_app/provider/aviation_info_provider.dart';
import 'package:airline_app/screen/reviewsubmission/widgets/progress_widget.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BuildQuestionHeaderForAirport extends ConsumerWidget {
  const BuildQuestionHeaderForAirport({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardingPassDetail = ref.watch(aviationInfoProvider);
    final String airportName = boardingPassDetail.departureData["name"] ?? "";
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            "assets/images/airport.png",
            fit: BoxFit.cover,
          ),
        ),
        Container(
          color: Colors.black.withAlpha(50),
        ),
        Padding(
          padding:
              EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 5),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white24,
                        width: 2,
                      ),
                      color: Colors.black.withAlpha(128),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                    margin: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Text(
                          airportName,
                          style: AppStyles.italicTextStyle.copyWith(
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 3.0,
                                color: Colors.black.withAlpha(128),
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 22),
                        Text(
                          title,
                          style: AppStyles.textStyle_18_600.copyWith(
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 2.0,
                                color: Colors.black.withAlpha(127),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Spacer(),
              ProgressWidget(
                parent: 0,
              ),
              SizedBox(
                height: 5,
              ),
              Container(
                height: 24,
                width: double.infinity,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                        topRight: Radius.circular(24),
                        topLeft: Radius.circular(24))),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
