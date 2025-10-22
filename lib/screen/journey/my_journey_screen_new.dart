import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/flight_tracking_model.dart';
import '../../models/stage_feedback_model.dart';
import '../../provider/flight_tracking_provider.dart';
import '../../provider/stage_feedback_provider.dart';
import '../../utils/app_styles.dart';
import '../../utils/app_routes.dart';
import '../app_widgets/main_button.dart';
import 'widgets/flight_status_card.dart';
import 'widgets/timeline_section.dart';
import 'widgets/timeline_event_card.dart';
import 'widgets/micro_review_modal.dart';

class MyJourneyScreen extends ConsumerStatefulWidget {
  const MyJourneyScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MyJourneyScreen> createState() => _MyJourneyScreenState();
}

class _MyJourneyScreenState extends ConsumerState<MyJourneyScreen> {
  Map<String, bool> _expandedSections = {
    'Pre Flight': true,
    'In Flight': false,
    'Post Flight': false,
  };

  @override
  Widget build(BuildContext context) {
    final flightTrackingState = ref.watch(flightTrackingProvider);
    final allFlights = flightTrackingState.getAllFlights();
    final activeFlights = flightTrackingState.trackedFlights.values.toList();
    final completedFlights =
        flightTrackingState.completedFlights.values.toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Journey Timeline',
          style: AppStyles.textStyle_20_600.copyWith(color: Colors.black),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              ref.refresh(flightTrackingProvider);
            },
          ),
        ],
      ),
      body: allFlights.isEmpty
          ? _buildEmptyState()
          : _buildJourneyTimeline(allFlights.first),
      bottomNavigationBar:
          allFlights.isNotEmpty ? _buildFeedbackButton(allFlights.first) : null,
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
              style:
                  AppStyles.textStyle_24_600.copyWith(color: Colors.grey[600]),
            ),
            SizedBox(height: 12),
            Text(
              'Connect your flight to start tracking your journey',
              style:
                  AppStyles.textStyle_16_500.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.reviewsubmissionscreen);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF3B82F6),
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Connect Flight',
                style: AppStyles.textStyle_16_600.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJourneyTimeline(FlightTrackingModel flight) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Flight Status Card
          FlightStatusCard(flight: flight),

          // Timeline Sections
          TimelineSection(
            title: 'Pre Flight',
            icon: Icons.assignment,
            events: _getPreFlightEvents(flight),
            isExpanded: _expandedSections['Pre Flight']!,
            onToggle: () => _toggleSection('Pre Flight'),
          ),

          TimelineSection(
            title: 'In Flight',
            icon: Icons.flight,
            events: _getInFlightEvents(flight),
            isExpanded: _expandedSections['In Flight']!,
            onToggle: () => _toggleSection('In Flight'),
          ),

          TimelineSection(
            title: 'Post Flight',
            icon: Icons.star,
            events: _getPostFlightEvents(flight),
            isExpanded: _expandedSections['Post Flight']!,
            onToggle: () => _toggleSection('Post Flight'),
          ),

          SizedBox(height: 100), // Space for bottom button
        ],
      ),
    );
  }

  Widget _buildFeedbackButton(FlightTrackingModel flight) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: () => _showFeedbackModal(flight),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFEF4444), // Red
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Text(
            'Give Live Feedback',
            style: AppStyles.textStyle_16_600.copyWith(
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  void _toggleSection(String section) {
    setState(() {
      _expandedSections[section] = !_expandedSections[section]!;
    });
  }

  void _showFeedbackModal(FlightTrackingModel flight) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MicroReviewModal(
        event: JourneyEvent(
          id: 'overall_feedback',
          eventType: 'OVERALL_FEEDBACK',
          timestamp: DateTime.now(),
          description: 'Overall flight experience',
          metadata: {},
        ),
        onSubmitted: (rating, comment) {
          // TODO: Submit feedback to backend
          debugPrint('Feedback submitted: $rating, $comment');
          Navigator.pop(context);
        },
      ),
    );
  }

  List<TimelineEvent> _getPreFlightEvents(FlightTrackingModel flight) {
    final events = <TimelineEvent>[];

    // Trip Added
    events.add(TimelineEvent(
      id: 'trip_added',
      title: 'Trip Added',
      description: 'Boarding pass scanned successfully',
      timestamp:
          flight.phaseStartTime ?? DateTime.now().subtract(Duration(hours: 2)),
      icon: Icons.phone_android,
      isCompleted: true,
    ));

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
      events.add(TimelineEvent(
        id: 'gate_change',
        title: 'Gate Change',
        description: gateChangeEvent.description,
        timestamp: gateChangeEvent.timestamp,
        icon: Icons.business,
        location: '9-min walk',
        isCompleted: true,
      ));
    }

    // Boarding Started
    if (flight.currentPhase.index >= FlightPhase.boarding.index) {
      events.add(TimelineEvent(
        id: 'boarding_started',
        title: 'Boarding',
        description: 'Now boarding at Gate D18',
        timestamp: flight.phaseStartTime ??
            DateTime.now().subtract(Duration(hours: 1)),
        icon: Icons.flight_takeoff,
        location: 'Gate D18',
        isCompleted: flight.currentPhase.index > FlightPhase.boarding.index,
      ));
    }

    return events;
  }

  List<TimelineEvent> _getInFlightEvents(FlightTrackingModel flight) {
    final events = <TimelineEvent>[];

    if (flight.currentPhase.index >= FlightPhase.inFlight.index) {
      events.add(TimelineEvent(
        id: 'inflight_experience',
        title: 'In-Flight Experience',
        description: 'How is your flight going?',
        timestamp: flight.phaseStartTime ?? DateTime.now(),
        icon: Icons.flight,
        isCompleted: flight.currentPhase.index > FlightPhase.inFlight.index,
        hasFeedback: true,
      ));
    }

    return events;
  }

  List<TimelineEvent> _getPostFlightEvents(FlightTrackingModel flight) {
    final events = <TimelineEvent>[];

    if (flight.currentPhase.index >= FlightPhase.landed.index) {
      events.add(TimelineEvent(
        id: 'postflight_experience',
        title: 'Overall Journey',
        description: 'How was your overall experience?',
        timestamp: flight.phaseStartTime ?? DateTime.now(),
        icon: Icons.flight_land,
        isCompleted: flight.currentPhase == FlightPhase.completed,
        hasFeedback: true,
      ));
    }

    return events;
  }
}
