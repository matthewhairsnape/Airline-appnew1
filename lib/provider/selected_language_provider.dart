import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedLanguageProvider extends StateNotifier<String?> {
  SelectedLanguageProvider() : super(null);

  void changeLanguage(String index) {
    state = index;
  }
}

final selectedLanguageProvider =
    StateNotifierProvider<SelectedLanguageProvider, String?>((ref) {
  return SelectedLanguageProvider();
});
