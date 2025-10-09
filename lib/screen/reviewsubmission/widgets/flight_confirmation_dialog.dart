import 'package:flutter/material.dart';
import '../../../models/boarding_pass.dart';
import '../../../utils/app_styles.dart';
import '../../../utils/app_routes.dart';

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
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.flight_takeoff,
                color: Colors.black,
                size: 32,
              ),
            ),
            SizedBox(height: 20),
            
            // Title
            Text(
              'Confirm Flight Details',
              style: AppStyles.textStyle_20_600.copyWith(color: Colors.black),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Please verify your flight information',
              style: AppStyles.textStyle_14_500.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            
            // Flight details card
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  // Flight number and airline
                  _buildDetailRow(
                    Icons.flight,
                    'Flight',
                    '${boardingPass.flightNumber}',
                    subtitle: boardingPass.airlineName,
                  ),
                  SizedBox(height: 16),
                  Divider(height: 1, color: Colors.grey[300]),
                  SizedBox(height: 16),
                  
                  // Route
                  _buildRouteSection(),
                  
                  SizedBox(height: 16),
                  Divider(height: 1, color: Colors.grey[300]),
                  SizedBox(height: 16),
                  
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
                      SizedBox(width: 12),
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
            
            SizedBox(height: 24),
            
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
                      padding: EdgeInsets.symmetric(vertical: 16),
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
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(context, AppRoutes.myJourney);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Confirm',
                      style: AppStyles.textStyle_16_600.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {String? subtitle}) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.black, size: 20),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppStyles.textStyle_12_500.copyWith(color: Colors.grey[600]),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: AppStyles.textStyle_16_600.copyWith(color: Colors.black),
              ),
              if (subtitle != null) ...[
                SizedBox(height: 2),
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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'From',
                style: AppStyles.textStyle_12_500.copyWith(color: Colors.grey[600]),
              ),
              SizedBox(height: 4),
              Text(
                boardingPass.departureAirportCode,
                style: AppStyles.textStyle_18_600.copyWith(color: Colors.black),
              ),
              Text(
                boardingPass.departureCity,
                style: AppStyles.textStyle_12_500.copyWith(color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                boardingPass.departureTime,
                style: AppStyles.textStyle_14_600.copyWith(color: Colors.black),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
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
              SizedBox(height: 4),
              Text(
                boardingPass.arrivalAirportCode,
                style: AppStyles.textStyle_18_600.copyWith(color: Colors.black),
              ),
              Text(
                boardingPass.arrivalCity,
                style: AppStyles.textStyle_12_500.copyWith(color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                boardingPass.arrivalTime,
                style: AppStyles.textStyle_14_600.copyWith(color: Colors.black),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String value, String label) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.black, size: 20),
          SizedBox(height: 4),
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

