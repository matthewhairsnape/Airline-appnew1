import 'dart:async';
import 'package:airline_app/controller/boarding_pass_controller.dart';
import 'package:airline_app/controller/fetch_flight_info_by_cirium.dart';
import 'package:airline_app/models/boarding_pass.dart';
import 'package:airline_app/provider/user_data_provider.dart';
import 'package:airline_app/provider/flight_tracking_provider.dart';
import 'package:airline_app/provider/auth_provider.dart';
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
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: [
      BarcodeFormat.qrCode,
      BarcodeFormat.pdf417,
      BarcodeFormat.aztec,
      BarcodeFormat.dataMatrix,
    ],
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
        
        // Show what was scanned first
        debugPrint("📱 Scanned barcode:");
        debugPrint("  Type: ${_barcode!.format}");
        debugPrint("  Raw Value: ${_barcode!.rawValue}");
        debugPrint("  Display Value: ${_barcode!.displayValue ?? 'N/A'}");
        
        // Try to parse as boarding pass, but don't fail if it's not
        _tryParseBoardingPass(_barcode!.rawValue!);
      }
    }
  }

  void _tryParseBoardingPass(String rawValue) async {
    try {
      // Check if it looks like a boarding pass barcode
      bool isLikelyBoardingPass = rawValue.startsWith('M1') || 
                                 rawValue.startsWith('M2') ||
                                 rawValue.contains(RegExp(r'[A-Z]{3}[A-Z]{3}[A-Z]{2}')) ||
                                 rawValue.contains(RegExp(r'\d{3,4}[A-Z]\d{3}'));
      
      if (isLikelyBoardingPass) {
        debugPrint("✅ Attempting to parse as boarding pass");
        await parseIataBarcode(rawValue);
      } else {
        debugPrint("❌ Not a recognized boarding pass format");
        if (mounted) {
          // Show generic barcode info
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Barcode Scanned'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Type: ${_barcode?.format ?? 'Unknown'}'),
                  SizedBox(height: 8),
                  Text('Value: ${_barcode?.rawValue ?? 'N/A'}'),
                  SizedBox(height: 8),
                  Text('This doesn\'t appear to be a boarding pass barcode.'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _restartScanner();
                  },
                  child: Text('Scan Again'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Error in barcode parsing: $e");
      if (mounted) {
        CustomSnackBar.error(context, 'Error processing barcode: ${e.toString()}');
        _restartScanner();
      }
    }
  }

  void _restartScanner() {
    setState(() {
      isProcessing = false;
      _barcode = null;
    });
    controller.start();
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
        
        // Parse BCBP using universal algorithm that works for ALL airlines
        Map<String, String> parsedData = _parseBCBPUniversal(rawValue);
        
        departureAirport = parsedData['departureAirport'] ?? '';
        arrivalAirport = parsedData['arrivalAirport'] ?? '';
        carrier = parsedData['carrier'] ?? '';
        flightNumber = parsedData['flightNumber'] ?? '';
        seatNumber = parsedData['seatNumber'] ?? '';
        classOfService = parsedData['classOfService'] ?? 'Economy';
        pnr = parsedData['pnr'] ?? '';
        
        // Parse Julian date if available with year rollover handling
        if (parsedData['julianDate'] != null && parsedData['julianDate']!.isNotEmpty) {
          try {
            int julian = int.parse(parsedData['julianDate']!);
            int currentJulian = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays + 1;
            int year = DateTime.now().year;
            
            // Handle year rollover for flights in next year
            if (julian < currentJulian - 300) {
              year += 1;
              debugPrint("🔄 Year rollover detected: Julian day $julian < current $currentJulian, using year $year");
            }
            
            final baseDate = DateTime(year, 1, 1);
            date = baseDate.add(Duration(days: julian - 1));
            
            debugPrint("📅 Julian date conversion: $julian → ${date.toIso8601String().split('T')[0]}");
          } catch (e) {
            debugPrint("Error parsing Julian date: $e");
            date = DateTime.now();
          }
        }
        
        debugPrint("✅ Parsed BCBP boarding pass:");
        debugPrint("  Departure: $departureAirport");
        debugPrint("  Arrival: $arrivalAirport");
        debugPrint("  Carrier: $carrier");
        debugPrint("  Flight: $flightNumber");
        debugPrint("  Date: $date");
        debugPrint("  Seat: $seatNumber");
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

      // Validate flight identifiers before Cirium lookup
      if (!_isValidFlightIdentifier(carrier, flightNumber)) {
        debugPrint("❌ Invalid flight identifier: carrier='$carrier', flight='$flightNumber'");
        if (mounted) {
          CustomSnackBar.error(context, 'Invalid flight data extracted from boarding pass');
          _restartScanner();
          return;
        }
      }
      
      debugPrint("➡️ Cirium lookup: ${carrier}${flightNumber} on ${date.toIso8601String().split('T')[0]} from $departureAirport");
      
      // Try the scanned date first
      Map<String, dynamic> flightInfo = await _fetchFlightInfo.fetchFlightInfo(
        carrier: carrier,
        flightNumber: flightNumber,
        flightDate: date,
        departureAirport: departureAirport,
      );

      String responseStr = flightInfo.toString();
      debugPrint("📦 Cirium response: ${responseStr.length > 200 ? responseStr.substring(0, 200) + '...' : responseStr}");

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
        _restartScanner();
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

  /// Universal BCBP parser following IATA Resolution 792 standard
  Map<String, String> _parseBCBPUniversal(String rawValue) {
    Map<String, String> result = {};
    
    try {
      debugPrint("🔍 Parsing BCBP (${rawValue.length} chars): ${rawValue.substring(0, rawValue.length > 50 ? 50 : rawValue.length)}...");
      
      // IATA Resolution 792 - Fixed field positions
      if (rawValue.length < 52) {
        debugPrint("❌ BCBP too short: ${rawValue.length} chars (need at least 52)");
        return result;
      }
      
      // Extract fields using exact IATA Resolution 792 offsets
      result['pnr'] = rawValue.substring(22, 29).trim();
      result['departureAirport'] = rawValue.substring(30, 33);
      result['arrivalAirport'] = rawValue.substring(33, 36);
      result['carrier'] = rawValue.substring(36, 38); // Use first 2 chars for IATA code
      result['flightNumber'] = rawValue.substring(39, 44).trim().replaceAll(RegExp(r'^0+'), '');
      result['julianDate'] = rawValue.substring(44, 47).trim();
      result['classOfService'] = rawValue.substring(47, 48);
      result['seatNumber'] = rawValue.length >= 52 ? rawValue.substring(48, 52).trim() : '';
      
      // Clean up seat number (remove zero padding)
      if (result['seatNumber'] != null && result['seatNumber']!.isNotEmpty) {
        String seat = result['seatNumber']!;
        // Remove leading zeros from seat number part
        RegExp seatRegex = RegExp(r'(\d+)([A-F])');
        Match? match = seatRegex.firstMatch(seat);
        if (match != null) {
          String seatNum = match.group(1)!.replaceAll(RegExp(r'^0+'), '');
          if (seatNum.isEmpty) seatNum = '1';
          result['seatNumber'] = '$seatNum${match.group(2)}';
        }
      }
      
      // Map class codes to readable names
      switch (result['classOfService']) {
        case 'F':
          result['classOfService'] = 'First';
          break;
        case 'J':
        case 'C':
          result['classOfService'] = 'Business';
          break;
        case 'Y':
        case 'W':
          result['classOfService'] = 'Economy';
          break;
        case 'R':
          result['classOfService'] = 'Premium Economy';
          break;
        default:
          result['classOfService'] = 'Economy';
      }
      
      debugPrint("✅ IATA Resolution 792 parsed:");
      debugPrint("  PNR: ${result['pnr']}");
      debugPrint("  Route: ${result['departureAirport']} → ${result['arrivalAirport']}");
      debugPrint("  Carrier: ${result['carrier']}");
      debugPrint("  Flight: ${result['flightNumber']}");
      debugPrint("  Julian Date: ${result['julianDate']}");
      debugPrint("  Class: ${result['classOfService']}");
      debugPrint("  Seat: ${result['seatNumber']}");
      
      return result;
      
    } catch (e) {
      debugPrint("❌ Error in BCBP parsing: $e");
      return result;
    }
  }


  /// Validate flight identifier before Cirium lookup
  bool _isValidFlightIdentifier(String carrier, String flightNumber) {
    final validCarrier = RegExp(r'^[A-Z0-9]{2}$');
    final validFlight = RegExp(r'^\d{1,4}$');
    return validCarrier.hasMatch(carrier) && validFlight.hasMatch(flightNumber);
  }

  /// Extract seat number and class from a part like "Y007A0039" -> seat: "7A", class: "Economy"
  bool _extractSeatFromPart(String part, Map<String, String> result) {
    try {
      // Pattern like F002A0026 or Y007A0039
      RegExp seatRegex = RegExp(r'([A-Z])(\d+)([A-F])(\d+)');
      Match? match = seatRegex.firstMatch(part);
      
      if (match != null) {
        String classCode = match.group(1)!; // F or Y
        String seatNum = match.group(2)!;   // 002 or 007
        String seatLetter = match.group(3)!; // A, B, C, etc.
        
        // Clean up seat number (remove leading zeros)
        String cleanSeatNum = seatNum.replaceAll(RegExp(r'^0+'), '');
        if (cleanSeatNum.isEmpty) cleanSeatNum = '1';
        
        result['seatNumber'] = '$cleanSeatNum$seatLetter';
        
        // Determine class
        switch (classCode) {
          case 'F':
            result['classOfService'] = 'First';
            break;
          case 'J':
          case 'C':
            result['classOfService'] = 'Business';
            break;
          case 'Y':
          default:
            result['classOfService'] = 'Economy';
            break;
        }
        
        return true;
      }
      
      // Try simpler pattern like "12A" or "7A"
      RegExp simpleSeatRegex = RegExp(r'(\d+)([A-F])');
      Match? simpleMatch = simpleSeatRegex.firstMatch(part);
      
      if (simpleMatch != null) {
        result['seatNumber'] = '${simpleMatch.group(1)}${simpleMatch.group(2)}';
        return true;
      }
      
    } catch (e) {
      debugPrint("Error extracting seat: $e");
    }
    return false;
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

    // Get user ID from auth provider
    final authState = ref.read(authProvider);
    final userId = authState.user.value?.id ?? '';

    if (userId.isEmpty) {
      debugPrint('❌ No authenticated user found for journey creation');
      if (mounted) {
        CustomSnackBar.error(context, 'Please log in to save your journey');
        Navigator.pop(context);
      }
      return;
    }

    final newPass = BoardingPass(
      name: userId,
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
        ciriumFlightData: flightInfo,
        seatNumber: seatNumber,
        terminal: flightStatus['airportResources']?['departureTerminal'],
        gate: flightStatus['airportResources']?['departureGate'],
        aircraftType: flightStatus['flightEquipment']?['iata'],
        scheduledDeparture: departureEntireTime,
        scheduledArrival: arrivalEntireTime,
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
                fit: BoxFit.cover,
                scanWindow: Rect.fromCenter(
                  center: MediaQuery.of(context).size.center(Offset.zero),
                  width: 250,
                  height: 250,
                ),
              ),
              // Scanning guide overlay
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      // Corner indicators
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.green, width: 4),
                              left: BorderSide(color: Colors.green, width: 4),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.green, width: 4),
                              right: BorderSide(color: Colors.green, width: 4),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.green, width: 4),
                              left: BorderSide(color: Colors.green, width: 4),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.green, width: 4),
                              right: BorderSide(color: Colors.green, width: 4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Instructions text
              Positioned(
                top: 100,
                left: 20,
                right: 20,
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Position QR code within the frame\nHold steady for best results',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
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
