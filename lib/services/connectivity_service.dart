import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service to check and monitor internet connectivity
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  // Current connectivity status
  bool _isConnected = true;
  bool get isConnected => _isConnected;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    try {
      // Check initial connectivity
      final result = await _connectivity.checkConnectivity();
      _isConnected = _hasInternetConnection(result);
      
      // Listen to connectivity changes
      _subscription = _connectivity.onConnectivityChanged.listen((result) {
        final wasConnected = _isConnected;
        _isConnected = _hasInternetConnection(result);
        
        if (wasConnected != _isConnected) {
          if (kDebugMode) {
            debugPrint('📡 Connectivity changed: ${_isConnected ? "ONLINE" : "OFFLINE"}');
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error initializing connectivity service: $e');
      }
      // Assume connected on error
      _isConnected = true;
    }
  }

  /// Check if device has internet connection based on connectivity result
  bool _hasInternetConnection(List<ConnectivityResult> results) {
    // Consider connected if any non-none connection exists
    return results.any((result) => 
      result == ConnectivityResult.mobile ||
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.ethernet
    );
  }

  /// Check current connectivity status (one-time check)
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isConnected = _hasInternetConnection(result);
      return _isConnected;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error checking connectivity: $e');
      }
      // Assume connected on error
      return true;
    }
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
  }
}

