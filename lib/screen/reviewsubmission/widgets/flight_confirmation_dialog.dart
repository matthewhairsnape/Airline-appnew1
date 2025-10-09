import 'package:flutter/material.dart';
import '../../../models/boarding_pass.dart';
import '../../../utils/app_styles.dart';
import '../../../utils/app_routes.dart';
import '../../../screen/app_widgets/main_button.dart';

class FlightConfirmationDialog extends StatelessWidget {
  final BoardingPass boardingPass;
  final VoidCallback? onCancel;

  const FlightConfirmationDialog({
    Key? key,
    required this.boardingPass,
    this.onCancel,
  }) : super(key: key);

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
                    onPressed: () {
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

  // Static method to show the dialog
  static void show(BuildContext context, BoardingPass boardingPass, {VoidCallback? onCancel}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => FlightConfirmationDialog(
        boardingPass: boardingPass,
        onCancel: onCancel,
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