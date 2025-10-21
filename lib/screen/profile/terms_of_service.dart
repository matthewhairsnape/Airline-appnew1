import 'package:airline_app/screen/app_widgets/appbar_widget.dart';
import 'package:airline_app/screen/profile/utils/terms_of_service_json.dart';
import 'package:airline_app/utils/app_localizations.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';

class TermsOfService extends StatelessWidget {
  const TermsOfService({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppbarWidget(
        title: AppLocalizations.of(context).translate('Terms of Service'),
        onBackPressed: () => Navigator.pop(context),
      ),
      body: ListView(
        // crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 24,
          ),
          ...termsOfServiceList.map((value) {
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(value['topic'], style: AppStyles.textStyle_16_600),
                  ],
                ),
              ),
              SizedBox(
                height: 12,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        value['contents'],
                        style: AppStyles.textStyle_14_400,
                        maxLines: null,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 12,
              ),
            ]);
          }),
        ],
      ),
    );
  }
}
