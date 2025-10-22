import 'package:airline_app/screen/app_widgets/appbar_widget.dart';
import 'package:airline_app/screen/profile/utils/about_app.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:airline_app/utils/app_localizations.dart';

class AboutApp extends StatelessWidget {
  const AboutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppbarWidget(
        title: AppLocalizations.of(context).translate("About App"),
        onBackPressed: () => Navigator.pop(context),
      ),
      body: ListView(
        // crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 24,
          ),
          ...aboutAppList.map((value) {
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
