import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/boarding_pass.dart';
import '../../../services/supabase_service.dart';
import '../../../provider/user_data_provider.dart';
import '../../../utils/app_styles.dart';
import '../../../utils/app_routes.dart';
import '../../../screen/app_widgets/main_button.dart';
import '../../../screen/app_widgets/custom_snackbar.dart';

class FlightConfirmationDialog extends ConsumerWidget {
  final BoardingPass boardingPass;
  final VoidCallback? onCancel;
  final Map<String, dynamic>? ciriumFlightData;
  final String? seatNumber;
  final String? terminal;
  final String? gate;
  final String? aircraftType;
  final DateTime? scheduledDeparture;
  final DateTime? scheduledArrival;

  const FlightConfirmationDialog({
    Key? key,
    required this.boardingPass,
    this.onCancel,
    this.ciriumFlightData,
    this.seatNumber,
    this.terminal,
    this.gate,
    this.aircraftType,
    this.scheduledDeparture,
    this.scheduledArrival,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
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
                    'Confirm Flight Details',
                    style: AppStyles.textStyle_24_600,
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Navigator.pop(context);
                    onCancel?.call();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Flight icon
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.flight_takeoff,
                  color: Colors.black,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Subtitle
            Text(
              'Please verify your flight information',
              style: AppStyles.textStyle_16_400.copyWith(
                color: Colors.grey[700],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Flight details card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  // Flight number and airline
                  _buildDetailRow(
                    Icons.flight,
                    'Flight',
                    boardingPass.flightNumber,
                    subtitle: boardingPass.airlineName,
                  ),
                  const SizedBox(height: 20),
                  
                  // Route section
                  _buildRouteSection(),
                  
                  const SizedBox(height: 20),
                  
                  // Class and PNR
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoChip(
                          Icons.airline_seat_recline_normal,
                          boardingPass.classOfTravel,
                          'Class',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoChip(
                          Icons.confirmation_number,
                          boardingPass.pnr,
                          'PNR',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onCancel?.call();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      'Cancel',
                      style: AppStyles.textStyle_16_600.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MainButton(
                    text: 'Confirm',
                    onPressed: () async {
                      debugPrint('🎯 Flight confirmation: User clicked Confirm button');
                      await _saveFlightDataToDatabase(context, ref);
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(context, AppRoutes.myJourney);
                    },
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
  }

  // Method to save flight data to database
  Future<void> _saveFlightDataToDatabase(BuildContext context, WidgetRef ref) async {
    if (!SupabaseService.isInitialized) {
      debugPrint('⚠️ Supabase not initialized, skipping database save');
      return;
    }

    try {
      final session = SupabaseService.client.auth.currentSession;
      final userId = session?.user.id ?? '';
      if (userId.isEmpty) {
        debugPrint('❌ User ID not found, cannot save flight data');
        CustomSnackBar.error(context, 'User not authenticated. Please log in again.');
        return;
      }

      // Validate boarding pass data
      if (!_validateBoardingPassData()) {
        CustomSnackBar.error(context, 'Invalid flight data. Please scan again.');
        return;
      }

      // Extract flight details from boarding pass and Cirium data
      final carrier = boardingPass.airlineCode;
      final flightNumber = boardingPass.flightNumber.replaceAll('$carrier ', '');
      
      // Use provided scheduled times or parse from boarding pass
      final departureTime = scheduledDeparture ?? _parseFlightTime(boardingPass.departureTime);
      final arrivalTime = scheduledArrival ?? _parseFlightTime(boardingPass.arrivalTime);
      
      if (departureTime == null || arrivalTime == null) {
        debugPrint('❌ Could not parse flight times');
        CustomSnackBar.error(context, 'Invalid flight time data');
        return;
      }

      // Validate flight times
      if (arrivalTime.isBefore(departureTime)) {
        debugPrint('❌ Arrival time is before departure time');
        CustomSnackBar.error(context, 'Invalid flight schedule. Arrival time cannot be before departure time.');
        return;
      }

      // Save journey to Supabase using enhanced method
      final journeyResult = await SupabaseService.saveFlightData(
        userId: userId.toString(),
        pnr: boardingPass.pnr,
        carrier: carrier,
        flightNumber: flightNumber,
        departureAirport: boardingPass.departureAirportCode,
        arrivalAirport: boardingPass.arrivalAirportCode,
        scheduledDeparture: departureTime,
        scheduledArrival: arrivalTime,
        seatNumber: seatNumber?.isNotEmpty == true ? seatNumber : null,
        classOfTravel: boardingPass.classOfTravel,
        terminal: terminal?.isNotEmpty == true ? terminal : null,
        gate: gate?.isNotEmpty == true ? gate : null,
        aircraftType: aircraftType?.isNotEmpty == true ? aircraftType : null,
        ciriumData: ciriumFlightData,
      );

      if (journeyResult != null) {
        debugPrint('✅ Flight data saved to database successfully');
        CustomSnackBar.success(context, 'Flight confirmed and saved!');
      } else {
        debugPrint('❌ Failed to save flight data to database');
        CustomSnackBar.error(context, 'Failed to save flight data. Please try again.');
      }
    } catch (e) {
      debugPrint('❌ Error saving flight data: $e');
      CustomSnackBar.error(context, 'Error saving flight data: ${e.toString()}');
    }
  }

  // Helper method to validate boarding pass data
  bool _validateBoardingPassData() {
    // Check required fields
    if (boardingPass.pnr.isEmpty) {
      debugPrint('❌ PNR is empty');
      return false;
    }
    
    if (boardingPass.airlineCode.isEmpty) {
      debugPrint('❌ Airline code is empty');
      return false;
    }
    
    if (boardingPass.flightNumber.isEmpty) {
      debugPrint('❌ Flight number is empty');
      return false;
    }
    
    if (boardingPass.departureAirportCode.isEmpty) {
      debugPrint('❌ Departure airport code is empty');
      return false;
    }
    
    if (boardingPass.arrivalAirportCode.isEmpty) {
      debugPrint('❌ Arrival airport code is empty');
      return false;
    }
    
    if (boardingPass.departureTime.isEmpty) {
      debugPrint('❌ Departure time is empty');
      return false;
    }
    
    if (boardingPass.arrivalTime.isEmpty) {
      debugPrint('❌ Arrival time is empty');
      return false;
    }
    
    // Validate airport codes format (should be 3 characters)
    if (boardingPass.departureAirportCode.length != 3) {
      debugPrint('❌ Invalid departure airport code format: ${boardingPass.departureAirportCode}');
      return false;
    }
    
    if (boardingPass.arrivalAirportCode.length != 3) {
      debugPrint('❌ Invalid arrival airport code format: ${boardingPass.arrivalAirportCode}');
      return false;
    }
    
    // Validate PNR format (should be 6 characters)
    if (boardingPass.pnr.length != 6) {
      debugPrint('❌ Invalid PNR format: ${boardingPass.pnr}');
      return false;
    }
    
    return true;
  }

  // Helper method to parse flight time
  DateTime? _parseFlightTime(String timeString) {
    try {
      // Assuming time format is "HH:MM"
      final parts = timeString.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        
        // Use today's date as base, you might want to adjust this based on your needs
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day, hour, minute);
      }
    } catch (e) {
      debugPrint('Error parsing time: $e');
    }
    return null;
  }

  // Static method to show the dialog
  static void show(
    BuildContext context, 
    BoardingPass boardingPass, {
    VoidCallback? onCancel,
    Map<String, dynamic>? ciriumFlightData,
    String? seatNumber,
    String? terminal,
    String? gate,
    String? aircraftType,
    DateTime? scheduledDeparture,
    DateTime? scheduledArrival,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => FlightConfirmationDialog(
        boardingPass: boardingPass,
        onCancel: onCancel,
        ciriumFlightData: ciriumFlightData,
        seatNumber: seatNumber,
        terminal: terminal,
        gate: gate,
        aircraftType: aircraftType,
        scheduledDeparture: scheduledDeparture,
        scheduledArrival: scheduledArrival,
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {String? subtitle}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.black, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppStyles.textStyle_12_500.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppStyles.textStyle_16_600.copyWith(color: Colors.black),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppStyles.textStyle_12_500.copyWith(color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRouteSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'From',
                  style: AppStyles.textStyle_12_500.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  boardingPass.departureAirportCode,
                  style: AppStyles.textStyle_18_600.copyWith(color: Colors.black),
                ),
                Text(
                  boardingPass.departureCity,
                  style: AppStyles.textStyle_12_500.copyWith(color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  boardingPass.departureTime,
                  style: AppStyles.textStyle_14_600.copyWith(color: Colors.black),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Icons.arrow_forward,
              color: Colors.black,
              size: 24,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'To',
                  style: AppStyles.textStyle_12_500.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  boardingPass.arrivalAirportCode,
                  style: AppStyles.textStyle_18_600.copyWith(color: Colors.black),
                ),
                Text(
                  boardingPass.arrivalCity,
                  style: AppStyles.textStyle_12_500.copyWith(color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  boardingPass.arrivalTime,
                  style: AppStyles.textStyle_14_600.copyWith(color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.black, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppStyles.textStyle_14_600.copyWith(color: Colors.black),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: AppStyles.textStyle_10_500.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}