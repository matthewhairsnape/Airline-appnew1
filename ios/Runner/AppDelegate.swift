import Flutter
import UIKit
import OtplessSDK
import Firebase
import FirebaseMessaging
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Firebase
    FirebaseApp.configure()
    
    // CRITICAL: Set UNUserNotificationCenter delegate for foreground notifications
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      
      // Request standard notification permissions
      var authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      
      // CRITICAL for iOS 15+: Request time-sensitive notification permission
      // This prevents notifications from auto-dismissing
      if #available(iOS 15.0, *) {
        authOptions.insert(.timeSensitive)
      }
      
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { granted, error in
          if let error = error {
            print("❌ Notification permission error: \(error)")
          } else {
            print("✅ Notification permission granted: \(granted)")
          }
        }
      )
    }
    
    application.registerForRemoteNotifications()
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // CRITICAL: This makes notifications show when app is in FOREGROUND
  // and prevents them from auto-dismissing
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Show notification even when app is in foreground
    // CRITICAL: Include .list to keep notifications visible in notification center
    // The .list option ensures notifications stay visible until user dismisses them
    if #available(iOS 14.0, *) {
      let options: UNNotificationPresentationOptions = [.banner, .sound, .badge, .list]
      completionHandler(options)
    } else {
      completionHandler([[.alert, .sound, .badge]])
    }
  }
  
  // Handle notification tap
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    completionHandler()
  }

override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
if Otpless.sharedInstance.isOtplessDeeplink(url: url){
Otpless.sharedInstance.processOtplessDeeplink(url: url)
	return true
}
	super.application(app, open: url, options: options)
	return true
}
}