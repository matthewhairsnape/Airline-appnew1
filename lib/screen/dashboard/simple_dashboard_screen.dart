import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/simple_data_flow_service.dart';

/// Simple dashboard screen showing basic real-time data and analytics
class SimpleDashboardScreen extends StatefulWidget {
  const SimpleDashboardScreen({super.key});

  @override
  State<SimpleDashboardScreen> createState() => _SimpleDashboardScreenState();
}

class _SimpleDashboardScreenState extends State<SimpleDashboardScreen> {
  final SimpleDataFlowService _dataFlow = SimpleDataFlowService.instance;
  
  Map<String, dynamic> _analyticsData = {};
  List<Map<String, dynamic>> _recentEvents = [];
  List<Map<String, dynamic>> _recentFeedback = [];
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    try {
      // Load initial data
      await _loadDashboardData();
      
      // Set up real-time streams
      _setupRealtimeStreams();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error initializing dashboard: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      final analytics = await _dataFlow.getBasicAnalytics();
      
      setState(() {
        _analyticsData = analytics;
        _recentEvents = List<Map<String, dynamic>>.from(analytics['recent_events'] ?? []);
        _recentFeedback = List<Map<String, dynamic>>.from(analytics['recent_feedback'] ?? []);
      });
    } catch (e) {
      debugPrint('❌ Error loading dashboard data: $e');
    }
  }

  void _setupRealtimeStreams() {
    // Listen to dashboard updates
    _dataFlow.getDashboardStream().listen((event) {
      setState(() {
        _recentEvents.insert(0, event);
        if (_recentEvents.length > 50) {
          _recentEvents = _recentEvents.take(50).toList();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple Dashboard'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSystemHealthCard(),
                    const SizedBox(height: 16),
                    _buildAnalyticsOverview(),
                    const SizedBox(height: 16),
                    _buildRecentEventsSection(),
                    const SizedBox(height: 16),
                    _buildRecentFeedbackSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSystemHealthCard() {
    final health = _dataFlow.getSystemHealth();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Health',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildHealthIndicator('Initialized', health['initialized']),
                const SizedBox(width: 16),
                _buildHealthIndicator('Supabase', health['supabase_connected']),
                const SizedBox(width: 16),
                _buildHealthIndicator('Channels', health['active_channels'] > 0),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Active Channels: ${health['active_channels']}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            Text(
              'Active Streams: ${health['active_streams']}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthIndicator(String label, bool isHealthy) {
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

  Widget _buildAnalyticsOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analytics Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Recent Events',
                    '${_recentEvents.length}',
                    Icons.timeline,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    'Recent Feedback',
                    '${_recentFeedback.length}',
                    Icons.feedback,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Last Updated: ${_formatTimestamp(_analyticsData['last_updated'] ?? '')}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
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
    final data = event['data'] ?? {};
    
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
                if (data['event_type'] != null)
                  Text(
                    'Event: ${data['event_type']}',
                    style: TextStyle(color: Colors.blue[600], fontSize: 12),
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

  Widget _buildRecentFeedbackSection() {
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
                  'Recent Feedback',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_recentFeedback.length} feedback',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_recentFeedback.isEmpty)
              const Text('No recent feedback', style: TextStyle(color: Colors.grey))
            else
              ..._recentFeedback.take(10).map((feedback) => _buildFeedbackItem(feedback)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackItem(Map<String, dynamic> feedback) {
    final stage = feedback['stage'] ?? 'Unknown';
    final rating = feedback['overall_rating'] ?? 0;
    final timestamp = feedback['feedback_timestamp'] ?? '';
    
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
            Icons.feedback,
            size: 16,
            color: Colors.green,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stage: $stage',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (rating > 0)
                  Row(
                    children: [
                      Text(
                        'Rating: $rating/5',
                        style: TextStyle(color: Colors.orange[600], fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      ...List.generate(5, (index) {
                        return Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          size: 12,
                          color: Colors.orange,
                        );
                      }),
                    ],
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
