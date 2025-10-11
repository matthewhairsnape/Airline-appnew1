import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/flight_tracking_model.dart';
import '../../models/stage_feedback_model.dart';
import '../../provider/flight_tracking_provider.dart';
import '../../provider/stage_feedback_provider.dart';
import '../../utils/app_styles.dart';
import '../../utils/app_routes.dart';
import '../../utils/app_localizations.dart';
import '../app_widgets/main_button.dart';
import '../reviewsubmission/wallet_sync_screen.dart';
import '../reviewsubmission/scanner_screen/scanner_screen.dart';
import 'widgets/flight_status_card.dart';
import 'widgets/timeline_section.dart';
import 'widgets/timeline_event_card.dart';
import 'widgets/micro_review_modal.dart';
import 'widgets/comprehensive_feedback_modal.dart';

class MyJourneyScreen extends ConsumerStatefulWidget {
  const MyJourneyScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MyJourneyScreen> createState() => _MyJourneyScreenState();
}

class _MyJourneyScreenState extends ConsumerState<MyJourneyScreen> {
  Map<String, bool> _expandedSections = {
    'At the Airport': true,
    'During the Flight': false,
    'Overall Experience': false,
  };

  @override
  Widget build(BuildContext context) {
    final flightTrackingState = ref.watch(flightTrackingProvider);
    final allFlights = flightTrackingState.getAllFlights();
    final activeFlights = flightTrackingState.trackedFlights.values.toList();
    final completedFlights = flightTrackingState.completedFlights.values.toList();
    
    debugPrint('🎯 Journey Screen: allFlights count: ${allFlights.length}');
    debugPrint('🎯 Journey Screen: activeFlights count: ${activeFlights.length}');
    debugPrint('🎯 Journey Screen: completedFlights count: ${completedFlights.length}');
    if (allFlights.isNotEmpty) {
      debugPrint('🎯 Journey Screen: First flight PNR: ${allFlights.first.pnr}');
      debugPrint('🎯 Journey Screen: First flight carrier: ${allFlights.first.carrier}');
      debugPrint('🎯 Journey Screen: First flight number: ${allFlights.first.flightNumber}');
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.startreviews),
        ),
        title: Text(
          'Journey Timeline',
          style: AppStyles.textStyle_20_600.copyWith(color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: allFlights.isEmpty
          ? _buildEmptyState()
          : _buildJourneyTimeline(allFlights.first),
      // Remove the bottom feedback button - feedback is now in each section
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
              'Connect your flight to start tracking your journey',
              style: AppStyles.textStyle_16_400.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                _showSyncOptionsModal(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
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
            title: 'At the Airport',
            icon: Icons.assignment,
            events: _getPreFlightEvents(flight),
            isExpanded: _expandedSections['At the Airport']!,
            onToggle: () => _toggleSection('At the Airport'),
          ),
          
          TimelineSection(
            title: 'During the Flight',
            icon: Icons.flight,
            events: _getInFlightEvents(flight),
            isExpanded: _expandedSections['During the Flight']!,
            onToggle: () => _toggleSection('During the Flight'),
          ),
          
          TimelineSection(
            title: 'Overall Experience',
            icon: Icons.star,
            events: _getPostFlightEvents(flight),
            isExpanded: _expandedSections['Overall Experience']!,
            onToggle: () => _toggleSection('Overall Experience'),
          ),
          
          SizedBox(height: 32),
          
          // Complete Journey Button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: ElevatedButton(
              onPressed: () {
                ref.refresh(flightTrackingProvider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Complete Journey',
                    style: AppStyles.textStyle_16_600.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 100), // Space for bottom padding
        ],
      ),
    );
  }

  // Feedback button removed - now handled by individual timeline sections

  void _toggleSection(String section) {
    setState(() {
      _expandedSections[section] = !_expandedSections[section]!;
    });
  }

  // Feedback modal removed - now handled by individual timeline sections

  List<TimelineEvent> _getPreFlightEvents(FlightTrackingModel flight) {
    final events = <TimelineEvent>[];
    
    // Trip Added
    events.add(TimelineEvent(
      id: 'trip_added',
      title: 'Trip Added',
      description: 'Boarding pass scanned successfully',
      timestamp: flight.phaseStartTime ?? DateTime.now().subtract(Duration(hours: 2)),
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
        timestamp: flight.phaseStartTime ?? DateTime.now().subtract(Duration(hours: 1)),
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

  void _showSyncOptionsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppLocalizations.of(context).translate('Choose Sync Option'),
              style: AppStyles.textStyle_24_600,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            MainButton(
              text: AppLocalizations.of(context)
                  .translate('Sync from Your Wallet'),
              color: Colors.black,
              onPressed: () {
                Navigator.pop(context);
                showWalletSyncDialog(context);
              },
              icon: const Icon(Icons.account_balance_wallet, color: Colors.white),
            ),
            const SizedBox(height: 12),
            MainButton(
              text: AppLocalizations.of(context)
                  .translate('Scan Boarding Pass'),
              color: Colors.black,
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ScannerScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
