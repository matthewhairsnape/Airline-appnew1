import 'package:airline_app/screen/feed/feed_filter_screen.dart';
import 'package:airline_app/screen/feed/feed_screen.dart';
import 'package:airline_app/screen/leaderboard/leaderboard_filter_screen.dart';
import 'package:airline_app/screen/leaderboard/media_full_screen.dart';
import 'package:airline_app/screen/login/log_in.dart';
import 'package:airline_app/screen/settings/settings_screen.dart';
import 'package:airline_app/services/supabase_service.dart';
import 'package:airline_app/services/simple_data_flow_service.dart';
import 'package:airline_app/services/notification_manager.dart';
import 'package:airline_app/services/journey_notification_service.dart';
import 'package:airline_app/screen/logIn/skip_screen.dart';
import 'package:airline_app/screen/leaderboard/detail_airport.dart';
import 'package:airline_app/screen/leaderboard/leaderboard_screen.dart';
import 'package:airline_app/screen/profile/about_app.dart';
import 'package:airline_app/screen/profile/edit_profile_screen.dart';
import 'package:airline_app/screen/profile/help_faq.dart';
import 'package:airline_app/screen/profile/notifications_screen.dart';
import 'package:airline_app/screen/profile/profile_screen.dart';
import 'package:airline_app/screen/profile/terms_of_service.dart';
import 'package:airline_app/provider/selected_language_provider.dart';
import 'package:airline_app/screen/reviewsubmission/complete_reviews.dart';
import 'package:airline_app/screen/reviewsubmission/review_airline/detail_first_screen_for_airline.dart';
import 'package:airline_app/screen/reviewsubmission/review_airline/detail_second_screen_for_airline.dart';
import 'package:airline_app/screen/reviewsubmission/review_airline/question_first_screen_for_airline.dart';
import 'package:airline_app/screen/reviewsubmission/review_airline/question_second_screen_for_airline.dart';
import 'package:airline_app/screen/reviewsubmission/review_airport/detail_first_screen_for_airport.dart';
import 'package:airline_app/screen/reviewsubmission/review_airport/detail_second_screen_for_airport.dart';
import 'package:airline_app/screen/reviewsubmission/review_airport/question_first_screen_for_airport.dart';
import 'package:airline_app/screen/reviewsubmission/review_airport/question_second_screen_for_airport.dart';
import 'package:airline_app/screen/reviewsubmission/reviewsubmission_screen.dart';
import 'package:airline_app/screen/reviewsubmission/start_reviews.dart';
import 'package:airline_app/screen/reviewsubmission/submit_screen.dart';
import 'package:airline_app/screen/journey/my_journey_screen.dart';
import 'package:airline_app/screen/issues/issues_screen.dart';
import 'package:airline_app/utils/app_localizations.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final String languageCode = prefs.getString('selectedLanguageSym') ?? 'en';

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase initialization failed
  }

  try {
    await SupabaseService.initialize();
  } catch (e) {
    // Supabase initialization failed
  }

  try {
    await SimpleDataFlowService.instance.initialize();
  } catch (e) {
    // Data flow service initialization failed
  }

  try {
    await NotificationManager().initialize();
    debugPrint('✅ NotificationManager initialized successfully');
  } catch (e) {
    debugPrint('❌ NotificationManager initialization failed: $e');
    // Notification manager initialization failed
  }

  try {
    await JourneyNotificationService.initialize();
  } catch (e) {
    // Journey notification service initialization failed
  }

  runApp(
    ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => Locale(languageCode)),
        selectedLanguageProvider.overrideWith(
            (ref) => SelectedLanguageProvider()..changeLanguage(languageCode)),
      ],
      child: const MyApp(),
    ),
  );
}

final localeProvider = StateProvider<Locale>((ref) => const Locale('en'));

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return MaterialApp(
      locale: locale,
      supportedLocales: const [
        Locale('en', ''),
        Locale('zh', ''),
        Locale('es', ''),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      title: 'Airline App',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
        ),
        bottomSheetTheme:
            const BottomSheetThemeData(backgroundColor: Colors.white),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CustomPageTransitionBuilder(),
            TargetPlatform.iOS: CustomPageTransitionBuilder(),
          },
        ),
      ),
      initialRoute: AppRoutes.skipscreen,
      routes: {
        AppRoutes.loginscreen: (context) => const Login(),
        AppRoutes.skipscreen: (context) => const SkipScreen(),
        AppRoutes.startreviews: (context) => const StartReviews(),
        AppRoutes.reviewsubmissionscreen: (context) =>
            const ReviewsubmissionScreen(),
        AppRoutes.feedscreen: (context) => const FeedScreen(),
        AppRoutes.feedfilterscreen: (context) => const FeedFilterScreen(),
        AppRoutes.leaderboardscreen: (context) => const LeaderboardScreen(),
        AppRoutes.detailairport: (context) => const DetailAirport(),
        AppRoutes.mediafullscreen: (context) => const MediaFullScreen(),
        AppRoutes.profilescreen: (context) => const ProfileScreen(),
        AppRoutes.filterscreen: (context) => const LeaderboardFilterScreen(),
        AppRoutes.cardnotificationscreen: (context) =>
            const NotificationsScreen(),
        AppRoutes.questionfirstscreenforairline: (context) =>
            const QuestionFirstScreenForAirline(),
        AppRoutes.detailfirstscreenforairline: (context) =>
            const DetailFirstScreenForAirline(),
        AppRoutes.questionsecondscreenforairline: (context) =>
            const QuestionSecondScreenForAirline(),
        AppRoutes.detailsecondscreenforairline: (context) =>
            const DetailSecondScreenForAirline(),
        AppRoutes.questionfirstscreenforairport: (context) =>
            const QuestionFirstScreenForAirport(),
        AppRoutes.detailfirstscreenforairport: (context) =>
            const DetailFirstScreenForAirport(),
        AppRoutes.questionsecondscreenforairport: (context) =>
            const QuestionSecondScreenForAirport(),
        AppRoutes.detailsecondscreenforairport: (context) =>
            const DetailSecondScreenForAirport(),
        AppRoutes.submitscreen: (context) => const SubmitScreen(),
        AppRoutes.completereviews: (context) => const CompleteReviews(),
        AppRoutes.eidtprofilescreen: (context) => const EditProfileScreen(),
        AppRoutes.aboutapp: (context) => const AboutApp(),
        AppRoutes.helpFaqs: (context) => const HelpFaq(),
        AppRoutes.termsofservice: (context) => const TermsOfService(),
        AppRoutes.myJourney: (context) => const MyJourneyScreen(),
        AppRoutes.settingsscreen: (context) => const SettingsScreen(),
        AppRoutes.issuesScreen: (context) => const IssuesScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class CustomPageTransitionBuilder extends PageTransitionsBuilder {
  const CustomPageTransitionBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      )),
      child: child,
    );
  }
}
