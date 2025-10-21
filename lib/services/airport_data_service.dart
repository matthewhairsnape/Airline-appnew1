import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:airline_app/services/supabase_service.dart';
import 'package:airline_app/utils/global_variable.dart';

class AirportDataService {
  static const String _baseUrl = 'https://api.flightstats.com/flex/airports/rest/v1/json';

  /// Fetch comprehensive airport data from Cirium API
  static Future<Map<String, dynamic>?> fetchAirportData(String iataCode) async {
    try {
      debugPrint('🌐 Fetching airport data for: $iataCode');
      
      final url = '$_baseUrl/iata/$iataCode?appId=$ciriumAppId&appKey=$ciriumAppKey';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final airports = data['airports'] as List?;
        
        if (airports != null && airports.isNotEmpty) {
          final airport = airports.first as Map<String, dynamic>;
          debugPrint('✅ Airport data fetched successfully for $iataCode');
          return _parseAirportData(airport);
        } else {
          debugPrint('❌ No airport data found for $iataCode');
          return null;
        }
      } else {
        debugPrint('❌ Failed to fetch airport data: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error fetching airport data: $e');
      return null;
    }
  }

  /// Parse airport data from Cirium API response
  static Map<String, dynamic> _parseAirportData(Map<String, dynamic> airport) {
    return {
      'iata_code': airport['iata'] as String?,
      'icao_code': airport['icao'] as String?,
      'name': airport['name'] as String?,
      'city': airport['city'] as String?,
      'country': airport['countryName'] as String?,
      'latitude': airport['latitude'] as double?,
      'longitude': airport['longitude'] as double?,
      'timezone': airport['timezoneRegionName'] as String?,
      'elevation': airport['elevationFeet'] as int?,
      'country_code': airport['countryCode'] as String?,
      'region_name': airport['regionName'] as String?,
    };
  }

  /// Save or update airport data in Supabase
  static Future<Map<String, dynamic>?> saveAirportData(Map<String, dynamic> airportData) async {
    if (!SupabaseService.isInitialized) {
      debugPrint('❌ Supabase not initialized');
      return null;
    }

    try {
      final iataCode = airportData['iata_code'] as String?;
      if (iataCode == null || iataCode.isEmpty) {
        debugPrint('❌ Invalid IATA code');
        return null;
      }

      // Check if airport already exists
      final existingAirport = await SupabaseService.client
          .from('airports')
          .select('id, iata_code, icao_code, name, city, country, latitude, longitude, timezone')
          .eq('iata_code', iataCode)
          .maybeSingle();

      if (existingAirport != null) {
        // Update existing airport with new data
        debugPrint('🔄 Updating existing airport: $iataCode');
        
        final updateData = {
          'icao_code': airportData['icao_code'],
          'name': airportData['name'],
          'city': airportData['city'],
          'country': airportData['country'],
          'latitude': airportData['latitude'],
          'longitude': airportData['longitude'],
          'timezone': airportData['timezone'],
        };
        
        final updatedAirport = await SupabaseService.client
            .from('airports')
            .update(updateData)
            .eq('iata_code', iataCode)
            .select()
            .single();

        debugPrint('✅ Airport updated successfully: ${updatedAirport['name']}');
        return updatedAirport;
      } else {
        // Create new airport
        debugPrint('🆕 Creating new airport: $iataCode');
        
        final newAirport = await SupabaseService.client
            .from('airports')
            .insert({
              'iata_code': airportData['iata_code'],
              'icao_code': airportData['icao_code'],
              'name': airportData['name'],
              'city': airportData['city'],
              'country': airportData['country'],
              'latitude': airportData['latitude'],
              'longitude': airportData['longitude'],
              'timezone': airportData['timezone'],
              'created_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

        debugPrint('✅ Airport created successfully: ${newAirport['name']}');
        return newAirport;
      }
    } catch (e) {
      debugPrint('❌ Error saving airport data: $e');
      return null;
    }
  }

  /// Get or create airport data for both departure and arrival airports
  static Future<Map<String, Map<String, dynamic>?>> getOrCreateAirportData({
    required String departureIata,
    required String arrivalIata,
  }) async {
    final result = <String, Map<String, dynamic>?>{};

    // Process departure airport
    debugPrint('🛫 Processing departure airport: $departureIata');
    result['departure'] = await _processAirport(departureIata);

    // Process arrival airport
    debugPrint('🛬 Processing arrival airport: $arrivalIata');
    result['arrival'] = await _processAirport(arrivalIata);

    return result;
  }

  /// Process individual airport (fetch from API and save to database)
  static Future<Map<String, dynamic>?> _processAirport(String iataCode) async {
    try {
      // First check if airport exists in database
      final existingAirport = await SupabaseService.client
          .from('airports')
          .select('id, iata_code, icao_code, name, city, country, latitude, longitude, timezone')
          .eq('iata_code', iataCode)
          .maybeSingle();

      if (existingAirport != null) {
        debugPrint('✅ Airport found in database: ${existingAirport['name']}');
        return existingAirport;
      }

      // Airport not found, fetch from Cirium API
      debugPrint('🔍 Airport not found in database, fetching from Cirium API');
      final airportData = await fetchAirportData(iataCode);
      
      if (airportData != null) {
        // Save to database
        final savedAirport = await saveAirportData(airportData);
        return savedAirport;
      } else {
        debugPrint('❌ Could not fetch airport data from Cirium API');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error processing airport $iataCode: $e');
      return null;
    }
  }

  /// Extract airport data from Cirium flight status response
  static Map<String, dynamic>? extractAirportDataFromFlightStatus(
    Map<String, dynamic> flightStatus,
    String airportType, // 'departure' or 'arrival'
  ) {
    try {
      final airportKey = airportType == 'departure' 
          ? 'departureAirportFsCode' 
          : 'arrivalAirportFsCode';
      
      final airportFsCode = flightStatus[airportKey] as String?;
      if (airportFsCode == null) return null;

      // Look for airport resources in the flight status
      final airportResources = flightStatus['airportResources'] as Map<String, dynamic>?;
      if (airportResources == null) return null;

      // Extract airport data from resources
      final airportData = airportResources[airportType] as Map<String, dynamic>?;
      if (airportData == null) return null;

      return {
        'iata_code': airportFsCode,
        'icao_code': airportData['icao'] as String?,
        'name': airportData['name'] as String?,
        'city': airportData['city'] as String?,
        'country': airportData['countryName'] as String?,
        'latitude': airportData['latitude'] as double?,
        'longitude': airportData['longitude'] as double?,
        'timezone': airportData['timezoneRegionName'] as String?,
      };
    } catch (e) {
      debugPrint('❌ Error extracting airport data from flight status: $e');
      return null;
    }
  }

  /// Get airport data by IATA code from database
  static Future<Map<String, dynamic>?> getAirportByIata(String iataCode) async {
    if (!SupabaseService.isInitialized) return null;

    try {
      final airport = await SupabaseService.client
          .from('airports')
          .select('id, iata_code, icao_code, name, city, country, latitude, longitude, timezone')
          .eq('iata_code', iataCode)
          .maybeSingle();

      return airport;
    } catch (e) {
      debugPrint('❌ Error getting airport by IATA: $e');
      return null;
    }
  }
}
