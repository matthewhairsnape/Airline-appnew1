import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/data_flow_integration.dart';
import '../../models/flight_tracking_model.dart';

/// Live dashboard screen showing real-time data ingestion and analytics
class LiveDashboardScreen extends StatefulWidget {
  const LiveDashboardScreen({super.key});

  @override
  State<LiveDashboardScreen> createState() => _LiveDashboardScreenState();
}

class _LiveDashboardScreenState extends State<LiveDashboardScreen> {
  final DataFlowIntegration _dataFlow = DataFlowIntegration.instance;
  
  Map<String, dynamic> _analyticsData = {};
  Map<String, dynamic> _operationalInsights = {};
  Map<String, dynamic> _dataIngestionMetrics = {};
  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _recentEvents = [];
  
  bool _isLoading = true;
  String _selectedTimeRange = '24h';

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
      final analytics = await _dataFlow.getOperationalInsights();
      final metrics = await _dataFlow.getDataIngestionMetrics();
      
      setState(() {
        _operationalInsights = analytics;
        _dataIngestionMetrics = metrics;
      });
    } catch (e) {
      debugPrint('❌ Error loading dashboard data: $e');
    }
  }

  void _setupRealtimeStreams() {
    // Analytics stream
    _dataFlow.getAnalyticsStream().listen((data) {
      setState(() {
        _analyticsData = data;
        _recentEvents.insert(0, data);
        if (_recentEvents.length > 50) {
          _recentEvents = _recentEvents.take(50).toList();
        }
      });
    });

    // Alerts stream
    _dataFlow.getAlertsStream().listen((alert) {
      setState(() {
        _alerts.insert(0, alert);
        if (_alerts.length > 20) {
          _alerts = _alerts.take(20).toList();
        }
      });
      
      // Show alert notification
      _showAlertNotification(alert);
    });
  }

  void _showAlertNotification(Map<String, dynamic> alert) {
    final priority = alert['priority'] ?? 'low';
    final color = priority == 'high' ? Colors.red : 
                 priority == 'medium' ? Colors.orange : Colors.blue;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Alert: ${alert['data']['event_type'] ?? 'Unknown'}'),
        backgroundColor: color,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Dashboard'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedTimeRange = value;
              });
              _loadDashboardData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: '1h', child: Text('Last Hour')),
              const PopupMenuItem(value: '24h', child: Text('Last 24 Hours')),
              const PopupMenuItem(value: '7d', child: Text('Last 7 Days')),
              const PopupMenuItem(value: '30d', child: Text('Last 30 Days')),
            ],
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
                    _buildDataIngestionMetrics(),
                    const SizedBox(height: 16),
                    _buildOperationalInsights(),
                    const SizedBox(height: 16),
                    _buildAlertsSection(),
                    const SizedBox(height: 16),
                    _buildRecentEventsSection(),
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
                _buildHealthIndicator('Data Flow', health['data_flow_manager']),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Last Updated: ${_formatTimestamp(health['timestamp'])}',
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

  Widget _buildDataIngestionMetrics() {
    final events = _dataIngestionMetrics['events'] ?? {};
    final feedback = _dataIngestionMetrics['feedback'] ?? {};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data Ingestion Metrics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Events (Hourly)',
                    '${events['hourly'] ?? 0}',
                    Icons.timeline,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    'Events (Daily)',
                    '${events['daily'] ?? 0}',
                    Icons.timeline,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Feedback (Hourly)',
                    '${feedback['hourly'] ?? 0}',
                    Icons.feedback,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    'Feedback (Daily)',
                    '${feedback['daily'] ?? 0}',
                    Icons.feedback,
                    Colors.green,
                  ),
                ),
              ],
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

  Widget _buildOperationalInsights() {
    final flightStatus = _operationalInsights['flight_status_distribution'] ?? [];
    final phaseFeedback = _operationalInsights['phase_feedback_insights'] ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Operational Insights',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (flightStatus.isNotEmpty) ...[
              const Text('Flight Status Distribution', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: _buildFlightStatusChart(flightStatus),
              ),
              const SizedBox(height: 16),
            ],
            if (phaseFeedback.isNotEmpty) ...[
              const Text('Phase Feedback Insights', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...phaseFeedback.map((phase) => _buildPhaseFeedbackItem(phase)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFlightStatusChart(List<dynamic> flightStatus) {
    return PieChart(
      PieChartData(
        sections: flightStatus.map((status) {
          final phase = status['current_phase'] ?? 'unknown';
          final count = status['count'] ?? 0;
          final colors = [
            Colors.blue,
            Colors.green,
            Colors.orange,
            Colors.red,
            Colors.purple,
            Colors.teal,
            Colors.amber,
            Colors.indigo,
          ];
          
          return PieChartSectionData(
            color: colors[flightStatus.indexOf(status) % colors.length],
            value: count.toDouble(),
            title: phase,
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }

  Widget _buildPhaseFeedbackItem(Map<String, dynamic> phase) {
    final stage = phase['stage'] ?? 'Unknown';
    final avgRating = phase['avg_rating'] ?? 0.0;
    final feedbackCount = phase['feedback_count'] ?? 0;
    final positiveCount = phase['positive_feedback_count'] ?? 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(stage, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text('${avgRating.toStringAsFixed(1)}/5'),
          ),
          Expanded(
            child: Text('$feedbackCount total'),
          ),
          Expanded(
            child: Text('${((positiveCount / feedbackCount) * 100).toStringAsFixed(1)}% positive'),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection() {
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
                  'Live Alerts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_alerts.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_alerts.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_alerts.isEmpty)
              const Text('No active alerts', style: TextStyle(color: Colors.grey))
            else
              ..._alerts.take(5).map((alert) => _buildAlertItem(alert)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItem(Map<String, dynamic> alert) {
    final priority = alert['priority'] ?? 'low';
    final data = alert['data'] ?? {};
    final eventType = data['event_type'] ?? 'Unknown';
    final timestamp = alert['timestamp'] ?? '';
    
    Color alertColor = Colors.grey;
    if (priority == 'high') alertColor = Colors.red;
    else if (priority == 'medium') alertColor = Colors.orange;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alertColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: alertColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: alertColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eventType,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            priority.toUpperCase(),
            style: TextStyle(
              color: alertColor,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
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
            const Text(
              'Recent Events',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
