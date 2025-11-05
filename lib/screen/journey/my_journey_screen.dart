import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/flight_tracking_model.dart';
import '../../provider/flight_tracking_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/feedback_checking_service.dart';
import '../../services/cirium_flight_tracking_service.dart';
import '../../utils/app_styles.dart';
import '../../utils/app_routes.dart';
import '../../utils/app_localizations.dart';
import '../app_widgets/main_button.dart';
import '../app_widgets/bottom_nav_bar.dart';
import '../reviewsubmission/wallet_sync_screen.dart';
import '../reviewsubmission/scanner_screen/scanner_screen.dart';
import 'widgets/flight_status_card.dart';
import 'widgets/timeline_section.dart';
import 'widgets/comprehensive_feedback_modal.dart';

class MyJourneyScreen extends ConsumerStatefulWidget {
  const MyJourneyScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MyJourneyScreen> createState() => _MyJourneyScreenState();
}

class _MyJourneyScreenState extends ConsumerState<MyJourneyScreen>
    with SingleTickerProviderStateMixin {
  Map<String, bool> _expandedSections = {
    'At the Airport': true,
    'During the Flight': false,
    'Overall Experience': false,
  };

  late TabController _tabController;
  int _selectedTabIndex = 0;

  // Feedback status tracking
  Map<String, Map<String, bool>> _feedbackStatus = {};
  Map<String, Map<String, Map<String, dynamic>?>> _existingFeedback = {};
  
  // Complete journey loading state
  bool _isCompletingJourney = false;
  
  // Real-time updates
  Timer? _refreshTimer;
  StreamSubscription<FlightTrackingModel>? _flightUpdateSubscription;
  final CiriumFlightTrackingService _ciriumService = CiriumFlightTrackingService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });

    // Sync journeys from database when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncJourneysFromDatabase();
      _startRealTimeUpdates();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    _flightUpdateSubscription?.cancel();
    super.dispose();
  }
  
  /// Start real-time updates for landing time
  void _startRealTimeUpdates() {
    // Listen to flight updates from Cirium service
    // The provider already listens to these updates, but we also listen here
    // to trigger UI refresh when landing time changes
    _flightUpdateSubscription = _ciriumService.flightUpdates.listen((updatedFlight) {
      if (mounted) {
        // The provider will handle the update automatically via its own listener
        // But we trigger a rebuild here to ensure UI updates immediately
        setState(() {});
        debugPrint('🔄 Real-time update received: Landing time may have changed for ${updatedFlight.pnr}');
      }
    });
    
    // Set up periodic refresh every 30 seconds to ensure UI stays updated
    // This is a backup to ensure landing time updates even if stream events are missed
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        // Trigger rebuild to show latest landing times from provider
        setState(() {});
        debugPrint('🔄 Periodic refresh: Checking for landing time updates');
      }
    });
    
    debugPrint('🔄 Started real-time landing time updates');
  }

  @override
  Widget build(BuildContext context) {
    final flightTrackingState = ref.watch(flightTrackingProvider);
    final allFlights = flightTrackingState.getAllFlights();
    final activeFlights = flightTrackingState.trackedFlights.values.toList();
    final completedFlights =
        flightTrackingState.completedFlights.values.toList();

    debugPrint('🎯 Journey Screen: allFlights count: ${allFlights.length}');
    debugPrint(
        '🎯 Journey Screen: activeFlights count: ${activeFlights.length}');
    debugPrint(
        '🎯 Journey Screen: completedFlights count: ${completedFlights.length}');
    if (allFlights.isNotEmpty) {
      debugPrint(
          '🎯 Journey Screen: First flight PNR: ${allFlights.first.pnr}');
      debugPrint(
          '🎯 Journey Screen: First flight carrier: ${allFlights.first.carrier}');
      debugPrint(
          '🎯 Journey Screen: First flight number: ${allFlights.first.flightNumber}');
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'My Journey',
          style: AppStyles.textStyle_20_600.copyWith(color: Colors.black),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: Colors.black),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.settingsscreen);
            },
            tooltip: 'Settings',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.black,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flight_takeoff, size: 20),
                  SizedBox(width: 8),
                  Text('Active (${activeFlights.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 20),
                  SizedBox(width: 8),
                  Text('Completed (${completedFlights.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 1),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Active Journeys Tab
          activeFlights.isEmpty
              ? _buildEmptyState('No Active Journeys',
                  'Connect your flight to start tracking your journey')
              : _buildJourneyList(activeFlights),

          // Completed Journeys Tab
          completedFlights.isEmpty
              ? _buildEmptyState('No Completed Journeys',
                  'Your completed journeys will appear here')
              : _buildCompletedJourneyList(completedFlights),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              title.contains('Active') ? Icons.flight_takeoff : Icons.history,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 24),
            Text(
              title,
              style:
                  AppStyles.textStyle_24_600.copyWith(color: Colors.grey[600]),
            ),
            SizedBox(height: 12),
            Text(
              subtitle,
              style:
                  AppStyles.textStyle_16_400.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            if (title.contains('Active')) ...[
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
                  style:
                      AppStyles.textStyle_16_600.copyWith(color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildJourneyList(List<FlightTrackingModel> flights) {
    return SingleChildScrollView(
      child: Column(
        children:
            flights.map((flight) => _buildJourneyTimeline(flight)).toList(),
      ),
    );
  }

  Widget _buildCompletedJourneyList(List<FlightTrackingModel> flights) {
    return SingleChildScrollView(
      child: Column(
        children: flights
            .map((flight) => _buildCompletedJourneyCard(flight))
            .toList(),
      ),
    );
  }

  Widget _buildCompletedJourneyCard(FlightTrackingModel flight) {
    final journeyId = flight.journeyId;
    final feedbackPercentage =
        journeyId != null ? getFeedbackCompletionPercentage(journeyId) : 0;
    final hasAnyFeedback = journeyId != null
        ? _feedbackStatus[journeyId]
                ?.values
                .any((hasFeedback) => hasFeedback) ??
            false
        : false;

    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          // Header
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${flight.carrier}${flight.flightNumber}',
                        style: AppStyles.textStyle_18_600
                            .copyWith(color: Colors.black),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${flight.departureAirport} → ${flight.arrivalAirport}',
                        style: AppStyles.textStyle_14_500
                            .copyWith(color: Colors.grey[600]),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'PNR: ${flight.pnr}',
                        style: AppStyles.textStyle_12_500
                            .copyWith(color: Colors.grey[500]),
                      ),
                      if (hasAnyFeedback) ...[
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.feedback,
                              size: 16,
                              color: Colors.blue,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Feedback: $feedbackPercentage% Complete',
                              style: AppStyles.textStyle_12_500
                                  .copyWith(color: Colors.blue),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Completed',
                    style: AppStyles.textStyle_12_600
                        .copyWith(color: Colors.green),
                  ),
                ),
              ],
            ),
          ),

          // Flight Details
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Departure',
                        style: AppStyles.textStyle_12_500
                            .copyWith(color: Colors.grey[500]),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _formatDateTime(flight.departureTime),
                        style: AppStyles.textStyle_14_600
                            .copyWith(color: Colors.black),
                      ),
                      Text(
                        flight.departureAirport,
                        style: AppStyles.textStyle_12_500
                            .copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey[300],
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Arrival',
                        style: AppStyles.textStyle_12_500
                            .copyWith(color: Colors.grey[500]),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _formatDateTime(flight.arrivalTime),
                        style: AppStyles.textStyle_14_600
                            .copyWith(color: Colors.black),
                      ),
                      Text(
                        flight.arrivalAirport,
                        style: AppStyles.textStyle_12_500
                            .copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 20),

          // Action Buttons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _showJourneyDetails(flight);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'View Details',
                      style: AppStyles.textStyle_14_500
                          .copyWith(color: Colors.grey[700]),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // Only show button if feedback exists (Rate Experience is commented out)
                if (hasAnyFeedback)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Show read-only view of submitted feedback
                        _showReadOnlyFeedback(flight);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'View Feedback',
                        style: AppStyles.textStyle_14_600
                            .copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                
                /* 
                // COMMENTED OUT: Rate Experience functionality
                // Uncomment this to allow users to rate completed journeys without feedback
                if (!hasAnyFeedback)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Allow rating for first time
                        _showFeedbackForCompletedJourney(flight);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Rate Experience',
                        style: AppStyles.textStyle_14_600
                            .copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                */
              ],
            ),
          ),

          SizedBox(height: 20),
        ],
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
            flight: flight,
          ),

          TimelineSection(
            title: 'During the Flight',
            icon: Icons.flight,
            events: _getInFlightEvents(flight),
            isExpanded: _expandedSections['During the Flight']!,
            onToggle: () => _toggleSection('During the Flight'),
            flight: flight,
          ),

          TimelineSection(
            title: 'Overall Experience',
            icon: Icons.star,
            events: _getPostFlightEvents(flight),
            isExpanded: _expandedSections['Overall Experience']!,
            onToggle: () => _toggleSection('Overall Experience'),
            flight: flight,
          ),

          SizedBox(height: 32),

          // Complete Journey Button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Builder(
              builder: (context) {
                final canComplete = _canCompleteJourney(flight);
                final isEnabled = canComplete && !_isCompletingJourney;
                
                return ElevatedButton(
                  onPressed: isEnabled
                      ? () async {
                          await _completeJourney();
                        }
                      : canComplete
                          ? null  // Disabled while loading
                          : () {
                              _showCannotCompleteDialog(context, flight);
                            },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEnabled 
                        ? Colors.black 
                        : Colors.grey[400],
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isCompletingJourney
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Completing...',
                              style: AppStyles.textStyle_16_600
                                  .copyWith(color: Colors.white),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              canComplete ? Icons.check_circle : Icons.schedule,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Complete Journey',
                              style: AppStyles.textStyle_16_600
                                  .copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                );
              },
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

    // Trip Added - Use created_at from journey, convert to local time
    final tripAddedTime = flight.phaseStartTime;
    final localTripTime = tripAddedTime != null 
        ? (tripAddedTime.isUtc ? tripAddedTime.toLocal() : tripAddedTime)
        : DateTime.now();
    
    events.add(TimelineEvent(
      id: 'trip_added',
      title: 'Trip Added',
      description: 'Boarding pass scanned successfully',
      timestamp: localTripTime,
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
      // Get gate from flight data, fallback to events, then default
      String gate = flight.gate ?? '';
      if (gate.isEmpty) {
        final gateEvent = flight.events.firstWhere(
          (e) => e.eventType == 'GATE_ASSIGNED' && e.metadata?['gate'] != null,
          orElse: () => FlightEvent(eventType: '', timestamp: DateTime.now(), description: ''),
        );
        gate = gateEvent.metadata?['gate']?.toString() ?? '';
      }
      
      final gateDisplay = gate.isNotEmpty ? 'Gate $gate' : 'Gate';
      events.add(TimelineEvent(
        id: 'boarding_started',
        title: 'Boarding',
        description: 'Now boarding at $gateDisplay',
        timestamp: flight.phaseStartTime ??
            DateTime.now().subtract(Duration(hours: 1)),
        icon: Icons.flight_takeoff,
        location: gateDisplay,
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

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    return '$hour:$minute\n$day/$month';
  }

  void _showJourneyDetails(FlightTrackingModel flight) {
    // Simple AlertDialog - Old Version (Currently in use)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Journey Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Flight', '${flight.carrier}${flight.flightNumber}'),
              _buildDetailRow('Route', '${flight.departureAirport} → ${flight.arrivalAirport}'),
              _buildDetailRow('PNR', flight.pnr),
              _buildDetailRow('Departure', _formatDateTime(flight.departureTime)),
              _buildDetailRow('Arrival', _formatDateTime(flight.arrivalTime)),
              if (flight.seatNumber != null)
                _buildDetailRow('Seat', flight.seatNumber!),
              if (flight.gate != null)
                _buildDetailRow('Gate', flight.gate!),
              if (flight.terminal != null)
                _buildDetailRow('Terminal', flight.terminal!),
              _buildDetailRow('Status', 'Completed'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
    
    /* MODERN MODAL VERSION - COMMENTED OUT FOR NOW
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.flight_takeoff,
                      color: Colors.green,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Journey Details',
                          style: AppStyles.textStyle_24_600,
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${flight.carrier}${flight.flightNumber}',
                          style: AppStyles.textStyle_16_600.copyWith(
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Completed',
                      style: AppStyles.textStyle_12_600
                          .copyWith(color: Colors.green),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 24),
              
              // Flight Route Section
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.blue.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'From',
                                style: AppStyles.textStyle_12_500
                                    .copyWith(color: Colors.grey[600]),
                              ),
                              SizedBox(height: 4),
                              Text(
                                flight.departureAirport,
                                style: AppStyles.textStyle_20_600
                                    .copyWith(color: Colors.blue[900]),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _formatDateTimeFull(flight.departureTime),
                                style: AppStyles.textStyle_12_500
                                    .copyWith(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward,
                            color: Colors.blue,
                            size: 24,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'To',
                                style: AppStyles.textStyle_12_500
                                    .copyWith(color: Colors.grey[600]),
                              ),
                              SizedBox(height: 4),
                              Text(
                                flight.arrivalAirport,
                                style: AppStyles.textStyle_20_600
                                    .copyWith(color: Colors.blue[900]),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _formatDateTimeFull(flight.arrivalTime),
                                style: AppStyles.textStyle_12_500
                                    .copyWith(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 24),
              
              // Details Grid
              _buildModernDetailCard(
                'PNR',
                flight.pnr,
                Icons.confirmation_number,
                Colors.purple,
              ),
              
              SizedBox(height: 12),
              
              Row(
                children: [
                  if (flight.seatNumber != null)
                    Expanded(
                      child: _buildModernDetailCard(
                        'Seat',
                        flight.seatNumber!,
                        Icons.event_seat,
                        Colors.orange,
                      ),
                    ),
                  if (flight.seatNumber != null && flight.gate != null)
                    SizedBox(width: 12),
                  if (flight.gate != null)
                    Expanded(
                      child: _buildModernDetailCard(
                        'Gate',
                        flight.gate!,
                        Icons.door_front_door,
                        Colors.teal,
                      ),
                    ),
                ],
              ),
              
              if (flight.terminal != null) ...[
                SizedBox(height: 12),
                _buildModernDetailCard(
                  'Terminal',
                  flight.terminal!,
                  Icons.location_city,
                  Colors.indigo,
                ),
              ],
              
              SizedBox(height: 24),
              
              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Close',
                    style: AppStyles.textStyle_16_600
                        .copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    */
  }
  
  /* COMMENTED OUT - Modern Modal Helper Functions
  /// Build modern detail card
  Widget _buildModernDetailCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppStyles.textStyle_12_500
                      .copyWith(color: Colors.grey[600]),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: AppStyles.textStyle_16_600.copyWith(color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// Format date time for display (full format)
  String _formatDateTimeFull(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    return '$hour:$minute • $day/$month/$year';
  }
  */

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style:
                  AppStyles.textStyle_14_500.copyWith(color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppStyles.textStyle_14_500.copyWith(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  void _showFeedbackForCompletedJourney(FlightTrackingModel flight) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ComprehensiveFeedbackModal(
        flight: flight,
        onSubmitted: () {
          Navigator.pop(context);
          // Reload feedback status
          if (flight.journeyId != null) {
            _loadFeedbackStatusForFlight(flight.journeyId!);
          }
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Thank you for your feedback!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  /// Show read-only feedback view for completed journeys
  void _showReadOnlyFeedback(FlightTrackingModel flight) {
    if (flight.journeyId == null) return;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Feedback',
                  style: AppStyles.textStyle_24_600,
                ),
                Icon(Icons.check_circle, color: Colors.green, size: 28),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Thank you for sharing your experience!',
              style: AppStyles.textStyle_14_500.copyWith(
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),

            // Airport Review (Pre-flight experience)
            _buildReadOnlyFeedbackCard(
              flight,
              'Airport Review',
              'airport_review',
              flight.journeyId!,
              Icons.location_city,
              Colors.teal,
            ),

            SizedBox(height: 12),

            // Airline Review (In-flight experience)
            _buildReadOnlyFeedbackCard(
              flight,
              'Airline Review',
              'airline_review',
              flight.journeyId!,
              Icons.airplanemode_active,
              Colors.green,
            ),

            SizedBox(height: 12),

            // Overall Experience (from feedback table)
            _buildReadOnlyFeedbackCard(
              flight,
              'Overall Experience',
              'overall',
              flight.journeyId!,
              Icons.star,
              Colors.purple,
            ),

            SizedBox(height: 24),

            // Overall completion status
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Feedback Completed: ${getFeedbackCompletionPercentage(flight.journeyId!)}%',
                      style: AppStyles.textStyle_14_600
                          .copyWith(color: Colors.green[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Deprecated: Old management function (replaced with read-only view)
  @deprecated
  void _showFeedbackManagement(FlightTrackingModel flight) {
    // This function is no longer used for completed journeys
    // Completed journeys now show read-only feedback via _showReadOnlyFeedback
    _showReadOnlyFeedback(flight);
  }

  /// Build read-only feedback card (no editing allowed)
  Widget _buildReadOnlyFeedbackCard(FlightTrackingModel flight, String title,
      String stage, String journeyId, IconData icon, Color color) {
    final hasFeedback = hasFeedbackForStage(journeyId, stage);
    final existingFeedback = getExistingFeedbackForStage(journeyId, stage);

    return Container(
      decoration: BoxDecoration(
        color: hasFeedback ? color.withOpacity(0.1) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasFeedback ? color : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: hasFeedback ? color : Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            hasFeedback ? Icons.check_circle : icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: AppStyles.textStyle_16_600.copyWith(
            color: hasFeedback ? color : Colors.grey[700],
          ),
        ),
        subtitle: Text(
          hasFeedback
              ? _getFeedbackSummary(existingFeedback)
              : 'No feedback submitted',
          style: AppStyles.textStyle_14_500.copyWith(
            color: hasFeedback ? Colors.grey[700] : Colors.grey[500],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: hasFeedback
            ? Icon(Icons.visibility, size: 20, color: color)
            : null,
        onTap: hasFeedback
            ? () {
                // Show detailed read-only view in a dialog
                _showDetailedFeedbackDialog(title, existingFeedback, color);
              }
            : null,
      ),
    );
  }

  /// Get a summary of the feedback for display
  String _getFeedbackSummary(Map<String, dynamic>? feedback) {
    if (feedback == null) return 'No feedback submitted';

    // Show rating if available
    if (feedback['overall_rating'] != null) {
      final rating = feedback['overall_rating'];
      return '⭐ ${rating}/5 rating';
    }

    // Show score if available
    if (feedback['score'] != null) {
      final score = feedback['score'];
      return '⭐ ${score}/5 rating';
    }

    // Show comment preview if available
    if (feedback['comments'] != null && feedback['comments'].isNotEmpty) {
      return feedback['comments'].toString().split('\n').first;
    }

    return 'Feedback submitted';
  }

  /// Show detailed feedback in a dialog (read-only)
  void _showDetailedFeedbackDialog(
      String title, Map<String, dynamic>? feedback, Color color) {
    if (feedback == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.feedback, color: color, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: AppStyles.textStyle_20_600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                
                // Rating
                if (feedback['overall_rating'] != null ||
                    feedback['score'] != null) ...[
                  Text(
                    'Rating',
                    style: AppStyles.textStyle_14_600.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (index) {
                      final rating = (feedback['overall_rating'] ??
                              feedback['score'] ??
                              0)
                          .toInt();
                      return Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 28,
                      );
                    }),
                  ),
                  SizedBox(height: 16),
                ],

                // Comments
                if (feedback['comments'] != null &&
                    feedback['comments'].isNotEmpty) ...[
                  Text(
                    'Comments',
                    style: AppStyles.textStyle_14_600.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      feedback['comments'].toString(),
                      style: AppStyles.textStyle_14_400,
                    ),
                  ),
                  SizedBox(height: 16),
                ],

                // Submitted date
                if (feedback['created_at'] != null) ...[
                  Text(
                    'Submitted',
                    style: AppStyles.textStyle_14_600.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _formatFeedbackDate(feedback['created_at']),
                    style: AppStyles.textStyle_14_400.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 16),
                ],

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: AppStyles.textStyle_14_600
                          .copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Format feedback date for display
  String _formatFeedbackDate(dynamic dateValue) {
    try {
      final date = dateValue is DateTime
          ? dateValue
          : DateTime.parse(dateValue.toString());
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  /// Deprecated: Old editable feedback card
  @deprecated
  Widget _buildFeedbackStageCard(FlightTrackingModel flight, String title,
      String stage, String journeyId, IconData icon, Color color) {
    // This function is deprecated - use _buildReadOnlyFeedbackCard instead
    return _buildReadOnlyFeedbackCard(flight, title, stage, journeyId, icon, color);
  }

  void _showFeedbackForStage(FlightTrackingModel flight, String stage,
      Map<String, dynamic>? existingFeedback) {
    if (stage == 'airline_review') {
      // Navigate to airline review screen
      Navigator.pushNamed(
        context,
        AppRoutes.questionfirstscreenforairline,
        arguments: {
          'flight': flight,
          'existingFeedback': existingFeedback,
        },
      );
    } else if (stage == 'airport_review') {
      // Navigate to airport review screen
      Navigator.pushNamed(
        context,
        AppRoutes.questionfirstscreenforairport,
        arguments: {
          'flight': flight,
          'existingFeedback': existingFeedback,
        },
      );
    } else {
      // Use comprehensive feedback modal for stage feedback
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ComprehensiveFeedbackModal(
          flight: flight,
          onSubmitted: () {
            Navigator.pop(context);
            // Reload feedback status
            if (flight.journeyId != null) {
              _loadFeedbackStatusForFlight(flight.journeyId!);
            }
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Feedback ${existingFeedback != null ? 'updated' : 'submitted'} successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      );
    }
  }

  /// Sync journeys from database based on current user
  Future<void> _syncJourneysFromDatabase() async {
    try {
      // Get current user ID
      final session = SupabaseService.client.auth.currentSession;
      if (session?.user.id == null) {
        debugPrint('❌ No authenticated user found for journey sync');
        return;
      }

      final userId = session!.user.id;
      debugPrint('🔄 Syncing journeys for user: $userId');

      // Sync journeys from database
      await ref
          .read(flightTrackingProvider.notifier)
          .syncJourneysFromDatabase(userId);

      // Load feedback status for completed flights
      await _loadFeedbackStatusForCompletedFlights();

      debugPrint('✅ Journey sync completed');
    } catch (e) {
      debugPrint('❌ Error syncing journeys from database: $e');
    }
  }

  /// Load feedback status for all completed flights
  Future<void> _loadFeedbackStatusForCompletedFlights() async {
    try {
      final flightTrackingState = ref.read(flightTrackingProvider);
      final completedFlights =
          flightTrackingState.completedFlights.values.toList();

      for (final flight in completedFlights) {
        if (flight.journeyId != null) {
          await _loadFeedbackStatusForFlight(flight.journeyId!);
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading feedback status: $e');
    }
  }

  /// Load feedback status for a specific flight
  Future<void> _loadFeedbackStatusForFlight(String journeyId) async {
    try {
      // Check feedback status
      final feedbackStatus =
          await FeedbackCheckingService.checkFeedbackStatus(journeyId);
      _feedbackStatus[journeyId] = feedbackStatus;

      // Load existing feedback for all stages
      final allFeedback =
          await FeedbackCheckingService.getAllFeedbackForJourney(journeyId);
      _existingFeedback[journeyId] = allFeedback;

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('❌ Error loading feedback for journey $journeyId: $e');
    }
  }

  /// Get feedback status for a specific flight and stage
  bool hasFeedbackForStage(String journeyId, String stage) {
    return _feedbackStatus[journeyId]?[stage] ?? false;
  }

  /// Get existing feedback for a specific flight and stage
  Map<String, dynamic>? getExistingFeedbackForStage(
      String journeyId, String stage) {
    return _existingFeedback[journeyId]?[stage];
  }

  /// Get feedback completion percentage for a flight
  int getFeedbackCompletionPercentage(String journeyId) {
    final status = _feedbackStatus[journeyId];
    if (status == null) return 0;

    final completedStages =
        status.values.where((hasFeedback) => hasFeedback).length;
    final totalStages = status.length;

    return ((completedStages / totalStages) * 100).round();
  }

  /// Check if journey can be completed (flight has landed)
  bool _canCompleteJourney(FlightTrackingModel flight) {
    final now = DateTime.now();
    return flight.arrivalTime.isBefore(now);
  }

  /// Show dialog when user tries to complete journey before flight lands
  void _showCannotCompleteDialog(BuildContext context, FlightTrackingModel flight) {
    final timeUntilArrival = flight.arrivalTime.difference(DateTime.now());
    final hours = timeUntilArrival.inHours;
    final minutes = timeUntilArrival.inMinutes % 60;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Flight Not Landed Yet'),
        content: Text(
          flight.arrivalTime.isBefore(DateTime.now())
              ? 'This flight has already landed. You can complete your journey.'
              : timeUntilArrival.inDays > 0
                  ? 'Please wait until your flight lands to complete your journey.\n\nExpected arrival: ${flight.arrivalTime.toString().split('.')[0]}\nEstimated time: ${timeUntilArrival.inDays} days, $hours hours'
                  : 'Please wait until your flight lands to complete your journey.\n\nExpected arrival: ${flight.arrivalTime.toString().split('.')[0]}\nEstimated time: $hours hours, $minutes minutes',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Complete the journey by updating its status
  Future<void> _completeJourney() async {
    // Set loading state
    setState(() {
      _isCompletingJourney = true;
    });

    try {
      final flightTrackingState = ref.read(flightTrackingProvider);
      final trackedFlights = flightTrackingState.trackedFlights.values.toList();
      
      if (trackedFlights.isEmpty) {
        debugPrint('❌ No tracked flights to complete');
        return;
      }

      final flight = trackedFlights.first;
      final journeyId = flight.journeyId;
      
      if (journeyId == null) {
        debugPrint('❌ No journey ID found for flight');
        return;
      }

      debugPrint('🔄 Completing journey: $journeyId');

      // Check if user can complete the journey based on flight arrival time
      final now = DateTime.now();
      if (!flight.arrivalTime.isBefore(now)) {
        debugPrint('⚠️ Flight has not landed yet');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Flight has not landed yet. Please wait until arrival.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Mark journey as completed using helper method with fallback strategies
      // This handles schema errors gracefully by trying multiple update strategies
      try {
        // Log the exact update we're attempting
        debugPrint('📝 Attempting to mark journey $journeyId as completed');
        
        // Use the helper method with fallback strategies to handle schema errors
        final success = await SupabaseService.markJourneyAsCompleted(
          journeyId: journeyId,
          flightId: flight.flightId,
          addEvent: true,
        );
        
        if (!success) {
          throw Exception('Failed to mark journey as completed');
        }
        
        debugPrint('✅ Journey marked as completed: $journeyId');

        // Sync journeys from database to update UI
        // This will reload all journeys and properly separate active from completed
        await _syncJourneysFromDatabase();

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Journey completed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Switch to completed tab to show the newly completed journey
          _tabController.animateTo(1);
        }
      } catch (updateError) {
        debugPrint('❌ Failed to update journey phase: $updateError');
        
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to complete journey. Please try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error completing journey: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete journey. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Reset loading state
      if (mounted) {
        setState(() {
          _isCompletingJourney = false;
        });
      }
    }
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
              icon:
                  const Icon(Icons.account_balance_wallet, color: Colors.white),
            ),
            const SizedBox(height: 12),
            MainButton(
              text:
                  AppLocalizations.of(context).translate('Scan Boarding Pass'),
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
