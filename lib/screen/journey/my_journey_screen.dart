import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/flight_tracking_model.dart';
import '../../provider/flight_tracking_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/feedback_checking_service.dart';
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
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (hasAnyFeedback) {
                        _showFeedbackManagement(flight);
                      } else {
                        _showFeedbackForCompletedJourney(flight);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          hasAnyFeedback ? Colors.blue : Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      hasAnyFeedback ? 'Manage Feedback' : 'Rate Experience',
                      style: AppStyles.textStyle_14_600
                          .copyWith(color: Colors.white),
                    ),
                  ),
                ),
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
                    style: AppStyles.textStyle_16_600
                        .copyWith(color: Colors.white),
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

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    return '$hour:$minute\n$day/$month';
  }

  void _showJourneyDetails(FlightTrackingModel flight) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Journey Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
                'Flight', '${flight.carrier}${flight.flightNumber}'),
            _buildDetailRow('Route',
                '${flight.departureAirport} → ${flight.arrivalAirport}'),
            _buildDetailRow('PNR', flight.pnr),
            _buildDetailRow('Departure', _formatDateTime(flight.departureTime)),
            _buildDetailRow('Arrival', _formatDateTime(flight.arrivalTime)),
            if (flight.seatNumber != null)
              _buildDetailRow('Seat', flight.seatNumber!),
            if (flight.gate != null) _buildDetailRow('Gate', flight.gate!),
            if (flight.terminal != null)
              _buildDetailRow('Terminal', flight.terminal!),
            _buildDetailRow('Status', 'Completed'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

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

  void _showFeedbackManagement(FlightTrackingModel flight) {
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
            Text(
              'Manage Feedback',
              style: AppStyles.textStyle_24_600,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),

            // Pre-flight feedback
            _buildFeedbackStageCard(
              flight,
              'Pre-Flight Experience',
              'pre_flight',
              flight.journeyId!,
              Icons.assignment,
              Colors.blue,
            ),

            SizedBox(height: 12),

            // In-flight feedback
            _buildFeedbackStageCard(
              flight,
              'In-Flight Experience',
              'in_flight',
              flight.journeyId!,
              Icons.flight,
              Colors.orange,
            ),

            SizedBox(height: 12),

            // Post-flight feedback
            _buildFeedbackStageCard(
              flight,
              'Overall Experience',
              'post_flight',
              flight.journeyId!,
              Icons.star,
              Colors.purple,
            ),

            SizedBox(height: 12),

            // Airline review
            _buildFeedbackStageCard(
              flight,
              'Airline Review',
              'airline_review',
              flight.journeyId!,
              Icons.airplanemode_active,
              Colors.green,
            ),

            SizedBox(height: 12),

            // Airport review
            _buildFeedbackStageCard(
              flight,
              'Airport Review',
              'airport_review',
              flight.journeyId!,
              Icons.location_city,
              Colors.teal,
            ),

            SizedBox(height: 24),

            // Overall completion status
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Feedback Completion: ${getFeedbackCompletionPercentage(flight.journeyId!)}%',
                      style: AppStyles.textStyle_14_500
                          .copyWith(color: Colors.grey[700]),
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

  Widget _buildFeedbackStageCard(FlightTrackingModel flight, String title,
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
            hasFeedback ? Icons.check : icon,
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
          hasFeedback ? 'Feedback submitted' : 'No feedback yet',
          style: AppStyles.textStyle_14_500.copyWith(
            color: hasFeedback ? color : Colors.grey[500],
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: hasFeedback ? color : Colors.grey[400],
        ),
        onTap: () {
          Navigator.pop(context);
          _showFeedbackForStage(flight, stage, existingFeedback);
        },
      ),
    );
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
