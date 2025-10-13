import 'package:flutter/material.dart';
import '../../services/direct_supabase_service.dart';

/// Test screen for direct data saving to Supabase
class DirectDataTestScreen extends StatefulWidget {
  const DirectDataTestScreen({super.key});

  @override
  State<DirectDataTestScreen> createState() => _DirectDataTestScreenState();
}

class _DirectDataTestScreenState extends State<DirectDataTestScreen> {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _pnrController = TextEditingController();
  
  bool _isLoading = false;
  String _statusMessage = 'Ready to test data saving';
  Map<String, dynamic> _lastSavedData = {};

  @override
  void initState() {
    super.initState();
    _initializeTestData();
  }

  void _initializeTestData() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _userIdController.text = 'test-user-$timestamp';
    _emailController.text = 'test$timestamp@example.com';
    _displayNameController.text = 'Test User $timestamp';
    _pnrController.text = 'TEST$timestamp';
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Testing connection...';
    });

    try {
      final result = await DirectSupabaseService.testConnection();
      setState(() {
        _isLoading = false;
        _statusMessage = result ? 'Connection successful!' : 'Connection failed!';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Connection error: $e';
      });
    }
  }

  Future<void> _saveUser() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Saving user...';
    });

    try {
      final result = await DirectSupabaseService.saveUser(
        userId: _userIdController.text,
        email: _emailController.text,
        displayName: _displayNameController.text,
        phone: '+1234567890',
        avatarUrl: 'https://example.com/avatar.jpg',
      );

      setState(() {
        _isLoading = false;
        _statusMessage = result ? 'User saved successfully!' : 'User save failed!';
        if (result) {
          _lastSavedData['user_id'] = _userIdController.text;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'User save error: $e';
      });
    }
  }

  Future<void> _saveJourney() async {
    if (_lastSavedData['user_id'] == null) {
      setState(() {
        _statusMessage = 'Please save user first!';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Saving journey...';
    });

    try {
      final journeyId = 'journey-${DateTime.now().millisecondsSinceEpoch}';
      final result = await DirectSupabaseService.saveJourney(
        journeyId: journeyId,
        userId: _lastSavedData['user_id'],
        pnr: _pnrController.text,
        seatNumber: '12A',
        classOfTravel: 'Economy',
        terminal: 'T1',
        gate: 'A12',
        status: 'scheduled',
        currentPhase: 'pre_check_in',
      );

      setState(() {
        _isLoading = false;
        _statusMessage = result ? 'Journey saved successfully!' : 'Journey save failed!';
        if (result) {
          _lastSavedData['journey_id'] = journeyId;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Journey save error: $e';
      });
    }
  }

  Future<void> _saveFeedback() async {
    if (_lastSavedData['journey_id'] == null) {
      setState(() {
        _statusMessage = 'Please save journey first!';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Saving feedback...';
    });

    try {
      final feedbackId = 'feedback-${DateTime.now().millisecondsSinceEpoch}';
      final result = await DirectSupabaseService.saveStageFeedback(
        feedbackId: feedbackId,
        journeyId: _lastSavedData['journey_id'],
        userId: _lastSavedData['user_id'],
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

      setState(() {
        _isLoading = false;
        _statusMessage = result ? 'Feedback saved successfully!' : 'Feedback save failed!';
        if (result) {
          _lastSavedData['feedback_id'] = feedbackId;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Feedback save error: $e';
      });
    }
  }

  Future<void> _saveEvent() async {
    if (_lastSavedData['journey_id'] == null) {
      setState(() {
        _statusMessage = 'Please save journey first!';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Saving event...';
    });

    try {
      final eventId = 'event-${DateTime.now().millisecondsSinceEpoch}';
      final result = await DirectSupabaseService.saveJourneyEvent(
        eventId: eventId,
        journeyId: _lastSavedData['journey_id'],
        eventType: 'phase_change',
        title: 'Journey Phase Updated',
        description: 'Journey phase changed to boarding',
        metadata: {
          'gate': 'A15',
          'terminal': 'T1',
          'boarding_time': DateTime.now().toIso8601String(),
        },
      );

      setState(() {
        _isLoading = false;
        _statusMessage = result ? 'Event saved successfully!' : 'Event save failed!';
        if (result) {
          _lastSavedData['event_id'] = eventId;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Event save error: $e';
      });
    }
  }

  Future<void> _getAllData() async {
    if (_lastSavedData['user_id'] == null) {
      setState(() {
        _statusMessage = 'Please save user first!';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Getting all data...';
    });

    try {
      final data = await DirectSupabaseService.getAllUserData(_lastSavedData['user_id']);
      
      setState(() {
        _isLoading = false;
        _statusMessage = 'Data retrieved successfully!';
        _lastSavedData['retrieved_data'] = data;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Data retrieval error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Direct Data Test'),
        backgroundColor: Colors.green[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _testConnection,
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
                  _buildStatusCard(),
                  const SizedBox(height: 16),
                  _buildTestDataForm(),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                  const SizedBox(height: 16),
                  _buildSavedDataCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _statusMessage,
              style: TextStyle(
                color: _statusMessage.contains('successfully') || _statusMessage.contains('successful')
                    ? Colors.green
                    : _statusMessage.contains('failed') || _statusMessage.contains('error')
                        ? Colors.red
                        : Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatusIndicator('Loading', _isLoading),
                const SizedBox(width: 16),
                _buildStatusIndicator('User Saved', _lastSavedData['user_id'] != null),
                const SizedBox(width: 16),
                _buildStatusIndicator('Journey Saved', _lastSavedData['journey_id'] != null),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String label, bool isActive) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isActive ? Colors.green : Colors.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildTestDataForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test Data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _userIdController,
              decoration: const InputDecoration(
                labelText: 'User ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pnrController,
              decoration: const InputDecoration(
                labelText: 'PNR',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
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
              'Test Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _testConnection,
                  icon: const Icon(Icons.wifi),
                  label: const Text('Test Connection'),
                ),
                ElevatedButton.icon(
                  onPressed: _saveUser,
                  icon: const Icon(Icons.person),
                  label: const Text('Save User'),
                ),
                ElevatedButton.icon(
                  onPressed: _saveJourney,
                  icon: const Icon(Icons.flight),
                  label: const Text('Save Journey'),
                ),
                ElevatedButton.icon(
                  onPressed: _saveFeedback,
                  icon: const Icon(Icons.feedback),
                  label: const Text('Save Feedback'),
                ),
                ElevatedButton.icon(
                  onPressed: _saveEvent,
                  icon: const Icon(Icons.event),
                  label: const Text('Save Event'),
                ),
                ElevatedButton.icon(
                  onPressed: _getAllData,
                  icon: const Icon(Icons.download),
                  label: const Text('Get All Data'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedDataCard() {
    if (_lastSavedData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saved Data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._lastSavedData.entries.map((entry) {
              if (entry.key == 'retrieved_data') {
                final data = entry.value as Map<String, dynamic>;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${entry.key}:', style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text('  User: ${data['user'] != null ? "Found" : "Not found"}'),
                    Text('  Journeys: ${data['total_journeys'] ?? 0}'),
                    Text('  Events: ${data['total_events'] ?? 0}'),
                    Text('  Retrieved: ${data['retrieved_at'] ?? "Unknown"}'),
                  ],
                );
              } else {
                return Text('${entry.key}: ${entry.value}');
              }
            }),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _emailController.dispose();
    _displayNameController.dispose();
    _pnrController.dispose();
    super.dispose();
  }
}
