import 'package:flutter_riverpod/flutter_riverpod.dart';

class AviationInfoState {
  final Map<String, dynamic> airlineData;
  final Map<String, dynamic> departureData;
  final Map<String, dynamic> arrivalData;
  final String selectedClassOfTravel;
  final int? index;

  AviationInfoState({
    this.airlineData = const {},
    this.departureData = const {},
    this.arrivalData = const {},
    this.selectedClassOfTravel = '',
    this.index,
  });

  AviationInfoState copyWith({
    Map<String, dynamic>? airlineData,
    Map<String, dynamic>? departureData,
    Map<String, dynamic>? arrivalData,
    String? selectedClassOfTravel,
    int? index,
  }) {
    return AviationInfoState(
      airlineData: airlineData ?? this.airlineData,
      departureData: departureData ?? this.departureData,
      arrivalData: arrivalData ?? this.arrivalData,
      selectedClassOfTravel: selectedClassOfTravel ?? this.selectedClassOfTravel,
      index: index ?? this.index,
    );
  }
}

class AirlineInfoNotifier extends StateNotifier<AviationInfoState> {
  AirlineInfoNotifier() : super(AviationInfoState());

  void updateAirlineData(Map<String, dynamic> data) {
    state = state.copyWith(airlineData: data);
  }

  void updateDepartureData(Map<String, dynamic> data) {
    state = state.copyWith(departureData: data);
  }

  void updateArrivalData(Map<String, dynamic> data) {
    state = state.copyWith(arrivalData: data);
  }

  void updateClassOfTravel(String value) {
    state = state.copyWith(selectedClassOfTravel: value);
  }

  void updateIndex(int value) {
    state = state.copyWith(index: value);
  }

  void resetState() {
    state = AviationInfoState();
  }
}

final aviationInfoProvider =
    StateNotifierProvider<AirlineInfoNotifier, AviationInfoState>((ref) {
  return AirlineInfoNotifier();
});
