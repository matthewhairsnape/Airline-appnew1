import 'dart:io';
import 'package:airline_app/provider/user_data_provider.dart';
import 'package:airline_app/screen/app_widgets/appbar_widget.dart';
import 'package:airline_app/screen/app_widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:airline_app/controller/boarding_pass_controller.dart';
import 'package:airline_app/controller/fetch_flight_info_by_cirium.dart';
import 'package:airline_app/models/boarding_pass.dart';
import 'package:airline_app/screen/app_widgets/loading.dart';
import 'package:airline_app/screen/app_widgets/main_button.dart';
import 'package:airline_app/utils/app_localizations.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';

class WalletSyncScreen extends ConsumerStatefulWidget {
  const WalletSyncScreen({super.key});

  @override
  ConsumerState<WalletSyncScreen> createState() => _WalletSyncScreenState();
}

class _WalletSyncScreenState extends ConsumerState<WalletSyncScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final FetchFlightInforByCirium _flightInfoFetcher =
      FetchFlightInforByCirium();
  final BoardingPassController _boardingPassController =
      BoardingPassController();
  final ImagePicker _imagePicker = ImagePicker();

  Map<String, dynamic>? detailedBoardingPass;
  bool isLoading = false;

  Future<void> _analyzeImageFromFile() async {
    setState(() => isLoading = true);
    try {
      final XFile? file =
          await _imagePicker.pickImage(source: ImageSource.gallery);
      if (file == null) return;

      final BarcodeCapture? barcodeCapture =
          await _controller.analyzeImage(file.path);
      final String? rawValue = barcodeCapture?.barcodes.firstOrNull?.rawValue;
      debugPrint("This is scanned barcode ========================> $rawValue");
      if (rawValue != null) {
        await parseIataBarcode(rawValue);
      } else {
        if (mounted) {
          CustomSnackBar.error(context,
              "This boarding pass cannot be scanned due to poor quality.");
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.info(context,
            'Unable to scan the boarding pass. Please try again with a clearer image.');
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> parseIataBarcode(String rawValue) async {
    setState(() => isLoading = true);
    try {
      debugPrint("This is scanned barcode ========================> $rawValue");

      final RegExp regex = RegExp(
          r'([A-Z0-9]{5,7})\s+([A-Z]{6}[A-Z0-9]{2})\s+(\d{4})\s+(\d{3}[A-Z])');
      final Match? match = regex.firstMatch(rawValue);

      if (match == null) {
        throw Exception('Invalid barcode format');
      }

      final String pnr = match.group(1)!;
      final String routeOfFlight = match.group(2)!;
      final String flightNumber = match.group(3)!;
      final String julianDateAndClassOfService = match.group(4)!;
      final String departureAirport = routeOfFlight.substring(0, 3);
      final String carrier = routeOfFlight.substring(6, 8);
      final String julianDate = julianDateAndClassOfService.substring(0, 3);
      final String classOfServiceKey =
          julianDateAndClassOfService.substring(3, 4);
      final String classOfService = _getClassOfService(classOfServiceKey);
      final DateTime baseDate = DateTime(DateTime.now().year, 1, 0);
      final DateTime date = baseDate.add(Duration(days: int.parse(julianDate)));

      final bool pnrExists = await _boardingPassController.checkPnrExists(pnr);
      if (pnrExists) {
        if (mounted) {
          CustomSnackBar.info(
              context, "Boading pass has already been reviewed.");
        }
        return;
      }

      Map<String, dynamic> flightInfo =
          await _flightInfoFetcher.fetchFlightInfo(
        carrier: carrier,
        flightNumber: flightNumber,
        flightDate: date,
        departureAirport: departureAirport,
      );

      if (flightInfo['flightStatuses']?.isEmpty ?? true) {
        final DateTime lastYearDate =
            DateTime(date.year - 1, date.month, date.day);
        flightInfo = await _flightInfoFetcher.fetchFlightInfo(
          carrier: carrier,
          flightNumber: flightNumber,
          flightDate: lastYearDate,
          departureAirport: departureAirport,
        );

        if (flightInfo['flightStatuses']?.isEmpty ?? true) {
          if (mounted) {
            CustomSnackBar.info(context,
                "Flight data is only available for up to one year in the past.");
          }
          return;
        }
      }

      await _processFetchedFlightInfo(flightInfo, pnr, classOfService);
    } catch (e) {
      if (mounted) {
        CustomSnackBar.info(context,
            "Oops! We had trouble processing your boarding pass. Please try again.");
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  String _getClassOfService(String key) {
    switch (key) {
      case "F":
        return "First";
      case "R":
        return "Premium Economy";
      case "J":
        return "Business";
      case "Y":
        return "Economy";
      default:
        return "Premium Economy";
    }
  }

  Future<void> _processFetchedFlightInfo(Map<String, dynamic> flightInfo,
      String pnr, String classOfService) async {
    if (flightInfo['flightStatuses']?.isEmpty ?? true) {
      CustomSnackBar.error(
          context, "No flight data found for the boarding pass.");

      return;
    }
    final flightStatus = flightInfo['flightStatuses'][0];
    final airlines = flightInfo['appendix']['airlines'];
    final airports = flightInfo['appendix']['airports'];
    final airlineName = airlines.firstWhere((airline) =>
        airline['fs'] == flightStatus['primaryCarrierFsCode'])['name'];
    final departureAirport = airports.firstWhere(
        (airport) => airport['fs'] == flightStatus['departureAirportFsCode']);
    final arrivalAirport = airports.firstWhere(
        (airport) => airport['fs'] == flightStatus['arrivalAirportFsCode']);
    final departureEntireTime =
        DateTime.parse(flightStatus['departureDate']['dateLocal']);
    final arrivalEntireTime =
        DateTime.parse(flightStatus['arrivalDate']['dateLocal']);

    /// ref.read(userDataProvider)?['userData']['_id']
    final newPass = BoardingPass(
      name: ref.read(userDataProvider)?['userData']['_id'],
      pnr: pnr,
      airlineName: airlineName,
      departureAirportCode: departureAirport['fs'],
      departureCity: departureAirport['city'],
      departureCountryCode: departureAirport['countryCode'],
      departureTime: _formatTime(departureEntireTime),
      arrivalAirportCode: arrivalAirport['fs'],
      arrivalCity: arrivalAirport['city'],
      arrivalCountryCode: arrivalAirport['countryCode'],
      arrivalTime: _formatTime(arrivalEntireTime),
      classOfTravel: classOfService,
      airlineCode: flightStatus['carrierFsCode'],
      flightNumber:
          "${flightStatus['carrierFsCode']} ${flightStatus['flightNumber']}",
      visitStatus: _getVisitStatus(departureEntireTime),
    );

    final bool result = await _boardingPassController.saveBoardingPass(newPass);
    if (result) {
      if (mounted) {
        CustomSnackBar.success(context, 'Boarding pass from wallet loaded successfully!');
        Navigator.pushReplacementNamed(context, AppRoutes.myJourney);
      }
    }
  }

  String _formatTime(DateTime time) =>
      "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

  String _getVisitStatus(DateTime departureEntireTime) {
    final now = DateTime.now();
    final difference = now.difference(departureEntireTime);

    if (departureEntireTime.isAfter(now)) {
      return "Upcoming";
    } else if (difference.inDays <= 20) {
      return "Recent";
    } else {
      return "Earlier";
    }
  }

  Future<void> _launchWallet() async {
    if (kIsWeb) {
      throw 'Wallet launch is not supported on web platform';
    }

    final String url;
    final String fallbackUrl;

    if (Platform.isAndroid) {
      url = 'https://pay.google.com/gp/v/home';
      fallbackUrl =
          'https://play.google.com/store/apps/details?id=com.google.android.apps.walletnfcrel';
    } else if (Platform.isIOS) {
      url = 'shoebox://';
      fallbackUrl = 'https://apps.apple.com/us/app/wallet/id1160481993';
    } else {
      throw 'Unsupported platform for wallet launch';
    }

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else if (await canLaunchUrl(Uri.parse(fallbackUrl))) {
      await launchUrl(Uri.parse(fallbackUrl));
    } else {
      throw 'Could not launch wallet on ${Platform.operatingSystem}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppbarWidget(
            title: "Sync from Your Wallet",
            onBackPressed: () {
              Navigator.pop(context);
            },
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withAlpha(51),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.flight_takeoff,
                        size: 48,
                        color: AppStyles.mainColor,
                      ),
                      const SizedBox(height: 16),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: AppStyles.textStyle_16_600.copyWith(
                            height: 1.5,
                            color: Colors.black,
                          ),
                          children: [
                            const TextSpan(text: "Please click on "),
                            TextSpan(
                              text: "Upload Boarding Pass Screenshot",
                              style: TextStyle(color: Colors.green),
                            ),
                            const TextSpan(
                              text:
                                  " button to upload the screenshot of your boarding pass used during your travel.\n\n",
                            ),
                            const TextSpan(
                              text:
                                  "If you don't have a screenshot, simply click on ",
                            ),
                            TextSpan(
                              text: "Move To Wallet",
                              style: TextStyle(color: Colors.green),
                            ),
                            const TextSpan(
                              text: " button to retrieve it.\n\n",
                            ),
                            const TextSpan(
                              text: "Caution: ",
                              style: TextStyle(color: Colors.orange),
                            ),
                            const TextSpan(
                              text:
                                  "Ensure that the screenshot clearly displays the barcode of your boarding pass.",
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 1,
                color: Colors.grey.shade300,
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: Column(
                  children: [
                    MainButton(
                      text: AppLocalizations.of(context)
                          .translate('Upload Boarding Pass Screenshot'),
                      onPressed: _analyzeImageFromFile,
                      // color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    MainButton(
                      text: AppLocalizations.of(context)
                          .translate('Move To Wallet'),
                      onPressed: _launchWallet,
                      // color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (isLoading) const LoadingWidget()
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
