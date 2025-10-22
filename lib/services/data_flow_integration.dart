import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data_flow_manager.dart';
import 'dashboard_service.dart';
import 'realtime_data_service.dart';
import 'supabase_service.dart';

/// Main integration service that coordinates all data flow operations
/// This is the primary interface for the app to interact with Supabase
class DataFlowIntegration {
  static DataFlowIntegration? _instance;
  static DataFlowIntegration get instance =>
      _instance ??= DataFlowIntegration._();

  DataFlowIntegration._();

  final DataFlowManager _dataFlowManager = DataFlowManager.instance;
  final DashboardService _dashboardService = DashboardService.instance;
  final RealtimeDataService _realtimeService = RealtimeDataService.instance;

  bool _isInitialized = false;

  /// Initialize the complete data flow system
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('🚀 Initializing DataFlowIntegration...');

    try {
      // Initialize Supabase
      await SupabaseService.initialize();

      // Initialize data flow manager
      await _dataFlowManager.initialize();

      // Initialize dashboard service
      await _dashboardService.initialize();

      // Initialize real-time service
      await _realtimeService.initialize();

      _isInitialized = true;
      debugPrint('✅ DataFlowIntegration initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing DataFlowIntegration: $e');
      rethrow;
    }
  }

  /// Check if the system is initialized
  bool get isInitialized => _isInitialized;

  // ==================== JOURNEY MANAGEMENT ====================

  /// Create a new journey with complete data flow
  Future<Map<String, dynamic>?> createJourney({
    required String userId,
    required String pnr,
    required String carrier,
    required String flightNumber,
    required String departureAirport,
    required String arrivalAirport,
    required DateTime scheduledDeparture,
    required DateTime scheduledArrival,
    String? seatNumber,
    String? classOfTravel,
    String? terminal,
    String? gate,
    String? aircraftType,
  }) async {
    if (!_isInitialized) {
      throw Exception(
          'DataFlowIntegration not initialized. Call initialize() first.');
    }

    return await _dataFlowManager.createJourneyWithTracking(
      userId: userId,
      pnr: pnr,
      carrier: carrier,
      flightNumber: flightNumber,
      departureAirport: departureAirport,
      arrivalAirport: arrivalAirport,
      scheduledDeparture: scheduledDeparture,
      scheduledArrival: scheduledArrival,
      seatNumber: seatNumber,
      classOfTravel: classOfTravel,
      terminal: terminal,
      gate: gate,
      aircraftType: aircraftType,
    );
  }

  /// Get user journeys with real-time updates
  Stream<List<Map<String, dynamic>>> getUserJourneysStream(String userId) {
    if (!_isInitialized) {
      throw Exception(
          'DataFlowIntegration not initialized. Call initialize() first.');
    }

    return _dataFlowManager.getUserJourneysStream(userId);
  }

  /// Get journey events stream
  Stream<Map<String, dynamic>> getJourneyEventsStream(String journeyId) {
    if (!_isInitialized) {
      throw Exception(
          'DataFlowIntegration not initialized. Call initialize() first.');
    }

    return _dataFlowManager.getJourneyEventsStream(journeyId);
  }

  /// Update journey phase
  Future<bool> updateJourneyPhase({
    required String journeyId,
    required String newPhase,
    String? gate,
    String? terminal,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isInitialized) {
      throw Exception(
          'DataFlowIntegration not initialized. Call initialize() first.');
    }

    return await _dataFlowManager.updateJourneyPhase(
      journeyId: journeyId,
      newPhase: newPhase,
      gate: gate,
      terminal: terminal,
      metadata: metadata,
    );
  }

  // ==================== FEEDBACK MANAGEMENT ====================

  /// Submit stage feedback with real-time updates
  Future<bool> submitStageFeedback({
    required String journeyId,
    required String userId,
    required String stage,
    required Map<String, dynamic> positiveSelections,
    required Map<String, dynamic> negativeSelections,
    required Map<String, dynamic> customFeedback,
    int? overallRating,
    String? additionalComments,
  }) async {
    if (!_isInitialized) {
      throw Exception(
          'DataFlowIntegration not initialized. Call initialize() first.');
    }

    return await _dataFlowManager.submitStageFeedbackWithRealtime(
      journeyId: journeyId,
      userId: userId,
      stage: stage,
      positiveSelections: positiveSelections,
      negativeSelections: negativeSelections,
      customFeedback: customFeedback,
      overallRating: overallRating,
      additionalComments: additionalComments,
    );
  }

  /// Submit complete review with real-time updates
  Future<Map<String, dynamic>?> submitCompleteReview({
    required String journeyId,
    required String userId,
    required String airlineId,
    required String airportId,
    required Map<String, int> airlineRatings,
    required Map<String, int> airportRatings,
    String? airlineComment,
    String? airportComment,
    List<String>? airlineImages,
    List<String>? airportImages,
  }) async {
    if (!_isInitialized) {
      throw Exception(
          'DataFlowIntegration not initialized. Call initialize() first.');
    }

    return await _dataFlowManager.submitCompleteReviewWithRealtime(
      journeyId: journeyId,
      userId: userId,
      airlineId: airlineId,
      airportId: airportId,
      airlineRatings: airlineRatings,
      airportRatings: airportRatings,
      airlineComment: airlineComment,
      airportComment: airportComment,
      airlineImages: airlineImages,
      airportImages: airportImages,
    );
  }

  /// Get feedback stream for a journey
  Stream<List<Map<String, dynamic>>> getFeedbackStream(String journeyId) {
    if (!_isInitialized) {
      throw Exception(
          'DataFlowIntegration not initialized. Call initialize() first.');
    }

    return _dataFlowManager.getFeedbackStream(journeyId);
  }

  // ==================== FLIGHT TRACKING ====================

  /// Get flight tracking stream
  Stream<Map<String, dynamic>> getFlightTrackingStream(String flightId) {
    if (!_isInitialized) {
      throw Exception(
          'DataFlowIntegration not initialized. Call initialize() first.');
    }

    return _dataFlowManager.getFlightTrackingStream(flightId);
  }

  // ==================== DASHBOARD & ANALYTICS ====================

  /// Get dashboard analytics stream
  Stream<Map<String, dynamic>> getDashboardStream() {
    if (!_isInitialized) {
      throw Exception(
          'DataFlowIntegration not initialized. Call initialize() first.');
    }

    return _dataFlowManager.getDashboardStream();
  }

  /// Get analytics stream for dashboard
  Stream<Map<String, dynamic>> getAnalyticsStream() {
    if (!_isInitialized) {
      throw Exception(
          'DataFlowIntegration not initialized. Call initialize() first.');
    }

    return _dashboardService.getAnalyticsStream();
  }

  /// Get flight tracking dashboard
  Stream<Map<String, dynamic>> getFlightTrackingDashboard() {
    if (!_isInitialized) {
      throw Exception(
          'DataFlowIntegration not initialized. Call initialize() first.');
    }

    return _dashboardService.getFlightTrackingDashboard();
  }

  /// Get alerts stream
  Stream<Map<String, dynamic>> getAlertsStream() {
    if (!_isInitialized) {
      throw Exception(
          'DataFlowIntegration not initialized. Call initialize() first.');
    }

    return _dashboardService.getAlertsStream();
  }

  /// Get user engagement metrics
  Future<Map<String, dynamic>> getUserEngagementMetrics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!_isInitialized) {
      throw Exception(
          'DataFlowIntegration not initialized. Call initialize() first.');
    }

    return await _dashboardService.getUserEngagementMetrics(
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Get operational insights
  Future<Map<String, dynamic>> getOperationalInsights() async {
    if (!_isInitialized) {
      throw Exception(
          'DataFlowIntegration not initialized. Call initialize() first.');
    }

    return await _dashboardService.getOperationalInsights();
  }

  /// Get data ingestion metrics
  Future<Map<String, dynamic>> getDataIngestionMetrics() async {
    if (!_isInitialized) {
      throw Exception(
          'DataFlowIntegration not initialized. Call initialize() first.');
    }

    return await _dashboardService.getDataIngestionMetrics();
  }

  /// Export dashboard data
  Future<Map<String, dynamic>> exportDashboardData({
    DateTime? startDate,
    DateTime? endDate,
    List<String>? dataTypes,
  }) async {
    if (!_isInitialized) {
      throw Exception(
          'DataFlowIntegration not initialized. Call initialize() first.');
    }

    return await _dashboardService.exportDashboardData(
      startDate: startDate,
      endDate: endDate,
      dataTypes: dataTypes,
    );
  }

  // ==================== DATA SYNCHRONIZATION ====================

  /// Sync all pending data
  Future<bool> syncAllData() async {
    if (!_isInitialized) {
      throw Exception(
          'DataFlowIntegration not initialized. Call initialize() first.');
    }

    return await _dataFlowManager.syncAllData();
  }

  /// Send data to Supabase with real-time updates
  Future<bool> sendDataToSupabase({
    required String table,
    required Map<String, dynamic> data,
    String? operation,
  }) async {
    if (!_isInitialized) {
      throw Exception(
          'DataFlowIntegration not initialized. Call initialize() first.');
    }

    return await _realtimeService.sendDataToSupabase(
      table: table,
      data: data,
      operation: operation,
    );
  }

  /// Get cached data for offline support
  Future<List<Map<String, dynamic>>> getCachedData(String table) async {
    if (!_isInitialized) {
      throw Exception(
          'DataFlowIntegration not initialized. Call initialize() first.');
    }

    return await _realtimeService.getCachedData(table);
  }

  // ==================== USER MANAGEMENT ====================

  /// Save user data with real-time sync
  Future<bool> saveUserData(Map<String, dynamic> userData) async {
    if (!_isInitialized) {
      throw Exception(
          'DataFlowIntegration not initialized. Call initialize() first.');
    }

    try {
      // Save to Supabase
      final success = await SupabaseService.saveUserDataToSupabase(userData);

      if (success) {
        // Send real-time update
        await _realtimeService.sendDataToSupabase(
          table: 'users',
          data: userData,
          operation: 'upsert',
        );
      }

      return success;
    } catch (e) {
      debugPrint('❌ Error saving user data: $e');
      return false;
    }
  }

  /// Get user profile with sync
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    if (!_isInitialized) {
      throw Exception(
          'DataFlowIntegration not initialized. Call initialize() first.');
    }

    return await SupabaseService.getUserProfile(userId);
  }

  // ==================== UTILITY METHODS ====================

  /// Get connection status
  bool get isConnected => SupabaseService.isInitialized;

  /// Get system health status
  Map<String, dynamic> getSystemHealth() {
    return {
      'initialized': _isInitialized,
      'supabase_connected': SupabaseService.isInitialized,
      'data_flow_manager': _dataFlowManager != null,
      'dashboard_service': _dashboardService != null,
      'realtime_service': _realtimeService != null,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Cleanup all resources
  void dispose() {
    _dataFlowManager.dispose();
    _dashboardService.dispose();
    _realtimeService.dispose();
    _isInitialized = false;
  }
}
