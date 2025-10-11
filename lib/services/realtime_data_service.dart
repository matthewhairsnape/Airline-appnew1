import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Comprehensive real-time data synchronization service
/// Handles all data flow between Flutter app and Supabase
class RealtimeDataService {
  static RealtimeDataService? _instance;
  static RealtimeDataService get instance => _instance ??= RealtimeDataService._();
  
  RealtimeDataService._();

  final Map<String, RealtimeChannel> _activeChannels = {};
  final Map<String, StreamController<dynamic>> _dataStreams = {};
  final Map<String, List<Map<String, dynamic>>> _localCache = {};

  /// Initialize real-time data service
  Future<void> initialize() async {
    debugPrint('🔄 Initializing RealtimeDataService...');
    
    // Set up global error handling
    Supabase.instance.client.realtime.onError((error) {
      debugPrint('❌ Realtime error: $error');
    });

    // Set up connection status monitoring
    Supabase.instance.client.realtime.onConnect((_) {
      debugPrint('📡 Realtime connected');
      _resubscribeToAllChannels();
    });
    
    Supabase.instance.client.realtime.onDisconnect((_) {
      debugPrint('📡 Realtime disconnected');
    });

    debugPrint('✅ RealtimeDataService initialized');
  }

  /// Subscribe to real-time updates for a specific journey
  Stream<Map<String, dynamic>> subscribeToJourney(String journeyId) {
    if (_dataStreams.containsKey(journeyId)) {
      return _dataStreams[journeyId]!.stream;
    }

    final streamController = StreamController<Map<String, dynamic>>.broadcast();
    _dataStreams[journeyId] = streamController;

    // Subscribe to journey events
    final journeyChannel = Supabase.instance.client
        .channel('journey_$journeyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'journey_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'journey_id',
            value: journeyId,
          ),
          callback: (payload) {
            _handleJourneyEventUpdate(journeyId, payload, streamController);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'journeys',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: journeyId,
          ),
          callback: (payload) {
            _handleJourneyUpdate(journeyId, payload, streamController);
          },
        )
        .subscribe();

    _activeChannels[journeyId] = journeyChannel;

