import 'package:flutter/material.dart';
import '../../services/supabase_test_service.dart';
import '../../services/supabase_service.dart';

/// Test screen to debug Supabase connection and data saving
class SupabaseTestScreen extends StatefulWidget {
  const SupabaseTestScreen({super.key});

  @override
  State<SupabaseTestScreen> createState() => _SupabaseTestScreenState();
}

class _SupabaseTestScreenState extends State<SupabaseTestScreen> {
  Map<String, bool> _testResults = {};
  Map<String, dynamic> _tableInfo = {};
  bool _isLoading = false;
  String _statusMessage = 'Ready to test';

  @override
  void initState() {
    super.initState();
    _loadTableInfo();
  }

  Future<void> _loadTableInfo() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading table information...';
    });

    try {
      final info = await SupabaseTestService.getTableInfo();
      setState(() {
        _tableInfo = info;
        _isLoading = false;
        _statusMessage = 'Table info loaded';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error loading table info: $e';
      });
    }
  }

  Future<void> _runAllTests() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Running all tests...';
    });

    try {
      final results = await SupabaseTestService.runAllTests();
      setState(() {
        _testResults = results;
        _isLoading = false;
        _statusMessage = 'Tests completed';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error running tests: $e';
      });
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Testing connection...';
    });

    try {
      final result = await SupabaseTestService.testConnection();
      setState(() {
        _testResults['connection'] = result;
        _isLoading = false;
        _statusMessage = result ? 'Connection successful' : 'Connection failed';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Connection error: $e';
      });
    }
  }

  Future<void> _testSaveUser() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Testing user save...';
    });

    try {
      final result = await SupabaseTestService.testSaveUser();
      setState(() {
        _testResults['user_save'] = result;
        _isLoading = false;
        _statusMessage = result ? 'User save successful' : 'User save failed';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'User save error: $e';
      });
    }
  }

  Future<void> _testSaveJourney() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Testing journey save...';
    });

    try {
      final result = await SupabaseTestService.testSaveJourney();
      setState(() {
        _testResults['journey_save'] = result;
        _isLoading = false;
        _statusMessage = result ? 'Journey save successful' : 'Journey save failed';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Journey save error: $e';
      });
    }
  }

  Future<void> _testSaveFeedback() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Testing feedback save...';
    });

    try {
      final result = await SupabaseTestService.testSaveFeedback();
      setState(() {
        _testResults['feedback_save'] = result;
        _isLoading = false;
        _statusMessage = result ? 'Feedback save successful' : 'Feedback save failed';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Feedback save error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supabase Test'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTableInfo,
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
                  _buildSupabaseInfoCard(),
                  const SizedBox(height: 16),
                  _buildTableInfoCard(),
                  const SizedBox(height: 16),
                  _buildTestButtons(),
                  const SizedBox(height: 16),
                  _buildTestResultsCard(),
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
                color: _statusMessage.contains('successful') || _statusMessage.contains('completed')
                    ? Colors.green
                    : _statusMessage.contains('failed') || _statusMessage.contains('Error')
                        ? Colors.red
                        : Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatusIndicator('Supabase Initialized', SupabaseService.isInitialized),
                const SizedBox(width: 16),
                _buildStatusIndicator('Loading', _isLoading),
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

  Widget _buildSupabaseInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Supabase Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'URL: https://otidfywfqxyxteixpqre.supabase.co',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            Text(
              'Initialized: ${SupabaseService.isInitialized ? "Yes" : "No"}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Database Tables',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_tableInfo.isEmpty)
              const Text('No table information available', style: TextStyle(color: Colors.grey))
            else
              ..._tableInfo.entries.map((entry) => _buildTableInfoItem(entry.key, entry.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildTableInfoItem(String tableName, Map<String, dynamic> info) {
    final exists = info['exists'] ?? false;
    final count = info['count'] ?? 0;
    final error = info['error'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            exists ? Icons.check_circle : Icons.error,
            size: 16,
            color: exists ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tableName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          if (exists)
            Text(
              'Count: $count',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            )
          else
            Text(
              'Error: ${error?.toString().substring(0, 50) ?? "Unknown"}',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildTestButtons() {
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
                  onPressed: _testSaveUser,
                  icon: const Icon(Icons.person),
                  label: const Text('Test User Save'),
                ),
                ElevatedButton.icon(
                  onPressed: _testSaveJourney,
                  icon: const Icon(Icons.flight),
                  label: const Text('Test Journey Save'),
                ),
                ElevatedButton.icon(
                  onPressed: _testSaveFeedback,
                  icon: const Icon(Icons.feedback),
                  label: const Text('Test Feedback Save'),
                ),
                ElevatedButton.icon(
                  onPressed: _runAllTests,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Run All Tests'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResultsCard() {
    if (_testResults.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test Results',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._testResults.entries.map((entry) => _buildTestResultItem(entry.key, entry.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResultItem(String testName, bool passed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.cancel,
            size: 20,
            color: passed ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              testName.replaceAll('_', ' ').toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            passed ? 'PASS' : 'FAIL',
            style: TextStyle(
              color: passed ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
