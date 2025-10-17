// lib/main.dart
import 'package:airline_app/screen/feed/feed_filter_screen.dart';
import 'package:airline_app/screen/feed/feed_screen.dart';
import 'package:airline_app/screen/leaderboard/leaderboard_filter_screen.dart';
import 'package:airline_app/screen/leaderboard/media_full_screen.dart';
import 'package:airline_app/screen/login/log_in.dart';
import 'package:airline_app/services/supabase_service.dart';
import 'package:airline_app/services/simple_data_flow_service.dart';
import 'package:airline_app/services/notification_manager.dart';
import 'package:airline_app/services/journey_notification_service.dart';
import 'package:airline_app/screen/login/skip_screen.dart';
import 'package:airline_app/screen/leaderboard/detail_airport.dart';
import 'package:airline_app/screen/leaderboard/leaderboard_screen.dart';
import 'package:airline_app/widgets/auth_wrapper.dart';
import 'package:airline_app/screen/profile/about_app.dart';
import 'package:airline_app/screen/profile/edit_profile_screen.dart';
import 'package:airline_app/screen/profile/help_faq.dart';
import 'package:airline_app/screen/profile/notifications_screen.dart';
import 'package:airline_app/screen/profile/profile_screen.dart';
import 'package:airline_app/screen/profile/terms_of_service.dart';
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

  // Get saved language before initializing rest of the app
  final prefs = await SharedPreferences.getInstance();
  final String languageCode = prefs.getString('selectedLanguageSym') ?? 'en';

  // Init Firebase, Supabase, other services with defensive error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized');
  } catch (e, st) {
    debugPrint('❌ Firebase init failed: $e\n$st');
    // You can choose to proceed or exit; here we proceed but log the error.
  }

  try {
    await SupabaseService.initialize(); // uses String.fromEnvironment defaults
    debugPrint('✅ SupabaseService.initialize completed');
  } catch (e, st) {
    debugPrint('❌ Supabase init failed: $e\n$st');
    // If Supabase is critical for the app, consider showing an error UI instead of proceeding.
  }

  try {
    await SimpleDataFlowService.instance.initialize();
    debugPrint('✅ SimpleDataFlowService initialized');
  } catch (e, st) {
    debugPrint('❌ SimpleDataFlowService init failed: $e\n$st');
  }

  try {
    await NotificationManager().initialize();
    debugPrint('✅ NotificationManager initialized');
  } catch (e, st) {
    debugPrint('❌ NotificationManager init failed: $e\n$st');
  }

  try {
    await JourneyNotificationService.initialize();
    debugPrint('✅ JourneyNotificationService initialized');
  } catch (e, st) {
    debugPrint('❌ JourneyNotificationService init failed: $e\n$st');
  }

  runApp(
    ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => Locale(languageCode)),
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
        bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.white),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CustomPageTransitionBuilder(),
            TargetPlatform.iOS: CustomPageTransitionBuilder(),
          },
        ),
      ),
      routes: {
        // Public routes (no authentication required)
        AppRoutes.loginscreen: (context) => const Login(),
        AppRoutes.skipscreen: (context) => const SkipScreen(),
        
        // Protected routes (authentication required)
        AppRoutes.startreviews: (context) => const AuthWrapper(child: StartReviews()),
        AppRoutes.reviewsubmissionscreen: (context) =>
            const AuthWrapper(child: ReviewsubmissionScreen()),
        AppRoutes.feedscreen: (context) => const AuthWrapper(child: FeedScreen()),
        AppRoutes.feedfilterscreen: (context) => const AuthWrapper(child: FeedFilterScreen()),
        AppRoutes.leaderboardscreen: (context) => const AuthWrapper(child: LeaderboardScreen()),
        AppRoutes.detailairport: (context) => const AuthWrapper(child: DetailAirport()),
        AppRoutes.mediafullscreen: (context) => const AuthWrapper(child: MediaFullScreen()),
        AppRoutes.profilescreen: (context) => const AuthWrapper(child: ProfileScreen()),
        AppRoutes.filterscreen: (context) => const AuthWrapper(child: LeaderboardFilterScreen()),
        AppRoutes.cardnotificationscreen: (context) => const AuthWrapper(child: NotificationsScreen()),
        AppRoutes.questionfirstscreenforairline: (context) =>
            const AuthWrapper(child: QuestionFirstScreenForAirline()),
        AppRoutes.detailfirstscreenforairline: (context) =>
            const AuthWrapper(child: DetailFirstScreenForAirline()),
        AppRoutes.questionsecondscreenforairline: (context) =>
            const AuthWrapper(child: QuestionSecondScreenForAirline()),
        AppRoutes.detailsecondscreenforairline: (context) =>
            const AuthWrapper(child: DetailSecondScreenForAirline()),
        AppRoutes.questionfirstscreenforairport: (context) =>
            const AuthWrapper(child: QuestionFirstScreenForAirport()),
        AppRoutes.detailfirstscreenforairport: (context) =>
            const AuthWrapper(child: DetailFirstScreenForAirport()),
        AppRoutes.questionsecondscreenforairport: (context) =>
            const AuthWrapper(child: QuestionSecondScreenForAirport()),
        AppRoutes.detailsecondscreenforairport: (context) =>
            const AuthWrapper(child: DetailSecondScreenForAirport()),
        AppRoutes.submitscreen: (context) => const AuthWrapper(child: SubmitScreen()),
        AppRoutes.completereviews: (context) => const AuthWrapper(child: CompleteReviews()),
        AppRoutes.eidtprofilescreen: (context) => const AuthWrapper(child: EditProfileScreen()),
        AppRoutes.aboutapp: (context) => const AuthWrapper(child: AboutApp()),
        AppRoutes.helpFaqs: (context) => const AuthWrapper(child: HelpFaq()),
        AppRoutes.termsofservice: (context) => const AuthWrapper(child: TermsOfService()),
        AppRoutes.myJourney: (context) => const AuthWrapper(child: MyJourneyScreen()),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class CustomPageTransitionBuilder extends PageTransitionsBuilder {
  const CustomPageTransitionBuilder(); // <- add this
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
