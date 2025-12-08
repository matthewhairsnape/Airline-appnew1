import 'dart:io';
import 'package:airline_app/provider/user_data_provider.dart';
import 'package:airline_app/provider/flight_tracking_provider.dart';
import 'package:airline_app/provider/auth_provider.dart';
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
import 'package:airline_app/screen/app_widgets/main_button.dart';
import 'package:airline_app/screen/reviewsubmission/widgets/flight_confirmation_dialog.dart';
import 'package:airline_app/utils/app_styles.dart';
import 'package:airline_app/services/supabase_service.dart';

// Show the wallet sync dialog
void showWalletSyncDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    builder: (context) => const WalletSyncDialog(),
  );
}

enum WalletSyncStep { openWallet, chooseScreenshot }

class WalletSyncDialog extends ConsumerStatefulWidget {
  const WalletSyncDialog({super.key});

  @override
  ConsumerState<WalletSyncDialog> createState() => _WalletSyncDialogState();
}

class _WalletSyncDialogState extends ConsumerState<WalletSyncDialog> {
  final MobileScannerController _controller = MobileScannerController();
  final FetchFlightInforByCirium _flightInfoFetcher =
      FetchFlightInforByCirium();
  final BoardingPassController _boardingPassController =
      BoardingPassController();
  final ImagePicker _imagePicker = ImagePicker();

  Map<String, dynamic>? detailedBoardingPass;
  bool isLoading = false;
  WalletSyncStep currentStep = WalletSyncStep.openWallet;
  bool walletOpened = false;
  File? selectedImage;

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