    return streamController.stream;
  }

  /// Subscribe to user's all journeys
  Stream<List<Map<String, dynamic>>> subscribeToUserJourneys(String userId) {
    final streamController = StreamController<List<Map<String, dynamic>>>.broadcast();
    _dataStreams['user_journeys_$userId'] = streamController as StreamController<dynamic>;

    final userChannel = Supabase.instance.client
        .channel('user_journeys_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'journeys',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            _handleUserJourneysUpdate(userId, payload, streamController as StreamController<List<Map<String, dynamic>>>);
          },
        )
        .subscribe();

    _activeChannels['user_journeys_$userId'] = userChannel;

    return streamController.stream;
  }

  /// Subscribe to flight tracking updates
  Stream<Map<String, dynamic>> subscribeToFlightTracking(String flightId) {
    if (_dataStreams.containsKey('flight_$flightId')) {
      return _dataStreams['flight_$flightId']!.stream;
    }

    final streamController = StreamController<Map<String, dynamic>>.broadcast();
    _dataStreams['flight_$flightId'] = streamController;

    final flightChannel = Supabase.instance.client
        .channel('flight_tracking_$flightId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'flights',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: flightId,
          ),
          callback: (payload) {
            _handleFlightUpdate(flightId, payload, streamController);
          },
        )
        .subscribe();

    _activeChannels['flight_$flightId'] = flightChannel;

    return streamController.stream;
  }

  /// Subscribe to feedback updates
  Stream<List<Map<String, dynamic>>> subscribeToFeedback(String journeyId) {
    final streamController = StreamController<List<Map<String, dynamic>>>.broadcast();
    _dataStreams['feedback_$journeyId'] = streamController as StreamController<dynamic>;

    final feedbackChannel = Supabase.instance.client
        .channel('feedback_$journeyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'stage_feedback',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'journey_id',
            value: journeyId,
          ),
          callback: (payload) {
            _handleFeedbackUpdate(journeyId, payload, streamController as StreamController<List<Map<String, dynamic>>>);
          },
        )
        .subscribe();

    _activeChannels['feedback_$journeyId'] = feedbackChannel;

    return streamController.stream;
  }

  /// Subscribe to dashboard analytics data
  Stream<Map<String, dynamic>> subscribeToDashboard() {
    final streamController = StreamController<Map<String, dynamic>>.broadcast();
    _dataStreams['dashboard'] = streamController;

    final dashboardChannel = Supabase.instance.client
        .channel('dashboard_analytics')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'journey_events',
          callback: (payload) {
            _handleDashboardUpdate(payload, streamController);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'stage_feedback',
          callback: (payload) {
            _handleDashboardUpdate(payload, streamController);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'airline_reviews',
          callback: (payload) {
            _handleDashboardUpdate(payload, streamController);
          },
        )
        .subscribe();

    _activeChannels['dashboard'] = dashboardChannel;

    return streamController.stream;
  }

  /// Send real-time data to Supabase
  Future<bool> sendDataToSupabase({
    required String table,
    required Map<String, dynamic> data,
    String? operation, // 'insert', 'update', 'delete'
  }) async {
    try {
      // Add metadata
      final enrichedData = {
        ...data,
        'updated_at': DateTime.now().toIso8601String(),
        'client_timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // Perform the operation
      switch (operation) {
        case 'insert':
          await Supabase.instance.client.from(table).insert(enrichedData);
          break;
        case 'update':
          await Supabase.instance.client.from(table).update(enrichedData);
          break;
        case 'delete':
          await Supabase.instance.client.from(table).delete();
          break;
        default:
          await Supabase.instance.client.from(table).upsert(enrichedData);
      }

      // Cache locally for offline support
      await _cacheDataLocally(table, enrichedData);

      debugPrint('✅ Data sent to Supabase: $table');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending data to Supabase: $e');
      // Store for retry when connection is restored
      await _storeForRetry(table, data, operation);
      return false;
    }
  }

  /// Sync all pending data when connection is restored
  Future<void> syncPendingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingData = prefs.getString('pending_supabase_data');
      
      if (pendingData != null) {
        final List<Map<String, dynamic>> pending = 
            List<Map<String, dynamic>>.from(json.decode(pendingData));
        
        for (final item in pending) {
          await sendDataToSupabase(
            table: item['table'],
            data: item['data'],
            operation: item['operation'],
          );
        }
        
        // Clear pending data after successful sync
        await prefs.remove('pending_supabase_data');
        debugPrint('✅ Pending data synced successfully');
      }
    } catch (e) {
      debugPrint('❌ Error syncing pending data: $e');
    }
  }

  /// Get cached data for offline support
  Future<List<Map<String, dynamic>>> getCachedData(String table) async {
    if (_localCache.containsKey(table)) {
      return _localCache[table]!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_$table');
      
      if (cachedData != null) {
        final data = List<Map<String, dynamic>>.from(json.decode(cachedData));
        _localCache[table] = data;
        return data;
      }
    } catch (e) {
      debugPrint('❌ Error getting cached data: $e');
    }
    
    return [];
  }

  /// Update local cache
  Future<void> _cacheDataLocally(String table, Map<String, dynamic> data) async {
    try {
      if (!_localCache.containsKey(table)) {
        _localCache[table] = [];
      }
      
      _localCache[table]!.add(data);
      
      // Persist to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_$table', json.encode(_localCache[table]));
    } catch (e) {
      debugPrint('❌ Error caching data locally: $e');
    }
  }

  /// Store data for retry when connection is restored
  Future<void> _storeForRetry(String table, Map<String, dynamic> data, String? operation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingData = prefs.getString('pending_supabase_data');
      
      List<Map<String, dynamic>> pending = [];
      if (existingData != null) {
        pending = List<Map<String, dynamic>>.from(json.decode(existingData));
      }
      
      pending.add({
        'table': table,
        'data': data,
        'operation': operation,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      await prefs.setString('pending_supabase_data', json.encode(pending));
    } catch (e) {
      debugPrint('❌ Error storing data for retry: $e');
    }
  }

  /// Handle journey event updates
  void _handleJourneyEventUpdate(
    String journeyId,
    PostgresChangePayload payload,
    StreamController<Map<String, dynamic>> controller,
  ) {
    final eventData = {
      'type': 'journey_event',
      'journey_id': journeyId,
      'event': payload.eventType.toString(),
      'data': payload.newRecord ?? payload.oldRecord,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    controller.add(eventData);
    _cacheDataLocally('journey_events', eventData);
  }

  /// Handle journey updates
  void _handleJourneyUpdate(
    String journeyId,
    PostgresChangePayload payload,
    StreamController<Map<String, dynamic>> controller,
  ) {
    final journeyData = {
      'type': 'journey_update',
      'journey_id': journeyId,
      'event': payload.eventType.toString(),
      'data': payload.newRecord ?? payload.oldRecord,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    controller.add(journeyData);
    _cacheDataLocally('journeys', journeyData);
  }

  /// Handle user journeys updates
  void _handleUserJourneysUpdate(
    String userId,
    PostgresChangePayload payload,
    StreamController<List<Map<String, dynamic>>> controller,
  ) {
    // Fetch updated journeys list
    _fetchUserJourneys(userId).then((journeys) {
      controller.add(journeys);
    });
  }

  /// Handle flight updates
  void _handleFlightUpdate(
    String flightId,
    PostgresChangePayload payload,
    StreamController<Map<String, dynamic>> controller,
  ) {
    final flightData = {
      'type': 'flight_update',
      'flight_id': flightId,
      'event': payload.eventType.toString(),
      'data': payload.newRecord ?? payload.oldRecord,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    controller.add(flightData);
    _cacheDataLocally('flights', flightData);
  }

  /// Handle feedback updates
  void _handleFeedbackUpdate(
    String journeyId,
    PostgresChangePayload payload,
    StreamController<List<Map<String, dynamic>>> controller,
  ) {
    // Fetch updated feedback list
    _fetchJourneyFeedback(journeyId).then((feedback) {
      controller.add(feedback);
    });
  }

  /// Handle dashboard updates
  void _handleDashboardUpdate(
    PostgresChangePayload payload,
    StreamController<Map<String, dynamic>> controller,
  ) {
    final dashboardData = {
      'type': 'dashboard_update',
      'table': payload.table,
      'event': payload.eventType.toString(),
      'data': payload.newRecord ?? payload.oldRecord,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    controller.add(dashboardData);
  }

  /// Fetch user journeys
  Future<List<Map<String, dynamic>>> _fetchUserJourneys(String userId) async {
    try {
      final data = await Supabase.instance.client
          .from('journeys')
          .select('''
            *,
            flight:flights (
              *,
              airline:airlines (*),
              departure_airport:airports!flights_departure_airport_id_fkey (*),
              arrival_airport:airports!flights_arrival_airport_id_fkey (*)
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('❌ Error fetching user journeys: $e');
      return [];
    }
  }

  /// Fetch journey feedback
  Future<List<Map<String, dynamic>>> _fetchJourneyFeedback(String journeyId) async {
    try {
      final data = await Supabase.instance.client
          .from('stage_feedback')
          .select('*')
          .eq('journey_id', journeyId)
          .order('feedback_timestamp', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('❌ Error fetching journey feedback: $e');
      return [];
    }
  }

  /// Resubscribe to all active channels
  void _resubscribeToAllChannels() {
    debugPrint('🔄 Resubscribing to all channels...');
    for (final entry in _activeChannels.entries) {
      entry.value.subscribe();
    }
  }

  /// Unsubscribe from a specific channel
  void unsubscribe(String channelId) {
    if (_activeChannels.containsKey(channelId)) {
      _activeChannels[channelId]!.unsubscribe();
      _activeChannels.remove(channelId);
    }
    
    if (_dataStreams.containsKey(channelId)) {
      _dataStreams[channelId]!.close();
      _dataStreams.remove(channelId);
    }
  }

  /// Cleanup all subscriptions
  void dispose() {
    for (final channel in _activeChannels.values) {
      channel.unsubscribe();
    }
    
    for (final stream in _dataStreams.values) {
      stream.close();
    }
    
    _activeChannels.clear();
    _dataStreams.clear();
    _localCache.clear();
  }
}
