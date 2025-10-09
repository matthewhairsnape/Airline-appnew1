import 'dart:async';
import 'package:airline_app/controller/boarding_pass_controller.dart';
import 'package:airline_app/controller/fetch_flight_info_by_cirium.dart';
import 'package:airline_app/models/boarding_pass.dart';
import 'package:airline_app/provider/user_data_provider.dart';
import 'package:airline_app/provider/flight_tracking_provider.dart';
import 'package:airline_app/services/supabase_service.dart';
import 'package:airline_app/screen/app_widgets/appbar_widget.dart';
import 'package:airline_app/screen/app_widgets/custom_snackbar.dart';
import 'package:airline_app/screen/app_widgets/loading.dart';
import 'package:airline_app/utils/app_localizations.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../widgets/flight_confirmation_dialog.dart';
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
      String pnr = '';
      String departureAirport = '';
      String arrivalAirport = '';
      String carrier = '';
      String flightNumber = '';
      String seatNumber = '';
      String classOfService = 'Economy';
      DateTime date = DateTime.now();

      // Check if it's BCBP format (starts with M1 or M2)
      if (rawValue.startsWith('M1') || rawValue.startsWith('M2')) {
        debugPrint("✅ Detected BCBP format");
        
        // BCBP Format parsing
        // M1HAIRSNAPE/MATTHEWM          CTABEGJU 439  244 12A 0209  00
        // M1 = Format code
        // HAIRSNAPE/MATTHEWM = Passenger name
        // CTA = Origin airport
        // BEG = Destination airport
        // JU = Operating carrier
        // 439 = Flight number
        // 244 = Julian date
        // 12A = Seat number
        // 0209 = Sequence number
        // etc.
        
        int pos = 2; // Skip M1
        
        // Extract passenger name (variable length, padded with spaces)
        int nameEnd = pos + 20;
        if (nameEnd > rawValue.length) nameEnd = rawValue.length;
        // Skip name for now
        pos = nameEnd;
        
        // Extract data after name
        String remainingData = rawValue.substring(pos).trim();
        
        // Parse the key fields
        // Format: XXXYYYZZ NNNN DDD SSS CCCC
        // XXX = Departure airport (3 chars)
        // YYY = Arrival airport (3 chars)
        // ZZ = Carrier code (2 chars)
        // NNNN = Flight number (variable, up to 5 chars with spaces)
        // DDD = Julian date (3 digits)
        // SSS = Seat number (3 chars)
        
        if (remainingData.length >= 8) {
          departureAirport = remainingData.substring(0, 3);
          arrivalAirport = remainingData.substring(3, 6);
          carrier = remainingData.substring(6, 8);
          
          // Find flight number and date
          String afterCarrier = remainingData.substring(8).trim();
          List<String> parts = afterCarrier.split(RegExp(r'\s+'));
          
          if (parts.isNotEmpty) {
            flightNumber = parts[0]; // Flight number
          }
          if (parts.length > 1) {
            String julianDate = parts[1]; // Julian date
            if (julianDate.length >= 3) {
              final baseDate = DateTime(DateTime.now().year, 1, 0);
              date = baseDate.add(Duration(days: int.parse(julianDate.substring(0, 3))));
            }
          }
          if (parts.length > 2) {
            seatNumber = parts[2]; // Seat number
          }
          
          // Use PNR from the last part of passenger name or generate from flight info
          pnr = '${carrier}${flightNumber}${departureAirport}'.substring(0, 6);
          
          debugPrint("✅ Parsed BCBP boarding pass:");
          debugPrint("  Departure: $departureAirport");
          debugPrint("  Arrival: $arrivalAirport");
          debugPrint("  Carrier: $carrier");
          debugPrint("  Flight: $flightNumber");
          debugPrint("  Date: $date");
          debugPrint("  Seat: $seatNumber");
        }
      } else {
        // Try old format parsing
        final regex = RegExp(
            r'([A-Z0-9]{5,7})\s+([A-Z]{6}[A-Z0-9]{2})\s+(\d{4})\s+(\d{3}[A-Z])');
        final match = regex.firstMatch(rawValue);

        if (match == null) {
          debugPrint("❌ Invalid barcode format. Raw value: $rawValue");
          if (mounted) {
            CustomSnackBar.error(context,
                'Unable to read boarding pass. Please ensure it\'s a valid IATA barcode.');
            Navigator.pop(context);
          }
          return;
        }

        pnr = match.group(1)!;
        final routeOfFlight = match.group(2)!;
        departureAirport = routeOfFlight.substring(0, 3);
        carrier = routeOfFlight.substring(6, 8);
        flightNumber = match.group(3)!;
        final julianDateAndClassOfService = match.group(4)!;
        final julianDate = julianDateAndClassOfService.substring(0, 3);
        final classOfServiceKey = julianDateAndClassOfService.substring(3, 4);
        classOfService = _getClassOfService(classOfServiceKey);
        final baseDate = DateTime(DateTime.now().year, 1, 0);
        date = baseDate.add(Duration(days: int.parse(julianDate)));

        debugPrint("✅ Scanned boarding pass details:");
        debugPrint("  PNR: $pnr");
        debugPrint("  Carrier: $carrier");
        debugPrint("  Flight Number: $flightNumber");
        debugPrint("  Departure Airport: $departureAirport");
        debugPrint("  Date: $date");
        debugPrint("  Class: $classOfService");
      }

      final pnrExists = await _boardingPassController.checkPnrExists(pnr);
      if (pnrExists) {
        if (mounted) {
          CustomSnackBar.info(
              context, 'Boarding pass has already been reviewed');
          Navigator.pop(context);
        }
      }

      debugPrint("🔍 Fetching flight info from Cirium for date: $date");
      
      // Try the scanned date first
      Map<String, dynamic> flightInfo = await _fetchFlightInfo.fetchFlightInfo(
        carrier: carrier,
        flightNumber: flightNumber,
        flightDate: date,
        departureAirport: departureAirport,
      );

      debugPrint("📦 Cirium response: ${flightInfo.toString().substring(0, 200)}...");

      // Check if flight data was found
      if (flightInfo['flightStatuses']?.isEmpty ?? true) {
        debugPrint("❌ No flight found in Cirium");
        if (mounted) {
          CustomSnackBar.error(context,
              'Unable to find flight information. Please ensure the boarding pass is valid.');
          Navigator.pop(context);
        }
        return;
      }
      
      debugPrint("✅ Found flight data with ${flightInfo['flightStatuses'].length} status(es)");

      await _processFetchedFlightInfo(flightInfo, pnr, classOfService, carrier, flightNumber, date, departureAirport, seatNumber);
    } catch (e, stackTrace) {
      debugPrint("❌ Error processing boarding pass: $e");
      debugPrint("Stack trace: $stackTrace");
      if (mounted) {
        CustomSnackBar.error(context,
            'Unable to process boarding pass: ${e.toString()}');
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
      String departureAirportCode,
      String seatNumber) async {
    if (flightInfo['flightStatuses']?.isEmpty ?? true) {
      CustomSnackBar.error(
          context, 'No flight data found for the boarding pass');
      Navigator.pushNamed(context, AppRoutes.reviewsubmissionscreen);
      return;
    }

    final flightStatus = flightInfo['flightStatuses'][0];
    final airlines = flightInfo['appendix']['airlines'] ?? [];
    final airports = flightInfo['appendix']['airports'] ?? [];
    
    final airlineName = airlines.firstWhere(
      (airline) => airline['fs'] == flightStatus['primaryCarrierFsCode'],
      orElse: () => {'name': 'Unknown Airline'},
    )['name'] ?? 'Unknown Airline';

    final departureAirport = airports.firstWhere(
      (airport) => airport['fs'] == flightStatus['departureAirportFsCode'],
      orElse: () => {'fs': '', 'city': '', 'countryCode': ''},
    );
    final arrivalAirport = airports.firstWhere(
      (airport) => airport['fs'] == flightStatus['arrivalAirportFsCode'],
      orElse: () => {'fs': '', 'city': '', 'countryCode': ''},
    );

    final departureEntireTime =
        DateTime.parse(flightStatus['departureDate']['dateLocal']);
    final arrivalEntireTime =
        DateTime.parse(flightStatus['arrivalDate']['dateLocal']);

    final userId = ref.read(userDataProvider)?['userData']?['_id'] ?? '';

    final newPass = BoardingPass(
      name: userId.toString(),
      pnr: pnr,
      airlineName: airlineName.toString(),
      departureAirportCode: (departureAirport['fs'] ?? '').toString(),
      departureCity: (departureAirport['city'] ?? '').toString(),
      departureCountryCode: (departureAirport['countryCode'] ?? '').toString(),
      departureTime: _formatTime(departureEntireTime),
      arrivalAirportCode: (arrivalAirport['fs'] ?? '').toString(),
      arrivalCity: (arrivalAirport['city'] ?? '').toString(),
      arrivalCountryCode: (arrivalAirport['countryCode'] ?? '').toString(),
      arrivalTime: _formatTime(arrivalEntireTime),
      classOfTravel: classOfService,
      airlineCode: (flightStatus['carrierFsCode'] ?? '').toString(),
      flightNumber:
          "${flightStatus['carrierFsCode'] ?? ''} ${flightStatus['flightNumber'] ?? ''}",
      visitStatus: getVisitStatus(departureEntireTime),
    );

    final result = await _boardingPassController.saveBoardingPass(newPass);
    
    // Save to Supabase if initialized
    if (SupabaseService.isInitialized) {
      final userId = ref.read(userDataProvider)?['userData']?['_id'] ?? '';
      await SupabaseService.createJourney(
        userId: userId.toString(),
        pnr: pnr,
        carrier: carrier,
        flightNumber: flightNumber,
        departureAirport: departureAirportCode,
        arrivalAirport: arrivalAirport['fs'].toString(),
        scheduledDeparture: departureEntireTime,
        scheduledArrival: arrivalEntireTime,
        seatNumber: seatNumber.isNotEmpty ? seatNumber : null,
        classOfTravel: classOfService,
        terminal: flightStatus['airportResources']?['departureTerminal'],
        gate: flightStatus['airportResources']?['departureGate'],
        aircraftType: flightStatus['flightEquipment']?['iata'],
      );
      debugPrint('✅ Journey saved to Supabase');
    }
    
    // Start real-time flight tracking with Cirium regardless of save result
    debugPrint('🪑 Seat number from boarding pass: $seatNumber');
    final trackingStarted = await ref.read(flightTrackingProvider.notifier).trackFlight(
      carrier: carrier,
      flightNumber: flightNumber,
      flightDate: date,
      departureAirport: departureAirportCode,
      pnr: pnr,
      existingFlightData: flightInfo,
    );

    if (trackingStarted) {
      debugPrint('✈️ Flight tracking started successfully for $pnr');
      debugPrint('📡 Real-time monitoring active - will notify at each flight phase');
    } else {
      debugPrint('⚠️ Flight tracking failed');
    }

    if (mounted) {
      if (result) {
        CustomSnackBar.success(context, '✅ Boarding pass scanned! Your flight is now being tracked.');
      } else {
        debugPrint('⚠️ Boarding pass save failed, but continuing with tracking');
        CustomSnackBar.success(context, '✅ Flight loaded! Your journey is being tracked.');
      }
      
      // Show confirmation dialog with flight details
      FlightConfirmationDialog.show(
        context,
        newPass,
        onCancel: () {
          // User cancelled, stay on current screen
        },
      );
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
