import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/flight_tracking_model.dart';
import '../../models/stage_feedback_model.dart';
import '../../provider/flight_tracking_provider.dart';
import '../../provider/stage_feedback_provider.dart';
import '../../utils/app_styles.dart';
import '../../utils/app_routes.dart';
import '../app_widgets/main_button.dart';
import 'widgets/journey_event_card.dart';
import 'widgets/micro_review_modal.dart';

class MyJourneyScreen extends ConsumerStatefulWidget {
  const MyJourneyScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MyJourneyScreen> createState() => _MyJourneyScreenState();
}

class _MyJourneyScreenState extends ConsumerState<MyJourneyScreen> {
  @override
  Widget build(BuildContext context) {
    final flightTrackingState = ref.watch(flightTrackingProvider);
    final allFlights = flightTrackingState.getAllFlights();
    final activeFlights = flightTrackingState.trackedFlights.values.toList();
    final completedFlights = flightTrackingState.completedFlights.values.toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Journey',
          style: AppStyles.textStyle_20_600.copyWith(color: Colors.black),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              // Refresh flight data
              ref.refresh(flightTrackingProvider);
            },
          ),
        ],
      ),
      body: allFlights.isEmpty
          ? _buildEmptyState()
          : _buildJourneyContent(activeFlights, completedFlights),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flight_takeoff,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 24),
            Text(
              'No Active Flights',
              style: AppStyles.textStyle_24_600.copyWith(color: Colors.grey[600]),
            ),
            SizedBox(height: 12),
            Text(
              'Scan your boarding pass to start tracking your journey and provide real-time feedback.',
              textAlign: TextAlign.center,
              style: AppStyles.textStyle_16_400.copyWith(color: Colors.grey[500]),
            ),
            SizedBox(height: 32),
            MainButton(
              text: 'Scan Boarding Pass',
              onPressed: () {
                Navigator.pushNamed(context, '/scanner');
              },
              color: Color(0xFF3B82F6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJourneyContent(List<FlightTrackingModel> activeFlights, List<FlightTrackingModel> completedFlights) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active flights section
          if (activeFlights.isNotEmpty) ...[
            _buildSectionHeader('Active Flights', activeFlights.length),
            SizedBox(height: 16),
            ...activeFlights.map((flight) => _buildFlightCard(flight, isActive: true)),
            SizedBox(height: 24),
          ],
          
          // Completed flights section
          if (completedFlights.isNotEmpty) ...[
            _buildSectionHeader('Flight History', completedFlights.length),
            SizedBox(height: 16),
            ...completedFlights.map((flight) => _buildFlightCard(flight, isActive: false)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: AppStyles.textStyle_18_600.copyWith(color: Colors.black),
        ),
        SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: AppStyles.textStyle_12_600.copyWith(color: Colors.blue[700]),
          ),
        ),
      ],
    );
  }

  Widget _buildFlightCard(FlightTrackingModel flight, {required bool isActive}) {
    final hasStageFeedback = ref.watch(stageFeedbackProvider.notifier).hasFeedback(flight.flightId);
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flight summary header
          _buildFlightSummary(flight, isActive: isActive),
          
          SizedBox(height: 16),
          
          // Journey sections
          _buildJourneySection('Pre Flight', _getPreFlightEvents(flight), isActive: isActive),
          SizedBox(height: 12),
          _buildJourneySection('In Flight', _getInFlightEvents(flight), isActive: isActive),
          SizedBox(height: 12),
          _buildJourneySection('Post Flight', _getPostFlightEvents(flight), isActive: isActive),
          
          // Show "Complete Review" button for completed flights
          if (!isActive && flight.currentPhase == FlightPhase.completed) ...[
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(25),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.rate_review, color: Color(0xFF3B82F6), size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Share Your Experience',
                              style: AppStyles.textStyle_16_600.copyWith(color: Colors.black),
                            ),
                            SizedBox(height: 4),
                            Text(
                              hasStageFeedback 
                                  ? 'Complete your review with photos and detailed ratings'
                                  : 'Tell us about your journey and help other travelers',
                              style: AppStyles.textStyle_14_400.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  MainButton(
                    text: 'Complete Review & Share',
                    onPressed: () => _navigateToCompleteReview(flight),
                    color: Color(0xFF3B82F6),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  void _navigateToCompleteReview(FlightTrackingModel flight) {
    // Navigate to review submission with flight data
    Navigator.pushNamed(
      context,
      AppRoutes.reviewsubmissionscreen,
      arguments: {
        'flight': flight,
        'flightId': flight.flightId,
        'pnr': flight.pnr,
      },
    );
  }

  Widget _buildFlightSummary(FlightTrackingModel flight, {required bool isActive}) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flight,
                color: Color(0xFF3B82F6),
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                '${flight.carrier}${flight.flightNumber}',
                style: AppStyles.textStyle_20_600.copyWith(color: Colors.black),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive 
                      ? _getPhaseColor(flight.currentPhase).withAlpha(25)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  isActive 
                      ? _getPhaseText(flight.currentPhase)
                      : 'Completed',
                  style: AppStyles.textStyle_12_600.copyWith(
                    color: isActive 
                        ? _getPhaseColor(flight.currentPhase)
                        : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Departure',
                      style: AppStyles.textStyle_12_500.copyWith(color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      flight.departureAirport,
                      style: AppStyles.textStyle_16_600.copyWith(color: Colors.black),
                    ),
                    Text(
                      _formatTime(flight.departureTime),
                      style: AppStyles.textStyle_14_400.copyWith(color: Colors.grey[600]),
                    ),
                    if (flight.terminal != null || flight.gate != null) ...[
                      SizedBox(height: 4),
                      Text(
                        '${flight.terminal != null ? 'T${flight.terminal}' : ''}${flight.terminal != null && flight.gate != null ? ' • ' : ''}${flight.gate != null ? 'Gate ${flight.gate}' : ''}',
                        style: AppStyles.textStyle_12_500.copyWith(color: Colors.blue[600]),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward,
                color: Colors.grey[400],
                size: 20,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Arrival',
                      style: AppStyles.textStyle_12_500.copyWith(color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      flight.arrivalAirport,
                      style: AppStyles.textStyle_16_600.copyWith(color: Colors.black),
                    ),
                    Text(
                      _formatTime(flight.arrivalTime),
                      style: AppStyles.textStyle_14_400.copyWith(color: Colors.grey[600]),
                    ),
                    if (flight.flightDuration != null) ...[
                      SizedBox(height: 4),
                      Text(
                        flight.flightDuration!,
                        style: AppStyles.textStyle_12_500.copyWith(color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          
          // Additional flight details
          if (flight.aircraftType != null || flight.seatNumber != null) ...[
            SizedBox(height: 16),
            Row(
              children: [
                if (flight.aircraftType != null) ...[
                  Icon(Icons.flight, size: 16, color: Colors.grey[500]),
                  SizedBox(width: 4),
                  Text(
                    'Aircraft: ${flight.aircraftType}',
                    style: AppStyles.textStyle_12_500.copyWith(color: Colors.grey[600]),
                  ),
                ],
                if (flight.aircraftType != null && flight.seatNumber != null) ...[
                  SizedBox(width: 16),
                ],
                if (flight.seatNumber != null) ...[
                  Icon(Icons.event_seat, size: 16, color: Colors.grey[500]),
                  SizedBox(width: 4),
                  Text(
                    'Seat: ${flight.seatNumber}',
                    style: AppStyles.textStyle_12_500.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildJourneySection(String title, List<JourneyEvent> events, {required bool isActive}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _getSectionIcon(title),
              color: Color(0xFF3B82F6),
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              title,
              style: AppStyles.textStyle_18_600.copyWith(color: Colors.black),
            ),
            Spacer(),
            Icon(
              Icons.keyboard_arrow_up,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
        SizedBox(height: 16),
        ...events.map((event) => JourneyEventCard(
          event: event,
          onFeedbackTap: isActive ? () => _showMicroReviewModal(event) : null,
          isActive: isActive,
        )),
      ],
    );
  }

  List<JourneyEvent> _getPreFlightEvents(FlightTrackingModel flight) {
    final events = <JourneyEvent>[];
    
    // Trip Added - when boarding pass was scanned
    events.add(JourneyEvent(
      id: 'trip_added',
      title: 'Trip Added',
      description: 'Boarding pass scanned successfully',
        timestamp: flight.phaseStartTime ?? DateTime.now(),
      icon: Icons.credit_card,
      hasFeedback: false,
      isCompleted: true,
    ));

    // Check-in Experience
    if (flight.currentPhase.index >= FlightPhase.checkInOpen.index) {
      events.add(JourneyEvent(
        id: 'checkin_experience',
        title: 'Check-in Experience',
        description: 'How was your check-in process?',
        timestamp: flight.phaseStartTime ?? DateTime.now(),
        icon: Icons.business,
        hasFeedback: true,
        isCompleted: flight.currentPhase.index > FlightPhase.checkInOpen.index,
        feedbackType: FeedbackStage.preFlight,
      ));
    }

    // Gate Change (if detected)
    final gateChangeEvent = flight.events.firstWhere(
      (e) => e.eventType == 'GATE_ASSIGNED',
      orElse: () => FlightEvent(
        eventType: '',
        timestamp: DateTime.now(),
        description: '',
      ),
    );
    
    if (gateChangeEvent.eventType.isNotEmpty) {
      events.add(JourneyEvent(
        id: 'gate_change',
        title: 'Gate Change',
        description: gateChangeEvent.description,
        timestamp: gateChangeEvent.timestamp,
        icon: Icons.business,
        hasFeedback: false,
        isCompleted: true,
      ));
    }

    // Boarding Started
    if (flight.currentPhase.index >= FlightPhase.boarding.index) {
      events.add(JourneyEvent(
        id: 'boarding_started',
        title: 'Boarding Started',
        description: 'Now boarding at gate',
        timestamp: flight.phaseStartTime ?? DateTime.now(),
        icon: Icons.flight_takeoff,
        hasFeedback: true,
        isCompleted: flight.currentPhase.index > FlightPhase.boarding.index,
        feedbackType: FeedbackStage.preFlight,
      ));
    }

    return events;
  }

  List<JourneyEvent> _getInFlightEvents(FlightTrackingModel flight) {
    final events = <JourneyEvent>[];
    
    if (flight.currentPhase.index >= FlightPhase.inFlight.index) {
      events.add(JourneyEvent(
        id: 'inflight_experience',
        title: 'In-Flight Experience',
        description: 'How is your flight going?',
        timestamp: flight.phaseStartTime ?? DateTime.now(),
        icon: Icons.flight,
        hasFeedback: true,
        isCompleted: flight.currentPhase.index > FlightPhase.inFlight.index,
        feedbackType: FeedbackStage.inFlight,
      ));
    }

    return events;
  }

  List<JourneyEvent> _getPostFlightEvents(FlightTrackingModel flight) {
    final events = <JourneyEvent>[];
    
    if (flight.currentPhase.index >= FlightPhase.landed.index) {
      events.add(JourneyEvent(
        id: 'postflight_experience',
        title: 'Overall Journey',
        description: 'How was your overall experience?',
        timestamp: flight.phaseStartTime ?? DateTime.now(),
        icon: Icons.flight_land,
        hasFeedback: true,
        isCompleted: flight.currentPhase == FlightPhase.completed,
        feedbackType: FeedbackStage.postFlight,
      ));
    }

    return events;
  }

  void _showMicroReviewModal(JourneyEvent event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MicroReviewModal(
        event: event,
        onSubmitted: (rating, comment) {
          // TODO: Submit feedback to backend
          debugPrint('Feedback submitted: $rating, $comment');
          Navigator.pop(context);
        },
      ),
    );
  }

  IconData _getSectionIcon(String title) {
    switch (title) {
      case 'Pre Flight':
        return Icons.flight_takeoff;
      case 'In Flight':
        return Icons.flight;
      case 'Post Flight':
        return Icons.flight_land;
      default:
        return Icons.timeline;
    }
  }

  Color _getPhaseColor(FlightPhase phase) {
    switch (phase) {
      case FlightPhase.preCheckIn:
        return Colors.grey;
      case FlightPhase.checkInOpen:
        return Colors.blue;
      case FlightPhase.security:
        return Colors.orange;
      case FlightPhase.boarding:
        return Colors.purple;
      case FlightPhase.departed:
        return Colors.indigo;
      case FlightPhase.inFlight:
        return Colors.green;
      case FlightPhase.landed:
        return Colors.teal;
      case FlightPhase.baggageClaim:
        return Colors.cyan;
      case FlightPhase.completed:
        return Colors.green[700]!;
    }
  }

  String _getPhaseText(FlightPhase phase) {
    switch (phase) {
      case FlightPhase.preCheckIn:
        return 'Pre Check-in';
      case FlightPhase.checkInOpen:
        return 'Check-in Open';
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
        return 'Baggage';
      case FlightPhase.completed:
        return 'Completed';
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

