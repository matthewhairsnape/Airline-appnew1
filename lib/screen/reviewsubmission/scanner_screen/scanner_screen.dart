import 'dart:async';
import 'package:airline_app/controller/boarding_pass_controller.dart';
import 'package:airline_app/controller/fetch_flight_info_by_cirium.dart';
import 'package:airline_app/models/boarding_pass.dart';
import 'package:airline_app/provider/user_data_provider.dart';
import 'package:airline_app/provider/flight_tracking_provider.dart';
import 'package:airline_app/screen/app_widgets/appbar_widget.dart';
import 'package:airline_app/screen/app_widgets/custom_snackbar.dart';
import 'package:airline_app/screen/app_widgets/loading.dart';
import 'package:airline_app/utils/app_localizations.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'scanner_button_widgets.dart';
import 'scanner_error_widget.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController controller = MobileScannerController(
    autoStart: false,
    torchEnabled: false,
  );
  final FetchFlightInforByCirium _fetchFlightInfo = FetchFlightInforByCirium();
  final BoardingPassController _boardingPassController =
      BoardingPassController();

  Barcode? _barcode;
  StreamSubscription<Object?>? _subscription;
  Map<String, dynamic>? detailedBoardingPass;
  bool isLoading = false;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = controller.barcodes.listen(_handleBarcode);
    unawaited(controller.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!controller.value.hasCameraPermission) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _subscription = controller.barcodes.listen(_handleBarcode);
        unawaited(controller.start());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_subscription?.cancel());
        _subscription = null;
        unawaited(controller.stop());
        break;
      default:
        break;
    }
  }

  void _handleBarcode(BarcodeCapture barcodes) {
    if (mounted && !isProcessing) {
      setState(() {
        _barcode = barcodes.barcodes.firstOrNull;
      });
      if (_barcode?.rawValue != null) {
        isProcessing = true;
        controller.stop();
        parseIataBarcode(_barcode!.rawValue!);
      }
    }
  }

  String getVisitStatus(DateTime departureEntireTime) {
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

  Future<void> parseIataBarcode(String rawValue) async {
    setState(() => isLoading = true);
    debugPrint("rawValue 🎎 =====================> $rawValue");
    try {
      final regex = RegExp(
          r'([A-Z0-9]{5,7})\s+([A-Z]{6}[A-Z0-9]{2})\s+(\d{4})\s+(\d{3}[A-Z])');
      final match = regex.firstMatch(rawValue);

      if (match == null) {
        throw Exception('Invalid barcode format');
      }

      final pnr = match.group(1)!;
      final routeOfFlight = match.group(2)!;
      final departureAirport = routeOfFlight.substring(0, 3);
      final carrier = routeOfFlight.substring(6, 8);
      final flightNumber = match.group(3)!;
      final julianDateAndClassOfService = match.group(4)!;
      final julianDate = julianDateAndClassOfService.substring(0, 3);
      final classOfServiceKey = julianDateAndClassOfService.substring(3, 4);
      final classOfService = _getClassOfService(classOfServiceKey);
      final baseDate = DateTime(DateTime.now().year, 1, 0);
      final date = baseDate.add(Duration(days: int.parse(julianDate)));

      debugPrint("This is scanned date ✨ ============ > $date");

      final pnrExists = await _boardingPassController.checkPnrExists(pnr);
      if (pnrExists) {
        if (mounted) {
          CustomSnackBar.info(
              context, 'Boarding pass has already been reviewed');
          Navigator.pop(context);
        }
      }

      Map<String, dynamic> flightInfo = await _fetchFlightInfo.fetchFlightInfo(
        carrier: carrier,
        flightNumber: flightNumber,
        flightDate: date,
        departureAirport: departureAirport,
      );

      if (flightInfo['flightStatuses']?.isEmpty ?? true) {
        final DateTime lastYearDate =
            DateTime(date.year - 1, date.month, date.day);
        flightInfo = await _fetchFlightInfo.fetchFlightInfo(
          carrier: carrier,
          flightNumber: flightNumber,
          flightDate: lastYearDate,
          departureAirport: departureAirport,
        );

        if (flightInfo['flightStatuses']?.isEmpty ?? true) {
          if (mounted) {
            CustomSnackBar.error(context,
                'Oops! We had trouble processing your boarding pass. Please try again.');
            Navigator.pop(context);
          }
        }
      }

      await _processFetchedFlightInfo(flightInfo, pnr, classOfService, carrier, flightNumber, date, departureAirport);
    } catch (e) {
      if (mounted) {
        CustomSnackBar.error(context,
            'Unable to process boarding pass. Please try scanning again.');
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isProcessing = false;
        });
      }
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

  Future<void> _processFetchedFlightInfo(
      Map<String, dynamic> flightInfo,
      String pnr,
      String classOfService,
      String carrier,
      String flightNumber,
      DateTime date,
      String departureAirportCode) async {
    if (flightInfo['flightStatuses']?.isEmpty ?? true) {
      CustomSnackBar.error(
          context, 'No flight data found for the boarding pass');
      Navigator.pushNamed(context, AppRoutes.reviewsubmissionscreen);
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
      visitStatus: getVisitStatus(departureEntireTime),
    );

    final result = await _boardingPassController.saveBoardingPass(newPass);
    if (result) {
      // Start real-time flight tracking with Cirium
      final trackingStarted = await ref.read(flightTrackingProvider.notifier).trackFlight(
        carrier: carrier,
        flightNumber: flightNumber,
        flightDate: date,
        departureAirport: departureAirportCode,
        pnr: pnr,
      );

      if (trackingStarted) {
        debugPrint('✈️ Flight tracking started successfully for $pnr');
        debugPrint('📡 Real-time monitoring active - will notify at each flight phase');
      } else {
        debugPrint('⚠️ Flight tracking failed but boarding pass saved');
      }

      if (mounted) {
        Navigator.pushNamed(context, AppRoutes.reviewsubmissionscreen);
        CustomSnackBar.success(context, 'Flight verified and tracking started!');
      }
    }
  }

  String _formatTime(DateTime time) =>
      "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

  Widget _buildBarcode(Barcode? value) {
    if (value == null) {
      return Text(
        'Scan a boarding pass!',
        overflow: TextOverflow.fade,
        style: AppStyles.textStyle_15_500.copyWith(color: Colors.white),
      );
    }
    return Text(
      'Scanned: ${value.format}',
      overflow: TextOverflow.fade,
      style: AppStyles.textStyle_15_500.copyWith(color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppbarWidget(
            title:
                AppLocalizations.of(context).translate('Boarding Pass Scanner'),
            onBackPressed: () => Navigator.pop(context),
          ),
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              MobileScanner(
                controller: controller,
                errorBuilder: (context, error) =>
                    ScannerErrorWidget(error: error),
                fit: BoxFit.contain,
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  alignment: Alignment.bottomCenter,
                  height: 150,
                  color: Colors.black.withAlpha(100),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(child: Center(child: _buildBarcode(_barcode))),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ToggleFlashlightButton(controller: controller),
                          StartStopMobileScannerButton(controller: controller),
                          SwitchCameraButton(controller: controller),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isLoading) const LoadingWidget(),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _subscription = null;
    controller.dispose();
    super.dispose();
  }
}
