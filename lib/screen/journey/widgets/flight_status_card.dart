import 'package:flutter/material.dart';
import '../../../models/flight_tracking_model.dart';
import '../../../utils/app_styles.dart';

class FlightStatusCard extends StatelessWidget {
  final FlightTrackingModel flight;

  const FlightStatusCard({
    Key? key,
    required this.flight,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isCompleted = flight.currentPhase == FlightPhase.completed;
    final progress = _calculateProgress();
    
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            // Airline and Flight Number
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getAirlineName(),
                        style: AppStyles.textStyle_18_600.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Flight ${flight.carrier}${flight.flightNumber}',
                        style: AppStyles.textStyle_14_500.copyWith(
                          color: Colors.white.withAlpha(200),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 24),
            
            // Flight Details Row
            Row(
              children: [
                // Departure
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        flight.departureAirport,
                        style: AppStyles.textStyle_24_600.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _formatTime(flight.departureTime),
                        style: AppStyles.textStyle_14_500.copyWith(
                          color: Colors.white.withAlpha(200),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Progress and Status
                Expanded(
                  child: Column(
                    children: [
                      // Progress Bar
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _getStatusText(),
                        style: AppStyles.textStyle_14_600.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Arrival
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!isCompleted) ...[
                        Text(
                          _getTimeRemaining(),
                          style: AppStyles.textStyle_24_600.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Until Landing',
                          style: AppStyles.textStyle_12_500.copyWith(
                            color: Colors.white.withAlpha(200),
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Completed',
                          style: AppStyles.textStyle_18_600.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      SizedBox(height: 4),
                      Text(
                        flight.arrivalAirport,
                        style: AppStyles.textStyle_24_600.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _formatTime(flight.arrivalTime),
                        style: AppStyles.textStyle_14_500.copyWith(
                          color: Colors.white.withAlpha(200),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _calculateProgress() {
    final now = DateTime.now();
    final totalDuration = flight.arrivalTime.difference(flight.departureTime);
    final elapsed = now.difference(flight.departureTime);
    
    if (flight.currentPhase == FlightPhase.completed) return 1.0;
    if (elapsed.isNegative) return 0.0;
    
    final progress = elapsed.inMilliseconds / totalDuration.inMilliseconds;
    return progress.clamp(0.0, 1.0);
  }

  String _getStatusText() {
    switch (flight.currentPhase) {
      case FlightPhase.preCheckIn:
        return 'Pre-Check In';
      case FlightPhase.checkInOpen:
        return 'Check-In Open';
      case FlightPhase.security:
        return 'Security';
      case FlightPhase.boarding:
        return 'Boarding';
      case FlightPhase.departed:
        return 'Departed';
      case FlightPhase.inFlight:
        return 'In Flight';
      case FlightPhase.landed:
        return 'Landed';
      case FlightPhase.baggageClaim:
        return 'Baggage Claim';
      case FlightPhase.completed:
        return 'Completed';
    }
  }

  String _getTimeRemaining() {
    final now = DateTime.now();
    final remaining = flight.arrivalTime.difference(now);
    
    if (remaining.isNegative) return '0h 0m';
    
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  String _getAirlineName() {
    // Map airline codes to names
    switch (flight.carrier) {
      case 'BA':
        return 'British Airways';
      case 'CX':
        return 'Cathay Pacific';
      case 'AA':
        return 'American Airlines';
      case 'DL':
        return 'Delta Air Lines';
      case 'UA':
        return 'United Airlines';
      case 'LH':
        return 'Lufthansa';
      case 'AF':
        return 'Air France';
      case 'EK':
        return 'Emirates';
      case 'SQ':
        return 'Singapore Airlines';
      default:
        return '${flight.carrier} Airlines';
    }
  }
}
