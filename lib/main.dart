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
import 'package:airline_app/services/push_notification_service.dart';
import 'package:airline_app/services/connectivity_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
import 'package:airline_app/screen/test_push_notification_screen.dart';
import 'package:airline_app/widgets/in_app_notification_banner.dart';
import 'package:airline_app/utils/app_localizations.dart';
import 'package:airline_app/utils/app_routes.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

/// CRITICAL: Background message handler for when app is terminated
/// This MUST be a top-level function (not inside a class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  if (kDebugMode) {
    debugPrint('🔔 Background message received (app terminated)');
    debugPrint('   Title: ${message.notification?.title}');
    debugPrint('   Body: ${message.notification?.body}');
    debugPrint('   Data: ${message.data}');
  }
  
  // Initialize local notifications
  final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
  
  const AndroidInitializationSettings androidSettings = 
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  
  await localNotifications.initialize(initSettings);
  
  // Create Android notification channel
  if (!kIsWeb && Platform.isAndroid) {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
      playSound: true,
    );
    
    await localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
  
  // Show notification
  if (message.notification != null) {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );
    
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification!.title ?? 'Notification',
      message.notification!.body ?? '',
      platformDetails,
      payload: message.data.toString(),
    );
    
    if (kDebugMode) {
      debugPrint('✅ Notification displayed successfully');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final String languageCode = prefs.getString('selectedLanguageSym') ?? 'en';

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // CRITICAL: Register background message handler IMMEDIATELY after Firebase init
    // This ensures notifications work when app is terminated
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    if (kDebugMode) {
      debugPrint('✅ Background message handler registered');
    }
  } catch (e) {
    // Firebase initialization failed - app will continue without Firebase features
    debugPrint('⚠️ Firebase initialization failed: $e');
  }

  try {
    await SupabaseService.initialize();
  } catch (e) {
    // Supabase initialization failed - app will continue with limited functionality
    if (kDebugMode) {
      debugPrint('⚠️ Supabase initialization failed: $e');
    }
  }

  try {
    await SimpleDataFlowService.instance.initialize();
  } catch (e) {
    // Data flow service initialization failed - app will continue
    if (kDebugMode) {
      debugPrint('⚠️ SimpleDataFlowService initialization failed: $e');
    }
  }

  // Initialize Push Notification Service (Main FCM service)
  // IMPORTANT: This MUST run BEFORE JourneyNotificationService
  // PushNotificationService requests notification permission (once)
  // JourneyNotificationService just checks if permission was granted
  try {
    await PushNotificationService.initialize();
    if (kDebugMode) {
      debugPrint('✅ PushNotificationService initialized successfully');
    }
  } catch (e) {
    // Continue app even if push notifications fail
    if (kDebugMode) {
      debugPrint('⚠️ PushNotificationService initialization failed: $e');
    }
  }

  try {
    await NotificationManager().initialize();
    if (kDebugMode) {
      debugPrint('✅ NotificationManager initialized successfully');
    }
  } catch (e) {
    // Notification manager initialization failed - non-critical
    if (kDebugMode) {
      debugPrint('⚠️ NotificationManager initialization failed: $e');
    }
  }

  // Initialize Journey Notification Service
  // This service does NOT request permission (to avoid double prompt)
  // It only initializes if permission was already granted by PushNotificationService
  try {
    await JourneyNotificationService.initialize();
    if (kDebugMode) {
      debugPrint('✅ JourneyNotificationService initialized successfully');
    }
  } catch (e) {
    // Journey notification service initialization failed - non-critical
    if (kDebugMode) {
      debugPrint('⚠️ JourneyNotificationService initialization failed: $e');
    }
  }

  // Initialize Connectivity Service for offline support
  try {
    await ConnectivityService().initialize();
    if (kDebugMode) {
      debugPrint('✅ ConnectivityService initialized successfully');
    }
  } catch (e) {
    // Connectivity service initialization failed - non-critical
    if (kDebugMode) {
      debugPrint('⚠️ ConnectivityService initialization failed: $e');
    }
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
  
  // Global key for navigator to access overlay
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Build routes - excludes test routes in production
  Map<String, WidgetBuilder> _buildRoutes() {
    final routes = <String, WidgetBuilder>{
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
    };

    // Only add test routes in debug mode
    if (kDebugMode) {
      routes[AppRoutes.testPushNotification] = 
          (context) => const TestPushNotificationScreen();
    }

    return routes;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return MaterialApp(
      navigatorKey: navigatorKey,
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
      builder: (context, child) {
        // Set up foreground notification callback for in-app banner
        PushNotificationService.onForegroundNotification = (title, body, data) {
          // Use post-frame callback to ensure overlay is ready
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Get the navigator state and its overlay directly
            final navigatorState = navigatorKey.currentState;
            if (navigatorState != null && navigatorState.mounted) {
              // Get the overlay from the navigator's context
              final overlayContext = navigatorState.overlay?.context;
              if (overlayContext != null && overlayContext.mounted) {
                if (kDebugMode) {
                  debugPrint('📍 Showing in-app notification banner');
                }
                // Show in-app notification banner when app is in foreground
                InAppNotificationBanner.show(
                  overlayContext,
                  title: title,
                  body: body,
                  onTap: () {
                    if (kDebugMode) {
                      debugPrint('In-app notification tapped: $title');
                    }
                    // Handle notification tap - you can add navigation logic here
                  },
                  displayDuration: const Duration(seconds: 5),
                  icon: Icons.flight_takeoff,
                );
              } else if (kDebugMode) {
                debugPrint('⚠️ Overlay context not available for in-app banner');
              }
            } else if (kDebugMode) {
              debugPrint('⚠️ Navigator state not available for in-app banner');
            }
          });
        };
        return child ?? const SizedBox.shrink();
      },
      initialRoute: AppRoutes.skipscreen,
      routes: _buildRoutes(),
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
