import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/flight_status_integration.dart';
import '../../services/supabase_service.dart';
import '../../config/cirium_config.dart';
import '../../widgets/notification_permission_widget.dart';

class FlightStatusTestScreen extends StatefulWidget {
  const FlightStatusTestScreen({super.key});

  @override
  State<FlightStatusTestScreen> createState() => _FlightStatusTestScreenState();
}

class _FlightStatusTestScreenState extends State<FlightStatusTestScreen> {
  List<Map<String, dynamic>> _journeys = [];
  bool _isLoading = false;
  String? _selectedJourneyId;
  Map<String, dynamic>? _selectedJourney;
  List<Map<String, dynamic>> _statusHistory = [];
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadJourneys();
  }

  Future<void> _initializeServices() async {
    if (CiriumConfig.isConfigured) {
      await FlightStatusIntegration.initialize(
        ciriumAppId: CiriumConfig.appIdFromEnv,
        ciriumAppKey: CiriumConfig.appKeyFromEnv,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Cirium API credentials not configured'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _loadJourneys() async {
    setState(() => _isLoading = true);
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final journeys = await SupabaseService.getUserJourneys(user.id);
        setState(() => _journeys = journeys);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading journeys: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectJourney(String journeyId) async {
    setState(() => _selectedJourneyId = journeyId);
    
    try {
      final journey = _journeys.firstWhere((j) => j['id'] == journeyId);
      setState(() => _selectedJourney = journey);
      
      // Load status history
      final history = await FlightStatusIntegration.getJourneyStatusHistory(journeyId);
      setState(() => _statusHistory = history);
      
      // Check if already monitoring
      setState(() => _isMonitoring = FlightStatusIntegration.isJourneyMonitored(journeyId));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting journey: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startMonitoring() async {
    if (_selectedJourneyId == null) return;
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await FlightStatusIntegration.startJourneyMonitoring(
          journeyId: _selectedJourneyId!,
          userId: user.id,
        );
        
        setState(() => _isMonitoring = true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Started monitoring flight status'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting monitoring: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopMonitoring() async {
    if (_selectedJourneyId == null) return;
    
    try {
      FlightStatusIntegration.stopJourneyMonitoring(_selectedJourneyId!);
      setState(() => _isMonitoring = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏹️ Stopped monitoring flight status'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error stopping monitoring: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _checkStatusManually() async {
    if (_selectedJourney == null) return;
    
    try {
      final flight = _selectedJourney!['flight'] as Map<String, dynamic>;
      final airline = flight['airline'] as Map<String, dynamic>;
      final carrier = airline['iata_code'] as String;
      final flightNumber = flight['flight_number'] as String;
      final scheduledDeparture = DateTime.parse(flight['scheduled_departure'] as String);
      
      final result = await FlightStatusIntegration.checkFlightStatus(
        journeyId: _selectedJourneyId!,
        carrier: carrier,
        flightNumber: flightNumber,
        departureDate: scheduledDeparture,
      );
      
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Flight status updated'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload status history
        final history = await FlightStatusIntegration.getJourneyStatusHistory(_selectedJourneyId!);
        setState(() => _statusHistory = history);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to update flight status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendTestNotification() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await FlightStatusIntegration.sendTestNotification(user.id);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📱 Test notification sent'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending test notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flight Status Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Journeys list
                Expanded(
                  flex: 1,
                  child: Card(
                    margin: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Your Journeys',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Notification permission widget
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: NotificationPermissionWidget(),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _journeys.length,
                            itemBuilder: (context, index) {
                              final journey = _journeys[index];
                              final flight = journey['flight'] as Map<String, dynamic>;
                              final airline = flight['airline'] as Map<String, dynamic>;
                              final departureAirport = flight['departure_airport'] as Map<String, dynamic>;
                              final arrivalAirport = flight['arrival_airport'] as Map<String, dynamic>;
                              
                              return ListTile(
                                title: Text('${airline['iata_code']}${flight['flight_number']}'),
                                subtitle: Text(
                                  '${departureAirport['iata_code']} → ${arrivalAirport['iata_code']}',
                                ),
                                trailing: Text(
                                  journey['current_phase'] ?? 'unknown',
                                  style: TextStyle(
                                    color: _getPhaseColor(journey['current_phase']),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                selected: _selectedJourneyId == journey['id'],
                                onTap: () => _selectJourney(journey['id']),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Journey details and controls
                Expanded(
                  flex: 2,
                  child: _selectedJourney == null
                      ? const Center(
                          child: Text('Select a journey to view details'),
                        )
                      : Card(
                          margin: const EdgeInsets.all(8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Journey Details',
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 16),
                                _buildJourneyInfo(),
                                const SizedBox(height: 16),
                                _buildControls(),
                                const SizedBox(height: 16),
                                const Text(
                                  'Status History',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: _buildStatusHistory(),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildJourneyInfo() {
    if (_selectedJourney == null) return const SizedBox();
    
    final flight = _selectedJourney!['flight'] as Map<String, dynamic>;
    final airline = flight['airline'] as Map<String, dynamic>;
    final departureAirport = flight['departure_airport'] as Map<String, dynamic>;
    final arrivalAirport = flight['arrival_airport'] as Map<String, dynamic>;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Flight: ${airline['iata_code']}${flight['flight_number']}'),
        Text('Route: ${departureAirport['iata_code']} → ${arrivalAirport['iata_code']}'),
        Text('Status: ${_selectedJourney!['current_phase'] ?? 'unknown'}'),
        Text('Scheduled Departure: ${flight['scheduled_departure']}'),
        Text('Scheduled Arrival: ${flight['scheduled_arrival']}'),
      ],
    );
  }

  Widget _buildControls() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton(
          onPressed: _isMonitoring ? _stopMonitoring : _startMonitoring,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isMonitoring ? Colors.red : Colors.green,
            foregroundColor: Colors.white,
          ),
          child: Text(_isMonitoring ? 'Stop Monitoring' : 'Start Monitoring'),
        ),
        ElevatedButton(
          onPressed: _checkStatusManually,
          child: const Text('Check Status Now'),
        ),
        ElevatedButton(
          onPressed: _sendTestNotification,
          child: const Text('Send Test Notification'),
        ),
        ElevatedButton(
          onPressed: _loadJourneys,
          child: const Text('Refresh'),
        ),
      ],
    );
  }

  Widget _buildStatusHistory() {
    if (_statusHistory.isEmpty) {
      return const Center(
        child: Text('No status history available'),
      );
    }
    
    return ListView.builder(
      itemCount: _statusHistory.length,
      itemBuilder: (context, index) {
        final event = _statusHistory[index];
        return Card(
          child: ListTile(
            title: Text(event['title'] ?? 'Unknown Event'),
            subtitle: Text(event['description'] ?? ''),
            trailing: Text(
              event['event_timestamp'] != null
                  ? DateTime.parse(event['event_timestamp']).toString().substring(0, 19)
                  : '',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  Color _getPhaseColor(String? phase) {
    switch (phase) {
      case 'boarding':
        return Colors.orange;
      case 'departed':
      case 'in_flight':
        return Colors.blue;
      case 'landed':
      case 'arrived':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'delayed':
        return Colors.yellow[700]!;
      default:
        return Colors.grey;
    }
  }
}
