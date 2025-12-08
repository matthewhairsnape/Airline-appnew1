import 'package:airline_app/controller/boarding_pass_controller.dart';
import 'package:airline_app/models/boarding_pass.dart';
import 'package:airline_app/provider/aviation_info_provider.dart';
import 'package:airline_app/screen/reviewsubmission/widgets/build_country_flag.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:country_codes/country_codes.dart';

class ReviewFlightCard extends ConsumerStatefulWidget {
  const ReviewFlightCard({
    super.key,
    required this.index,
    required this.singleBoardingPass,
    required this.isReviewed,
  });

  final int index;
  final BoardingPass singleBoardingPass;
  final bool isReviewed;

  @override
  ConsumerState<ReviewFlightCard> createState() => _ReviewFlightCardState();
}

class _ReviewFlightCardState extends ConsumerState<ReviewFlightCard> {
  final BoardingPassController _boardingPassController =
      BoardingPassController();

  Future<void> _handleFlightCardTap() async {
    try {
      final response = await _boardingPassController.getBoardingPassDetails(
        widget.singleBoardingPass.airlineCode,
        widget.singleBoardingPass.departureAirportCode,
        widget.singleBoardingPass.arrivalAirportCode,
      );

      final aviationInfoNotifier = ref.read(aviationInfoProvider.notifier);
      aviationInfoNotifier
        ..updateAirlineData(response["airline"])
        ..updateDepartureData(response["departure"])
        ..updateArrivalData(response["arrival"])
        ..updateClassOfTravel(widget.singleBoardingPass.classOfTravel)
        ..updateIndex(widget.index);

      if (!mounted) return;
      _showReviewOptions();
    } catch (e) {
      debugPrint('Error handling flight card tap: $e');
    }
  }

  void _showReviewOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'What would you like to review?',
                  style: AppStyles.textStyle_18_600,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                _buildReviewOption(
                  icon: Icons.flight_takeoff,
                  label: 'Pre-Flight (Airport) Experience',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                        context, AppRoutes.questionfirstscreenforairport);
                  },
                ),
                const SizedBox(height: 10),
                _buildReviewOption(
                  icon: Icons.airplanemode_active,
                  label: 'In-Flight Experience',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                        context, AppRoutes.questionfirstscreenforairline);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: AppStyles.textStyle_14_600.copyWith(color: Colors.white)),
      onPressed: onTap,
    );
  }

  Widget _buildStatusContainer(String text) {
    return IntrinsicWidth(
      child: Container(
        height: 24,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Center(
            child: Text(
              text,
              style: AppStyles.textStyle_14_500.copyWith(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final BoardingPass pass = widget.singleBoardingPass;
    CountryDetails? departureCountry;
    CountryDetails? arrivalCountry;

    try {
      departureCountry =
          CountryCodes.detailsFromAlpha2(pass.departureCountryCode);
      arrivalCountry = CountryCodes.detailsFromAlpha2(pass.arrivalCountryCode);
    } catch (e) {
      return const SizedBox.shrink();
    }

    return Opacity(
      opacity: widget.isReviewed ? 0.5 : 1.0,
      child: Container(
        decoration: AppStyles.cardDecoration,
        child: InkWell(
          onTap: widget.isReviewed ? null : _handleFlightCardTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        buildCountryFlag(pass.departureCountryCode),
                        const SizedBox(width: 4),
                        Text(
                          "${_truncateText(departureCountry.name, 11)}, ${pass.departureTime}",
                          style: AppStyles.textStyle_14_600,
                        )
                      ],
                    ),
                    Row(
                      children: [
                        if (pass.arrivalCountryCode.isNotEmpty)
                          buildCountryFlag(pass.arrivalCountryCode),
                        const SizedBox(width: 4),
                        Text(
                          "${_truncateText(arrivalCountry.name, 11)}, ${pass.arrivalTime}",
                          style: AppStyles.textStyle_14_600,
                        )
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        "${_truncateText(pass.departureCity, 12)} (${pass.departureAirportCode}) -> ${_truncateText(pass.arrivalCity, 12)} (${pass.arrivalAirportCode})",
                        style: AppStyles.textStyle_16_600
                            .copyWith(color: Colors.black),
                        overflow: TextOverflow.visible,
                        softWrap: true,
                        maxLines: 2,
                      ),
                    ),
                    const Icon(Icons.arrow_forward)
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Class : ${pass.classOfTravel}",
                            style: AppStyles.textStyle_14_500),
                        Text("Flight Number : ${pass.flightNumber}",
                            style: AppStyles.textStyle_14_500),
                      ],
                    ),
                    Text(pass.airlineName, style: AppStyles.textStyle_14_500),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusContainer(pass.visitStatus),
                    if (widget.isReviewed) _buildStatusContainer("Reviewed"),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _truncateText(String? text, int maxLength) {
    if (text == null) return 'Unknown';
    return text.length > maxLength ? '${text.substring(0, maxLength)}..' : text;
  }
}