  Future<void> parseIataBarcode(String rawValue) async {
    if (!mounted) return;
    
    setState(() => isLoading = true);
    
    try {
      debugPrint("rawValue 🎎 =====================> $rawValue");

      String pnr = '';
      String departureAirport = '';
      String arrivalAirport = '';
      String carrier = '';
      String flightNumber = '';
      String classOfService = 'Economy';
      String seatNumber = '';
      DateTime date = DateTime.now();

      // Check if it's BCBP format (starts with M1 or M2)
      if (rawValue.startsWith('M1') || rawValue.startsWith('M2')) {
        debugPrint("✅ Detected BCBP format");

        // IATA Resolution 792 BCBP Format - Fixed field positions
        // M1 = Format code (positions 1-2)
        // Passenger name (positions 3-22, variable length with padding)
        // E + PNR (positions 23-29): E = Electronic ticket, PNR = 6 chars
        // Flight info starts at position 30+

        if (rawValue.length < 52) {
          debugPrint("❌ BCBP too short: ${rawValue.length} chars (need at least 52)");
          throw Exception('Invalid BCBP format: too short');
        }

        // Extract PNR from fixed position (23-29, skip position 22 which is 'E')
        String extractedPnr = _safeSubstring(rawValue, 23, 29).trim();
        
        // Validate PNR: should be alphanumeric and 5-6 characters
        extractedPnr = extractedPnr.replaceAll(RegExp(r'[^A-Z0-9]'), '');
        
        // PNR validation
        bool isValidPnr = extractedPnr.length >= 5 && 
                          extractedPnr.length <= 7 &&
                          !RegExp(r'^[EYFRCJW]$').hasMatch(extractedPnr) && // Not a single class code
                          !RegExp(r'^\d+$').hasMatch(extractedPnr) && // Not all numbers
                          RegExp(r'^[A-Z0-9]+$').hasMatch(extractedPnr); // Only alphanumeric
        
        pnr = isValidPnr ? extractedPnr : '';

        // Extract flight info from fixed positions using safe substring
        departureAirport = _safeSubstring(rawValue, 30, 33);
        arrivalAirport = _safeSubstring(rawValue, 33, 36);
        carrier = _safeSubstring(rawValue, 36, 38);
        flightNumber = _safeSubstring(rawValue, 39, 44).trim().replaceAll(RegExp(r'^0+'), '');
        String julianDate = _safeSubstring(rawValue, 44, 47).trim();
        String classCode = _safeSubstring(rawValue, 47, 48);
        classOfService = _getClassOfService(classCode);
        seatNumber = _safeSubstring(rawValue, 48, 52).trim();
        if (seatNumber.isNotEmpty) {
          final seatMatch = RegExp(r'(\d+)([A-Z])').firstMatch(seatNumber);
          if (seatMatch != null) {
            final seatNum = seatMatch.group(1)!.replaceAll(RegExp(r'^0+'), '');
            seatNumber =
                '${seatNum.isEmpty ? '1' : seatNum}${seatMatch.group(2)}';
          }
        }

        // Parse Julian date
        if (julianDate.length >= 3) {
          final baseDate = DateTime(DateTime.now().year, 1, 0);
          date = baseDate.add(Duration(days: int.parse(julianDate)));
        }

        // Generate PNR if it was invalid or empty
        if (pnr.isEmpty && carrier.isNotEmpty && flightNumber.isNotEmpty && departureAirport.isNotEmpty) {
          pnr = '${carrier}${flightNumber}${departureAirport}'.substring(0, 6);
          debugPrint('🔄 Generated PNR: $pnr (original was invalid)');
        }

        debugPrint("✅ Parsed BCBP boarding pass:");
        debugPrint("  PNR: $pnr (${isValidPnr ? 'extracted' : 'generated'})");
        debugPrint("  Departure: $departureAirport");
        debugPrint("  Arrival: $arrivalAirport");
        debugPrint("  Carrier: $carrier");
        debugPrint("  Flight: $flightNumber");
        debugPrint("  Date: $date");
        debugPrint("  Class: $classOfService");
      } else {
        // Try old format parsing
        final RegExp regex = RegExp(
            r'([A-Z0-9]{5,7})\s+([A-Z]{6}[A-Z0-9]{2})\s+(\d{4})\s+(\d{3}[A-Z])');
        final Match? match = regex.firstMatch(rawValue);

        if (match == null) {
          throw Exception('Invalid barcode format');
        }

        pnr = match.group(1)!;
        
        // Validate PNR: ensure it's not just a class code
        // PNR should be 5-7 alphanumeric characters, not a single letter
        if (pnr.length == 1 && RegExp(r'^[EYFRCJW]$').hasMatch(pnr)) {
          debugPrint('⚠️ Invalid PNR detected (looks like class code): $pnr');
          pnr = ''; // Will be generated later
        }
        
        final String routeOfFlight = match.group(2)!;
        flightNumber = match.group(3)!;
        final String julianDateAndClassOfService = match.group(4)!;
        departureAirport = routeOfFlight.substring(0, 3);
        arrivalAirport = routeOfFlight.substring(3, 6);
        carrier = routeOfFlight.substring(6, 8).trim();
        final String julianDate = julianDateAndClassOfService.substring(0, 3);
        final String classOfServiceKey =
            julianDateAndClassOfService.substring(3, 4);
        classOfService = _getClassOfService(classOfServiceKey);
        final DateTime baseDate = DateTime(DateTime.now().year, 1, 0);
        date = baseDate.add(Duration(days: int.parse(julianDate)));
        
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
      final bool pnrExists = await _boardingPassController.checkPnrExists(pnr);
      if (pnrExists) {
        if (mounted) {
          CustomSnackBar.info(
              context, "This boarding pass has already been reviewed.");
        }
        return;
      }

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

      try {
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
              await _handleOfflineFallback(
                  "Live flight status is unavailable. Showing boarding pass details only.");
            }
            return;
          }
        }

        await _processFetchedFlightInfo(
          flightInfo,
          pnr,
          classOfService,
          seatNumber: seatNumber,
        );
      } catch (e) {
        debugPrint(
            '⚠️ Cirium lookup failed for wallet sync: $e. Falling back to offline data.');
        if (mounted) {
          await _handleOfflineFallback(
              "Live flight status is unavailable. Showing boarding pass details only.");
        }
      }
    } catch (e) {
      debugPrint("❌ Error parsing barcode: $e");
      if (mounted) {
        CustomSnackBar.info(context,
            "Oops! We had trouble processing your boarding pass. Please try again.");
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
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

  Future<void> _processFetchedFlightInfo(
    Map<String, dynamic> flightInfo,
    String pnr,
    String classOfService, {
    String? seatNumber,
  }) async {
    if (flightInfo['flightStatuses']?.isEmpty ?? true) {
      CustomSnackBar.error(
          context, "No flight data found for the boarding pass.");
      return;
    }

    try {
      final flightStatus = flightInfo['flightStatuses'][0];
      final airlines = flightInfo['appendix']['airlines'] as List?;
      final airports = flightInfo['appendix']['airports'] as List?;
      
      debugPrint('📊 Flight data received:');
      debugPrint('   Carrier: ${flightStatus['primaryCarrierFsCode']}');
      debugPrint('   Departure: ${flightStatus['departureAirportFsCode']}');
      debugPrint('   Arrival: ${flightStatus['arrivalAirportFsCode']}');
      debugPrint('   Airlines in appendix: ${airlines?.length ?? 0}');
      debugPrint('   Airports in appendix: ${airports?.length ?? 0}');
      
      // Try multiple methods to get airline name
      String? airlineName;
      
      // Method 1: Look up in appendix airlines list
      try {
        final airlineData = airlines?.firstWhere(
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
        final carrierCode = flightStatus['carrierFsCode'];
        airlineName = _getAirlineNameFromCode(carrierCode);
        if (airlineName != 'Unknown Airline') {
          debugPrint('✅ Mapped carrier code $carrierCode to airline: $airlineName');
        }
      }
      
      // Final fallback
      airlineName ??= 'Unknown Airline';
      debugPrint('   ✅ Airline name: $airlineName');
      
      // Safely find departure airport with fallback
      final departureAirport = airports?.firstWhere(
        (airport) => airport['fs'] == flightStatus['departureAirportFsCode'],
        orElse: () => {
          'fs': flightStatus['departureAirportFsCode'],
          'city': 'Unknown',
          'countryCode': 'XX',
        },
      );
      
      debugPrint('   ✅ Departure airport: ${departureAirport?['fs']} - ${departureAirport?['city']}');
      
      // Safely find arrival airport with fallback
      final arrivalAirport = airports?.firstWhere(
        (airport) => airport['fs'] == flightStatus['arrivalAirportFsCode'],
        orElse: () => {
          'fs': flightStatus['arrivalAirportFsCode'],
          'city': 'Unknown',
          'countryCode': 'XX',
        },
      );
      
      debugPrint('   ✅ Arrival airport: ${arrivalAirport?['fs']} - ${arrivalAirport?['city']}');
      
      final departureEntireTime =
          DateTime.parse(flightStatus['departureDate']['dateLocal']);
      final arrivalEntireTime =
          DateTime.parse(flightStatus['arrivalDate']['dateLocal']);

      // Get user ID from auth provider
      final authState = ref.read(authProvider);
      final userId = authState.user.value?.id ?? '';

      debugPrint('   ✅ Creating boarding pass object');
      
      final newPass = BoardingPass(
        name: userId.toString(),
        pnr: pnr,
        airlineName: airlineName,
        departureAirportCode: departureAirport?['fs'] ?? '',
        departureCity: departureAirport?['city'] ?? 'Unknown',
        departureCountryCode: departureAirport?['countryCode'] ?? 'XX',
        departureTime: _formatTime(departureEntireTime),
        arrivalAirportCode: arrivalAirport?['fs'] ?? '',
        arrivalCity: arrivalAirport?['city'] ?? 'Unknown',
        arrivalCountryCode: arrivalAirport?['countryCode'] ?? 'XX',
        arrivalTime: _formatTime(arrivalEntireTime),
        classOfTravel: classOfService,
        airlineCode: flightStatus['carrierFsCode'] ?? '',
        flightNumber:
            "${flightStatus['carrierFsCode']} ${flightStatus['flightNumber']}",
        visitStatus: _getVisitStatus(departureEntireTime),
      );

      debugPrint('   ✅ Saving boarding pass to database');
      final bool result = await _boardingPassController.saveBoardingPass(newPass);
      debugPrint('   ${result ? "✅" : "⚠️"} Boarding pass save result: $result');

      // Start real-time flight tracking with Cirium
      final carrier = flightStatus['carrierFsCode'] ?? '';
      final flightNumber = flightStatus['flightNumber']?.toString() ?? '';
      final flightDate = departureEntireTime;
      final departureAirportCode = departureAirport?['fs'] ?? '';

      debugPrint(
          '🪑 Starting flight tracking for wallet sync: $carrier $flightNumber');
      final trackingStarted =
          await ref.read(flightTrackingProvider.notifier).trackFlight(
                carrier: carrier,
                flightNumber: flightNumber,
                flightDate: flightDate,
                departureAirport: departureAirportCode,
                pnr: pnr,
                existingFlightData: flightInfo,
              );

      if (trackingStarted) {
        debugPrint('✈️ Flight tracking started successfully for $pnr');
      } else {
        debugPrint('⚠️ Flight tracking did not start for $pnr');
      }

      if (mounted) {
        debugPrint('✅ Processing complete, preparing to show confirmation dialog');
        
        if (result) {
          CustomSnackBar.success(
              context, '✅ Boarding pass from wallet loaded successfully!');
        } else {
          CustomSnackBar.success(
              context, '✅ Flight loaded! Your journey is being tracked.');
        }

        // Close the wallet sync dialog first
        debugPrint('🔙 Closing wallet sync dialog');
        Navigator.pop(context);

        // Add a small delay to ensure the wallet dialog is fully closed
        await Future.delayed(const Duration(milliseconds: 500));

        // Check if still mounted after delay
        if (!mounted) {
          debugPrint('❌ Widget unmounted after delay, cannot show confirmation');
          return;
        }

        try {
          // Show confirmation dialog
          debugPrint('📱 Showing FlightConfirmationDialog');
          await FlightConfirmationDialog.show(
            context,
            newPass,
            onCancel: () {
              debugPrint('❌ User cancelled flight confirmation');
            },
            ciriumFlightData: flightInfo,
            seatNumber: seatNumber,
            terminal: flightStatus['airportResources']?['departureTerminal'],
            gate: flightStatus['airportResources']?['departureGate'],
            aircraftType: flightStatus['flightEquipment']?['iata'],
            scheduledDeparture: departureEntireTime,
            scheduledArrival: arrivalEntireTime,
          );
          debugPrint('✅ FlightConfirmationDialog shown successfully');
        } catch (e) {
          debugPrint('❌ Error showing confirmation dialog: $e');
        }
      } else {
        debugPrint('❌ Widget not mounted, cannot show confirmation dialog');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error processing flight info: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      if (mounted) {
        CustomSnackBar.error(
            context, 'Unable to process boarding pass. Please try again.');
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
    final visitStatus = _getVisitStatus(flightDate);
    final fallbackDeparture =
        departureAirport.isNotEmpty ? departureAirport : '---';
    final fallbackArrival =
        arrivalAirport.isNotEmpty ? arrivalAirport : '---';

    return BoardingPass(
      name: userId,
      pnr: pnr,
      airlineName: airlineName,
      departureAirportCode: fallbackDeparture,
      departureCity: fallbackDeparture,
      departureCountryCode: '',
      departureTime: '--:--',
      arrivalAirportCode: fallbackArrival,
      arrivalCity: fallbackArrival,
      arrivalCountryCode: '',
      arrivalTime: '--:--',
      classOfTravel: classOfService,
      airlineCode: carrier,
      flightNumber: '$carrier $flightNumber',
      visitStatus: visitStatus,
    );
  }

  Future<void> _handleOfflineBoardingPass({
    required BoardingPass boardingPass,
    required String seatNumber,
    required DateTime flightDate,
    required String statusMessage,
  }) async {
    debugPrint('📴 Handling offline wallet boarding pass fallback');

    bool saved = false;
    if (boardingPass.name.isNotEmpty) {
      saved = await _boardingPassController.saveBoardingPass(boardingPass);
      debugPrint(saved
          ? '✅ Boarding pass saved via wallet offline flow'
          : '⚠️ Boarding pass save failed in wallet offline flow');
    }

    if (!mounted) return;

    await _saveOfflineJourneyToSupabase(
      boardingPass: boardingPass,
      flightDate: flightDate,
      seatNumber: seatNumber,
    );

    CustomSnackBar.success(
      context,
      'Boarding pass captured from wallet. Live status unavailable right now.',
    );

    Navigator.pop(context);
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    final fallbackDate =
        DateTime(flightDate.year, flightDate.month, flightDate.day);

    await FlightConfirmationDialog.show(
      context,
      boardingPass,
      seatNumber: seatNumber.isNotEmpty ? seatNumber : null,
      scheduledDeparture: fallbackDate,
      scheduledArrival: fallbackDate,
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

      debugPrint('✅ Offline wallet journey saved to Supabase');
    } catch (e) {
      debugPrint('⚠️ Unable to save wallet offline journey to Supabase: $e');
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with close button
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Sync from Your Wallet",
                      style: AppStyles.textStyle_24_600,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Progress Stepper
              _buildProgressStepper(),
              const SizedBox(height: 24),

              // Content based on current step
              _buildStepContent(),

              const SizedBox(height: 24),

              // Action buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressStepper() {
    return Row(
      children: [
        _buildStepDot(1, currentStep.index >= 0),
        _buildStepLine(currentStep.index >= 1),
        _buildStepDot(2, currentStep.index >= 1),
      ],
    );
  }

  Widget _buildStepDot(int stepNumber, bool isActive) {
    return Expanded(
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? Colors.black : Colors.grey[300],
        ),
        child: Center(
          child: Text(
            stepNumber.toString(),
            style: AppStyles.textStyle_16_600.copyWith(
              color: isActive ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepLine(bool isActive) {
    return Expanded(
      flex: 2,
      child: Container(
        height: 2,
        color: isActive ? Colors.black : Colors.grey[300],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (currentStep) {
      case WalletSyncStep.openWallet:
        return _buildOpenWalletContent();
      case WalletSyncStep.chooseScreenshot:
        return _buildChooseScreenshotContent();
    }
  }

  Widget _buildOpenWalletContent() {
    return Column(
      children: [
        Icon(
          Icons.account_balance_wallet,
          size: 60,
          color: Colors.black,
        ),
        const SizedBox(height: 16),
        Text(
          "Step 1: Open Your Wallet",
          style: AppStyles.textStyle_20_600,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          "Open your wallet app and take a screenshot of your boarding pass",
          style: AppStyles.textStyle_14_500.copyWith(color: Colors.grey[700]),
          textAlign: TextAlign.center,
        ),
        if (walletOpened) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Wallet opened! Take your screenshot",
                    style: AppStyles.textStyle_14_600
                        .copyWith(color: Colors.green[900]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChooseScreenshotContent() {
    return Column(
      children: [
        Icon(
          Icons.photo_library,
          size: 60,
          color: Colors.black,
        ),
        const SizedBox(height: 16),
        Text(
          "Step 2: Choose Screenshot",
          style: AppStyles.textStyle_20_600,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          selectedImage == null
              ? "Select the boarding pass screenshot from your photos"
              : "Ready to verify! We'll scan the barcode and confirm your flight details",
          style: AppStyles.textStyle_14_500.copyWith(color: Colors.grey[700]),
          textAlign: TextAlign.center,
        ),
        if (selectedImage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Screenshot selected - Click Verify to continue",
                    style: AppStyles.textStyle_14_600
                        .copyWith(color: Colors.green[900]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    if (currentStep == WalletSyncStep.openWallet) {
      return Column(
        children: [
          MainButton(
            text: "Open Wallet App",
            onPressed: _handleOpenWallet,
            color: Colors.black,
            icon: const Icon(Icons.account_balance_wallet, color: Colors.white),
          ),
          if (walletOpened) ...[
            const SizedBox(height: 12),
            MainButton(
              text: "Continue to Next Step",
              onPressed: _moveToScreenshotStep,
              color: Colors.black,
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: _moveToScreenshotStep,
            child: Text(
              "Already have a screenshot? Skip",
              style: AppStyles.textStyle_14_500.copyWith(
                color: Colors.grey[700],
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      );
    } else if (currentStep == WalletSyncStep.chooseScreenshot) {
      return Column(
        children: [
          if (selectedImage == null) ...[
            MainButton(
              text: "Choose Screenshot",
              onPressed: _pickScreenshot,
              color: Colors.black,
              icon: const Icon(Icons.photo_library, color: Colors.white),
            ),
          ] else ...[
            MainButton(
              text: isLoading ? "Processing..." : "Verify Boarding Pass",
              onPressed: isLoading ? () {} : () => _scanSelectedImage(),
              color: Colors.black,
              icon: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check_circle, color: Colors.white),
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() {
                currentStep = WalletSyncStep.openWallet;
                selectedImage = null;
              });
            },
            child: Text(
              "← Back",
              style:
                  AppStyles.textStyle_14_500.copyWith(color: Colors.grey[700]),
            ),
          ),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Future<void> _handleOpenWallet() async {
    try {
      await _launchWallet();
      setState(() {
        walletOpened = true;
      });
    } catch (e) {
      if (mounted) {
        CustomSnackBar.error(
            context, "Could not open wallet. Please try manually.");
      }
    }
  }

  void _moveToScreenshotStep() {
    setState(() {
      currentStep = WalletSyncStep.chooseScreenshot;
    });
  }

  Future<void> _pickScreenshot() async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (file != null) {
        setState(() {
          selectedImage = File(file.path);
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.error(
            context, "Failed to pick image. Please try again.");
      }
    }
  }

  Future<void> _scanSelectedImage() async {
    if (selectedImage == null) {
      debugPrint("❌ No image selected for scanning");
      return;
    }

    debugPrint("🔍 Starting to scan selected image: ${selectedImage!.path}");
    setState(() => isLoading = true);

    try {
      debugPrint("📸 Analyzing image for barcodes...");
      final BarcodeCapture? barcodeCapture =
          await _controller.analyzeImage(selectedImage!.path);

      debugPrint(
          "📸 Barcode capture result: ${barcodeCapture?.barcodes.length ?? 0} barcodes found");

      final String? rawValue = barcodeCapture?.barcodes.firstOrNull?.rawValue;

      if (rawValue != null) {
        debugPrint("✅ Barcode found, length: ${rawValue.length} chars");
        debugPrint("✅ Barcode raw value: $rawValue");
        debugPrint("🔄 Calling parseIataBarcode...");
        await parseIataBarcode(rawValue);
        debugPrint("✅ parseIataBarcode completed");
      } else {
        debugPrint("❌ No barcode found in image");
        if (mounted) {
          CustomSnackBar.error(context,
              "This boarding pass cannot be scanned due to poor quality.");
          setState(() {
            selectedImage = null;
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Error scanning image: $e");
      debugPrint("❌ Stack trace: $stackTrace");
      if (mounted) {
        CustomSnackBar.info(context,
            'Unable to scan the boarding pass. Please try again with a clearer image.');
        setState(() {
          selectedImage = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
