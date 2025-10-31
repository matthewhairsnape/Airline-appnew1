import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State class to manage airline and airport data
class AirlineAirportState {
  final List<Map<String, dynamic>> allData;
  final List<Map<String, dynamic>> airlineData;
  final List<Map<String, dynamic>> airportData;
  final List<Map<String, dynamic>> airlineScoreData;
  final List<Map<String, dynamic>> airportScoreData;
  final Map<String, Map<String, dynamic>> airportCache;
  final Map<String, Map<String, dynamic>> airlineCache;
  final Map<String, List<Map<String, dynamic>>> sortedListCache;
  final Map<String, Map<String, String>> continentCache;

  const AirlineAirportState({
    this.allData = const [],
    this.airlineData = const [],
    this.airportData = const [],
    this.airlineScoreData = const [],
    this.airportScoreData = const [],
    this.airportCache = const {},
    this.airlineCache = const {},
    this.sortedListCache = const {},
    this.continentCache = const {},
  });

  AirlineAirportState copyWith({
    List<Map<String, dynamic>>? allData,
    List<Map<String, dynamic>>? airlineData,
    List<Map<String, dynamic>>? airportData,
    List<Map<String, dynamic>>? airlineScoreData,
    List<Map<String, dynamic>>? airportScoreData,
    Map<String, Map<String, dynamic>>? airportCache,
    Map<String, Map<String, dynamic>>? airlineCache,
    Map<String, List<Map<String, dynamic>>>? sortedListCache,
    Map<String, Map<String, String>>? continentCache,
  }) {
    return AirlineAirportState(
      allData: allData ?? this.allData,
      airlineData: airlineData ?? this.airlineData,
      airportData: airportData ?? this.airportData,
      airlineScoreData: airlineScoreData ?? this.airlineScoreData,
      airportScoreData: airportScoreData ?? this.airportScoreData,
      airportCache: airportCache ?? this.airportCache,
      airlineCache: airlineCache ?? this.airlineCache,
      sortedListCache: sortedListCache ?? this.sortedListCache,
      continentCache: continentCache ?? this.continentCache,
    );
  }
}

/// Notifier class to manage airline and airport state
class AirlineAirportNotifier extends StateNotifier<AirlineAirportState> {
  AirlineAirportNotifier() : super(const AirlineAirportState());

  /// Sets the initial airline and airport data
  void setData(Map<String, dynamic> value) {
    final allData = List<Map<String, dynamic>>.from(value["data"] as List);
    state = AirlineAirportState(
      allData: allData,
    );
  }

  void appendData(Map<String, dynamic> value) {
    final newData = List<Map<String, dynamic>>.from(value["data"] as List);
    state = AirlineAirportState(
      allData: [...state.allData, ...newData],
    );
  }

  /// Retrieves airport data by IATA code
  Map<String, dynamic> getAirportData(String airportCode) {
    return state.airportCache[airportCode] ?? const <String, dynamic>{};
  }

  /// Retrieves airline data by IATA code
  Map<String, dynamic> getAirlineData(String airlineCode) {
    return state.airlineCache[airlineCode] ?? const <String, dynamic>{};
  }

  String getAirlineName(String airlineId) {
    final airline = state.airlineData.firstWhere(
      (airline) => airline['_id'] == airlineId,
      orElse: () => {'name': 'Unknown Airline'},
    );
    return airline['name'];
  }

  String getAirlineLogoImage(String airlineId) {
    final airline = state.airlineData.firstWhere(
      (airline) => airline['_id'] == airlineId,
      orElse: () => {'logoImage': ''},
    );
    return airline['logoImage'] ?? '';
  }

  String getAirlineBackgroundImage(String airlineId) {
    final airline = state.airlineData.firstWhere(
      (airline) => airline['_id'] == airlineId,
      orElse: () => {'backgroundImage': ''},
    );
    return airline['backgroundImage'] ?? '';
  }

  String getAirportName(String airportId) {
    final airport = state.airportData.firstWhere(
      (airport) => airport['_id'] == airportId,
      orElse: () => {'name': 'Unknown Airport'},
    );
    return airport['name'];
  }

  String getAirportLogoImage(String airportId) {
    final airport = state.airportData.firstWhere(
      (airport) => airport['_id'] == airportId,
      orElse: () => {'logoImage': ''},
    );
    return airport['logoImage'] ?? '';
  }

  String getAirportBackgroundImage(String airportId) {
    final airport = state.airportData.firstWhere(
      (airport) => airport['_id'] == airportId,
      orElse: () => {'backgroundImage': ''},
    );
    return airport['backgroundImage'] ?? '';
  }
}

/// Provider for airline and airport data management
final airlineAirportProvider =
    StateNotifierProvider<AirlineAirportNotifier, AirlineAirportState>((ref) {
  return AirlineAirportNotifier();
});
