import 'package:flutter/material.dart';
import '../../services/data_flow_integration.dart';

/// Example screen demonstrating how to use the complete data flow system
/// This shows how to integrate real-time data synchronization in your existing screens
class DataFlowExampleScreen extends StatefulWidget {
  const DataFlowExampleScreen({super.key});

  @override
  State<DataFlowExampleScreen> createState() => _DataFlowExampleScreenState();
}

class _DataFlowExampleScreenState extends State<DataFlowExampleScreen> {
  final DataFlowIntegration _dataFlow = DataFlowIntegration.instance;
  
  List<Map<String, dynamic>> _userJourneys = [];
  List<Map<String, dynamic>> _recentEvents = [];
  bool _isLoading = true;
  String _userId = 'example-user-id'; // Replace with actual user ID

  @override
  void initState() {
    super.initState();
    _initializeDataFlow();
  }

  Future<void> _initializeDataFlow() async {
    try {
      // Check if data flow is initialized
      if (!_dataFlow.isInitialized) {
        await _dataFlow.initialize();
      }

      // Set up real-time streams
      _setupRealtimeStreams();
      
      // Load initial data
      await _loadUserJourneys();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error initializing data flow: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setupRealtimeStreams() {
    // Listen to user journeys updates
    _dataFlow.getUserJourneysStream(_userId).listen((journeys) {
      setState(() {
        _userJourneys = journeys;
      });
    });

    // Listen to dashboard updates for recent events
    _dataFlow.getDashboardStream().listen((event) {
      setState(() {
        _recentEvents.insert(0, event);
        if (_recentEvents.length > 20) {
          _recentEvents = _recentEvents.take(20).toList();
        }
      });
    });
  }

  Future<void> _loadUserJourneys() async {
    try {
      // This will trigger the real-time stream to populate _userJourneys
      // The stream will automatically update the UI when new data arrives
    } catch (e) {
      debugPrint('❌ Error loading user journeys: $e');
    }
  }

  Future<void> _createSampleJourney() async {
    try {
      final journey = await _dataFlow.createJourney(
        userId: _userId,
        pnr: 'ABC123',
        carrier: 'AA',
        flightNumber: 'AA1234',
        departureAirport: 'LAX',
        arrivalAirport: 'JFK',
        scheduledDeparture: DateTime.now().add(const Duration(hours: 2)),
        scheduledArrival: DateTime.now().add(const Duration(hours: 6)),
        seatNumber: '12A',
        classOfTravel: 'Economy',
        terminal: 'T1',
        gate: 'A12',
        aircraftType: 'Boeing 737',
      );

      if (journey != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Journey created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating journey: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitSampleFeedback() async {
    if (_userJourneys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No journeys available. Create a journey first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final journeyId = _userJourneys.first['id'];
      
      final success = await _dataFlow.submitStageFeedback(
        journeyId: journeyId,
        userId: _userId,
        stage: 'pre_check_in',
        positiveSelections: {
          'service': ['friendly_staff', 'efficient_check_in'],
          'facilities': ['clean_restrooms', 'good_seating'],
        },
        negativeSelections: {
          'service': ['long_wait_times'],
          'facilities': ['crowded_areas'],
        },
        customFeedback: {
          'additional_comments': 'Overall good experience',
        },
        overallRating: 4,
        additionalComments: 'Staff was very helpful during check-in process',
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting feedback: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateJourneyPhase() async {
    if (_userJourneys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No journeys available. Create a journey first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final journeyId = _userJourneys.first['id'];
      
      final success = await _dataFlow.updateJourneyPhase(
        journeyId: journeyId,
        newPhase: 'boarding',
        gate: 'A15',
        terminal: 'T1',
        metadata: {
          'boarding_time': DateTime.now().toIso8601String(),
          'estimated_departure': DateTime.now().add(const Duration(minutes: 30)).toIso8601String(),
        },
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Journey phase updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating journey phase: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _syncAllData() async {
    try {
      final success = await _dataFlow.syncAllData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Data synced successfully!' : 'Sync failed'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error syncing data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Flow Example'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncAllData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSystemStatusCard(),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                  const SizedBox(height: 16),
                  _buildUserJourneysSection(),
                  const SizedBox(height: 16),
                  _buildRecentEventsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildSystemStatusCard() {
    final health = _dataFlow.getSystemHealth();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatusIndicator('Initialized', health['initialized']),
                const SizedBox(width: 16),
                _buildStatusIndicator('Supabase', health['supabase_connected']),
                const SizedBox(width: 16),
                _buildStatusIndicator('Connected', _dataFlow.isConnected),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String label, bool isHealthy) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isHealthy ? Colors.green : Colors.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data Flow Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _createSampleJourney,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Journey'),
                ),
                ElevatedButton.icon(
                  onPressed: _submitSampleFeedback,
                  icon: const Icon(Icons.feedback),
                  label: const Text('Submit Feedback'),
                ),
                ElevatedButton.icon(
                  onPressed: _updateJourneyPhase,
                  icon: const Icon(Icons.update),
                  label: const Text('Update Phase'),
                ),
                ElevatedButton.icon(
                  onPressed: _syncAllData,
                  icon: const Icon(Icons.sync),
                  label: const Text('Sync Data'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserJourneysSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'User Journeys (Real-time)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_userJourneys.length} journeys',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_userJourneys.isEmpty)
              const Text('No journeys found', style: TextStyle(color: Colors.grey))
            else
              ..._userJourneys.take(5).map((journey) => _buildJourneyItem(journey)),
          ],
        ),
      ),
    );
  }

  Widget _buildJourneyItem(Map<String, dynamic> journey) {
    final flight = journey['flight'] ?? {};
    final airline = flight['airline'] ?? {};
    final departureAirport = flight['departure_airport'] ?? {};
    final arrivalAirport = flight['arrival_airport'] ?? {};
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${airline['name'] ?? 'Unknown'} ${flight['flight_number'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            '${departureAirport['iata_code'] ?? ''} → ${arrivalAirport['iata_code'] ?? ''}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            'Phase: ${journey['current_phase'] ?? 'Unknown'}',
            style: TextStyle(color: Colors.blue[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentEventsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Events (Real-time)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_recentEvents.length} events',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_recentEvents.isEmpty)
              const Text('No recent events', style: TextStyle(color: Colors.grey))
            else
              ..._recentEvents.take(10).map((event) => _buildEventItem(event)),
          ],
        ),
      ),
    );
  }

  Widget _buildEventItem(Map<String, dynamic> event) {
    final type = event['type'] ?? 'Unknown';
    final table = event['table'] ?? 'Unknown';
    final timestamp = event['timestamp'] ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: Colors.blue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$type - $table',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}
