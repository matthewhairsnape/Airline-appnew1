import 'package:airline_app/screen/leaderboard/widgets/airport_list.dart';
import 'package:airline_app/utils/app_localizations.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';

class AirlineAirportListWidget extends StatelessWidget {
  const AirlineAirportListWidget({
    super.key,
    required this.leaderBoardList,
    required this.expandedItems,
    required this.onExpand,
  });

  final int expandedItems;
  final List<Map<String, dynamic>> leaderBoardList;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return leaderBoardList.isEmpty
        ? Padding(
            padding: const EdgeInsets.only(top: 15),
            child: Center(
              child: Text(
                'Nothing to show here',
                style: AppStyles.textStyle_14_600,
              ),
            ),
          )
        : Column(
            children: [
              Column(
                children: leaderBoardList.asMap().entries.map<Widget>((entry) {
                  int index = entry.key;
                  Map<String, dynamic> singleAirport = entry.value;
                  if (index < expandedItems) {
                    return AirportList(
                      airportData: {
                        ...singleAirport,
                        'rank': index + 1,
                        'index': index,
                      },
                      rank: index + 1,
                    );
                  }
                  return const SizedBox.shrink();
                }).toList(),
              ),
              SizedBox(height: 19),
              if (expandedItems < leaderBoardList.length)
                Center(
                  child: GestureDetector(
                    onTap: onExpand,
                    child: IntrinsicWidth(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                              AppLocalizations.of(context)
                                  .translate('Expand more'),
                              style: AppStyles.textStyle_18_600
                                  .copyWith(fontSize: 15)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_downward),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
  }
}
