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
    if (!mounted || isProcessing) return;
    
    try {
      setState(() {
        _barcode = barcodes.barcodes.firstOrNull;
      });
      
      final rawValue = _barcode?.rawValue;
      if (rawValue == null || rawValue.isEmpty) {
        debugPrint("⚠️ Barcode has no value");
        return;
      }
      
      isProcessing = true;
      controller.stop();

      // Show what was scanned first
      debugPrint("📱 Scanned barcode:");
      debugPrint("  Type: ${_barcode!.format}");
      debugPrint("  Raw Value: $rawValue");
      debugPrint("  Display Value: ${_barcode!.displayValue ?? 'N/A'}");

      // Try to parse as boarding pass, but don't fail if it's not
      _tryParseBoardingPass(rawValue);
    } catch (e, stackTrace) {
      debugPrint("❌ Error in _handleBarcode: $e");
      debugPrint("Stack trace: $stackTrace");
      if (mounted) {
        setState(() => isProcessing = false);
        CustomSnackBar.error(context, 'Error scanning barcode. Please try again.');
        _restartScanner();
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
        CustomSnackBar.error(
            context, 'Error processing barcode: ${e.toString()}');
        _restartScanner();
      }
    }
  }

  void _restartScanner() {
    if (!mounted) return;
    setState(() {
      isProcessing = false;
      _barcode = null;
    });
    controller.start();
  }
  
  /// Safe substring helper to prevent index out of bounds crashes
  String _safeSubstring(String value, int start, [int? end]) {
    try {
      if (value.isEmpty || start < 0 || start >= value.length) {
        return '';
      }
      if (end == null) {
        return value.substring(start);
      }
      if (end > value.length) {
        end = value.length;
      }
      if (end <= start) {
        return '';
      }
      return value.substring(start, end);
    } catch (e) {
      debugPrint("❌ Error in _safeSubstring: $e (start: $start, end: $end, length: ${value.length})");
      return '';
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
    if (!mounted) return;
    
    setState(() => isLoading = true);
    debugPrint("rawValue 🎎 =====================> $rawValue");
    
    try {
      String pnr = '';
      String departureAirport = '';
      String carrier = '';
      String flightNumber = '';
      String seatNumber = '';
      String classOfService = 'Economy';
      DateTime date = DateTime.now();
      String arrivalAirport = '';

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
        if (parsedData['julianDate'] != null &&
            parsedData['julianDate']!.isNotEmpty) {
          try {
            int julian = int.parse(parsedData['julianDate']!);
            int currentJulian = DateTime.now()
                    .difference(DateTime(DateTime.now().year, 1, 1))
                    .inDays +
                1;
            int year = DateTime.now().year;

            // Handle year rollover for flights in next year
            if (julian < currentJulian - 300) {
              year += 1;
              debugPrint(
                  "🔄 Year rollover detected: Julian day $julian < current $currentJulian, using year $year");
            }

            final baseDate = DateTime(year, 1, 1);
            date = baseDate.add(Duration(days: julian - 1));

            debugPrint(
                "📅 Julian date conversion: $julian → ${date.toIso8601String().split('T')[0]}");
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
        
        // Validate PNR: ensure it's not just a class code
        // PNR should be 5-7 alphanumeric characters, not a single letter
        if (pnr.length == 1 && RegExp(r'^[EYFRCJW]$').hasMatch(pnr)) {
          debugPrint('⚠️ Invalid PNR detected (looks like class code): $pnr');
          pnr = ''; // Will be generated later
        }
        
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
        arrivalAirport = arrivalAirport.isEmpty ? '' : arrivalAirport;
        
        // Generate PNR if it was invalid or empty
        // Include date to make it unique for same-flight multiple bookings
        if (pnr.isEmpty && carrier.isNotEmpty && flightNumber.isNotEmpty && departureAirport.isNotEmpty) {
          final dateStr = '${date.month}${date.day}';
          pnr = '${carrier}${flightNumber}$dateStr'.substring(0, 7);
          debugPrint('🔄 Generated PNR: $pnr (original was invalid, includes date for uniqueness)');
        }

        debugPrint("✅ Scanned boarding pass details:");
        debugPrint("  PNR: $pnr");
        debugPrint("  Carrier: $carrier");
        debugPrint("  Flight Number: $flightNumber");
        debugPrint("  Departure Airport: $departureAirport");
        debugPrint("  Date: $date");
        debugPrint("  Class: $classOfService");
      }

      // Check if this specific flight+date combination has already been reviewed
      // This allows multiple flights from same airline but different dates/flight numbers
      final pnrExists = await _boardingPassController.checkPnrExists(pnr);
      if (pnrExists) {
        if (mounted) {
          CustomSnackBar.info(
              context, 'This boarding pass has already been reviewed');
          Navigator.pop(context);
        }
        return;
      }

      // Validate flight identifiers before Cirium lookup
      if (!_isValidFlightIdentifier(carrier, flightNumber)) {
        debugPrint(
            "❌ Invalid flight identifier: carrier='$carrier', flight='$flightNumber'");
        if (mounted) {
          CustomSnackBar.error(
              context, 'Invalid flight data extracted from boarding pass');
          _restartScanner();
          return;
        }
      }

      debugPrint(
          "➡️ Cirium lookup: ${carrier}${flightNumber} on ${date.toIso8601String().split('T')[0]} from $departureAirport");

      final authState = ref.read(authProvider);
      final userId = authState.user.value?.id ?? '';
      final airlineName = _getAirlineNameFromCode(carrier);
      final fallbackBoardingPass = _buildOfflineBoardingPass(
        userId: userId,
        pnr: pnr,
        airlineName: airlineName,
        carrier: carrier,
        flightNumber: flightNumber,
        departureAirport: departureAirport,
        arrivalAirport: arrivalAirport,
        classOfService: classOfService,
        flightDate: date,
      );

      Future<void> _handleOfflineFallback(String message) async {
        await _handleOfflineBoardingPass(
          boardingPass: fallbackBoardingPass,
          seatNumber: seatNumber,
          flightDate: date,
          statusMessage: message,
        );
      }

      // Try the scanned date first
      try {
        Map<String, dynamic> flightInfo =
            await _fetchFlightInfo.fetchFlightInfo(
          carrier: carrier,
          flightNumber: flightNumber,
          flightDate: date,
          departureAirport: departureAirport,
        );

        String responseStr = flightInfo.toString();
        debugPrint(
            "📦 Cirium response: ${responseStr.length > 200 ? responseStr.substring(0, 200) + '...' : responseStr}");

        // Check if flight data was found
        if (flightInfo['flightStatuses']?.isEmpty ?? true) {
          debugPrint("❌ No flight found in Cirium");
          if (mounted) {
            await _handleOfflineFallback(
                'Live flight status is unavailable. We\'re showing the details from your boarding pass only.');
          }
          return;
        }

        debugPrint(
            "✅ Found flight data with ${flightInfo['flightStatuses'].length} status(es)");

        await _processFetchedFlightInfo(flightInfo, pnr, classOfService,
            carrier, flightNumber, date, departureAirport, seatNumber);
      } catch (e) {
        debugPrint(
            "⚠️ Cirium lookup failed, falling back to offline boarding pass data: $e");
        if (mounted) {
          await _handleOfflineFallback(
              'Live flight status couldn\'t be reached. Showing your boarding pass details for confirmation.');
        }
        return;
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Error processing boarding pass: $e");
      debugPrint("Stack trace: $stackTrace");
      if (mounted) {
        CustomSnackBar.error(
            context, 'Unable to process boarding pass: ${e.toString()}');
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

  BoardingPass _buildOfflineBoardingPass({
    required String userId,
    required String pnr,
    required String airlineName,
    required String carrier,
    required String flightNumber,
    required String departureAirport,
    required String arrivalAirport,
    required String classOfService,
    required DateTime flightDate,
  }) {
    final formattedDate =
        '${flightDate.year.toString().padLeft(4, '0')}-${flightDate.month.toString().padLeft(2, '0')}-${flightDate.day.toString().padLeft(2, '0')}';
    final visitStatus = getVisitStatus(flightDate);
    final safeArrival = arrivalAirport.isNotEmpty ? arrivalAirport : '---';
    final safeDeparture = departureAirport.isNotEmpty ? departureAirport : '---';

    return BoardingPass(
      name: userId,
      pnr: pnr,
      airlineName: airlineName,
      departureAirportCode: safeDeparture,
      departureCity: safeDeparture,
      departureCountryCode: '',
      departureTime: formattedDate,
      arrivalAirportCode: safeArrival,
      arrivalCity: safeArrival,
      arrivalCountryCode: '',
      arrivalTime: formattedDate,
      classOfTravel: classOfService,
      airlineCode: carrier,
      flightNumber: '$carrier $flightNumber',
      visitStatus: visitStatus,
    );
  }

  String _getClassOfService(String key) {
    switch (key) {
      case "F":
        return "First";
      case "R":
        return "Premium Economy";
      case "J":
      case "C":
        return "Business";
      case "Y":
      case "E":
      case "W":
        return "Economy";
      default:
        return "Economy";
    }
  }

  /// Map airline code to airline name
  String _getAirlineNameFromCode(String? code) {
    if (code == null || code.isEmpty) return 'Unknown Airline';
    
    // Common airline codes mapping
    final Map<String, String> airlineCodes = {
      'AA': 'American Airlines',
      'UA': 'United Airlines',
      'DL': 'Delta Air Lines',
      'WN': 'Southwest Airlines',
      'BA': 'British Airways',
      'LH': 'Lufthansa',
      'AF': 'Air France',
      'KL': 'KLM',
      'EK': 'Emirates',
      'QF': 'Qantas',
      'SQ': 'Singapore Airlines',
      'CX': 'Cathay Pacific',
      'JL': 'Japan Airlines',
      'NH': 'All Nippon Airways',
      'TG': 'Thai Airways',
      'QR': 'Qatar Airways',
      'EY': 'Etihad Airways',
      'VS': 'Virgin Atlantic',
      'AS': 'Alaska Airlines',
      'B6': 'JetBlue Airways',
      'F9': 'Frontier Airlines',
      'NK': 'Spirit Airlines',
      'G4': 'Allegiant Air',
      'AC': 'Air Canada',
      'AV': 'Avianca',
      'AM': 'Aeroméxico',
      'IB': 'Iberia',
      'AZ': 'ITA Airways',
      'LX': 'Swiss International Air Lines',
      'OS': 'Austrian Airlines',
      'SK': 'Scandinavian Airlines',
      'AY': 'Finnair',
      'TP': 'TAP Air Portugal',
      'SN': 'Brussels Airlines',
      'EI': 'Aer Lingus',
      'KE': 'Korean Air',
      'OZ': 'Asiana Airlines',
      'BR': 'EVA Air',
      'CI': 'China Airlines',
      'MU': 'China Eastern Airlines',
      'CA': 'Air China',
      'CZ': 'China Southern Airlines',
      'AI': 'Air India',
      'SV': 'Saudia',
      'MS': 'EgyptAir',
      'ET': 'Ethiopian Airlines',
      'SA': 'South African Airways',
      'LA': 'LATAM Airlines',
      'AR': 'Aerolineas Argentinas',
      'CM': 'Copa Airlines',
      'AV': 'Avianca',
      '6E': 'IndiGo',
      'SG': 'SpiceJet',
      'UK': 'Vistara',
      'IX': 'Air India Express',
      'QZ': 'AirAsia Indonesia',
      'AK': 'AirAsia',
      'D7': 'AirAsia X',
      'FD': 'Thai AirAsia',
      'VJ': 'VietJet Air',
      'BL': 'Jetstar Pacific',
      'TR': 'Scoot',
      '3K': 'Jetstar Asia',
      'JQ': 'Jetstar Airways',
      'VA': 'Virgin Australia',
      'NZ': 'Air New Zealand',
      'FJ': 'Fiji Airways',
    };
    
    return airlineCodes[code.toUpperCase()] ?? 'Unknown Airline';
  }

  /// Universal BCBP parser following IATA Resolution 792 standard
  Map<String, String> _parseBCBPUniversal(String rawValue) {
    Map<String, String> result = {};

    try {
      final preview = _safeSubstring(rawValue, 0, 50);
      debugPrint("🔍 Parsing BCBP (${rawValue.length} chars): $preview...");

      // IATA Resolution 792 - Fixed field positions
      if (rawValue.length < 52) {
        debugPrint("❌ BCBP too short: ${rawValue.length} chars (need at least 52)");
        return result;
      }

      // Extract fields using exact IATA Resolution 792 offsets with safe operations
      // Position 22: Electronic ticket indicator (usually 'E')
      // Positions 23-28: Actual PNR (6 characters)
      String extractedPnr = _safeSubstring(rawValue, 23, 29).trim();
      
      // Validate PNR: should be alphanumeric and 5-6 characters
      // Remove any non-alphanumeric characters
      extractedPnr = extractedPnr.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      
      // Additional validation: PNR should not be:
      // 1. A single class code letter (E, Y, F, R, C, J, W)
      // 2. All numbers (invalid PNR format)
      // 3. Contain obvious garbage patterns
      bool isValidPnr = extractedPnr.length >= 5 && 
                        extractedPnr.length <= 7 &&
                        !RegExp(r'^[EYFRCJW]$').hasMatch(extractedPnr) && // Not a single class code
                        !RegExp(r'^\d+$').hasMatch(extractedPnr) && // Not all numbers
                        RegExp(r'^[A-Z0-9]+$').hasMatch(extractedPnr); // Only alphanumeric
      
      // If PNR is invalid or too short, leave it empty for generation
      result['pnr'] = isValidPnr ? extractedPnr : '';
      
      // Use safe substring for all extractions
      result['departureAirport'] = _safeSubstring(rawValue, 30, 33);
      result['arrivalAirport'] = _safeSubstring(rawValue, 33, 36);
      result['carrier'] = _safeSubstring(rawValue, 36, 38);
      result['flightNumber'] = _safeSubstring(rawValue, 39, 44).trim().replaceAll(RegExp(r'^0+'), '');
      result['julianDate'] = _safeSubstring(rawValue, 44, 47).trim();
      result['classOfService'] = _safeSubstring(rawValue, 47, 48);
      result['seatNumber'] = _safeSubstring(rawValue, 48, 52).trim();
      
      // Generate PNR if it's empty or invalid
      if (result['pnr']!.isEmpty && 
          result['carrier']!.isNotEmpty && 
          result['flightNumber']!.isNotEmpty && 
          result['departureAirport']!.isNotEmpty) {
        final generated = '${result['carrier']}${result['flightNumber']}${result['departureAirport']}';
        result['pnr'] = _safeSubstring(generated, 0, 6);
        debugPrint('🔄 Generated PNR: ${result['pnr']} (original was invalid)');
      }

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
        case 'E':
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
      debugPrint(
          "  Route: ${result['departureAirport']} → ${result['arrivalAirport']}");
      debugPrint("  Carrier: ${result['carrier']}");
      debugPrint("  Flight: ${result['flightNumber']}");
      debugPrint("  Julian Date: ${result['julianDate']}");
      debugPrint("  Class: ${result['classOfService']}");
      debugPrint("  Seat: ${result['seatNumber']}");

      return result;
    } catch (e, stackTrace) {
      debugPrint("❌ Error in BCBP parsing: $e");
      debugPrint("Stack trace: $stackTrace");
      // Return empty result to prevent crashes
      return {};
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
        String seatNum = match.group(2)!; // 002 or 007
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

  Future<void> _handleOfflineBoardingPass({
    required BoardingPass boardingPass,
    required String seatNumber,
    required DateTime flightDate,
    required String statusMessage,
  }) async {
    debugPrint('📴 Handling offline boarding pass fallback');

    bool saved = false;
    if (boardingPass.name.isNotEmpty) {
      try {
        saved = await _boardingPassController.saveBoardingPass(boardingPass);
        debugPrint(saved
            ? '✅ Boarding pass saved via offline flow'
            : '⚠️ Boarding pass save failed in offline flow');
      } catch (e) {
        debugPrint('⚠️ Boarding pass save threw error in offline flow: $e');
      }
    }

    await _saveOfflineJourneyToSupabase(
      boardingPass: boardingPass,
      flightDate: flightDate,
      seatNumber: seatNumber,
    );

    if (!mounted) return;

    CustomSnackBar.success(
      context,
      'Boarding pass captured. Live flight status unavailable right now.',
    );

    await FlightConfirmationDialog.show(
      context,
      boardingPass,
      seatNumber: seatNumber.isNotEmpty ? seatNumber : null,
      scheduledDeparture: flightDate,
      scheduledArrival: flightDate,
      statusMessage: statusMessage,
      isOfflineMode: true,
    );
  }

  Future<void> _saveOfflineJourneyToSupabase({
    required BoardingPass boardingPass,
    required DateTime flightDate,
    required String seatNumber,
  }) async {
    if (!SupabaseService.isInitialized) return;

    try {
      final authState = ref.read(authProvider);
      final userId = authState.user.value?.id ?? '';
      if (userId.isEmpty) return;

      final departureTime =
          DateTime(flightDate.year, flightDate.month, flightDate.day, 9);
      final arrivalTime = departureTime.add(const Duration(hours: 3));

      final carrierCode = boardingPass.airlineCode;
      final cleanedFlightNumber =
          boardingPass.flightNumber.replaceAll('$carrierCode ', '').trim();

      await SupabaseService.saveFlightDataWithAirportDetails(
        userId: userId,
        pnr: boardingPass.pnr,
        carrier: carrierCode,
        flightNumber: cleanedFlightNumber.isEmpty
            ? boardingPass.flightNumber
            : cleanedFlightNumber,
        departureAirport: boardingPass.departureAirportCode,
        arrivalAirport: boardingPass.arrivalAirportCode,
        scheduledDeparture: departureTime,
        scheduledArrival: arrivalTime,
        seatNumber: seatNumber.isNotEmpty ? seatNumber : null,
        classOfTravel: boardingPass.classOfTravel,
      );

      debugPrint('✅ Offline journey saved to Supabase');
    } catch (e) {
      debugPrint('⚠️ Unable to save offline journey to Supabase: $e');
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

    // Try multiple methods to get airline name
    String? airlineName;
    
    // Method 1: Look up in appendix airlines list
    try {
      final airlineData = airlines.firstWhere(
        (airline) => airline['fs'] == flightStatus['primaryCarrierFsCode'],
        orElse: () => null,
      );
      airlineName = airlineData?['name'];
    } catch (e) {
      debugPrint('⚠️ Could not find airline in appendix: $e');
    }
    
    // Method 2: Try to get from flightStatus carrier object
    if (airlineName == null || airlineName == 'Unknown Airline') {
      airlineName = flightStatus['carrier']?['name'];
      if (airlineName != null) {
        debugPrint('✅ Got airline name from flightStatus.carrier: $airlineName');
      }
    }
    
    // Method 3: Map carrier code to airline name
    if (airlineName == null || airlineName == 'Unknown Airline') {
      final carrierCode = flightStatus['carrierFsCode'] ?? carrier;
      airlineName = _getAirlineNameFromCode(carrierCode);
      if (airlineName != 'Unknown Airline') {
        debugPrint('✅ Mapped carrier code $carrierCode to airline: $airlineName');
      }
    }
    
    // Final fallback
    airlineName ??= 'Unknown Airline';
    debugPrint('📋 Final airline name: $airlineName');

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
    Map<String, dynamic>? journeyResult;
    if (SupabaseService.isInitialized) {
      journeyResult = await SupabaseService.createJourney(
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
      
      // Check if this is a duplicate (PNR + flight_id + seat_number all match)
      if (journeyResult != null && journeyResult['duplicate'] == true) {
        debugPrint('⚠️ Duplicate journey detected - cannot add the same flight');
        if (mounted) {
          _showDuplicateJourneyDialog(context);
          return; // Don't proceed with tracking if it's a duplicate
        }
      } else {
        debugPrint('✅ Journey saved to Supabase');
      }
    }

    // Start real-time flight tracking with Cirium regardless of save result
    debugPrint('🪑 Seat number from boarding pass: $seatNumber');
    final trackingStarted =
        await ref.read(flightTrackingProvider.notifier).trackFlight(
              carrier: carrier,
              flightNumber: flightNumber,
              flightDate: date,
              departureAirport: departureAirportCode,
              pnr: pnr,
              existingFlightData: flightInfo,
            );

    if (trackingStarted) {
      debugPrint('✈️ Flight tracking started successfully for $pnr');
      debugPrint(
          '📡 Real-time monitoring active - will notify at each flight phase');
    } else {
      debugPrint('⚠️ Flight tracking failed');
    }

    if (mounted) {
      if (result) {
        CustomSnackBar.success(context,
            '✅ Boarding pass scanned! Your flight is now being tracked.');
      } else {
        debugPrint(
            '⚠️ Boarding pass save failed, but continuing with tracking');
        CustomSnackBar.success(
            context, '✅ Flight loaded! Your journey is being tracked.');
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

  /// Show dialog when duplicate journey is detected (PNR + flight_id + seat_number all match)
  void _showDuplicateJourneyDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 50,
                  ),
                ),

                SizedBox(height: 24),

                // Title
                Text(
                  'Cannot Add Flight',
                  style: AppStyles.textStyle_24_600.copyWith(color: Colors.black),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 12),

                // Description
                Text(
                  'This journey already exists in active mode.',
                  style: AppStyles.textStyle_16_400.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 32),

                // OK Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'OK',
                      style: AppStyles.textStyle_16_600.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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
