import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Firebase
    FirebaseApp.configure()

    // Lets notifications show while the app is in the foreground.
    UNUserNotificationCenter.current().delegate = self

    // No permission prompt here. Asking at first launch, before the person
    // has signed in or seen what the app is for, is the prompt most people
    // refuse; the app asks from Dart (firebase_messaging requestPermission)
    // once they are signed in.
    //
    // Registering for remote notifications does not prompt. It fetches the
    // APNs device token, which firebase_messaging needs before it can issue
    // an FCM token -- so it stays at launch.
    application.registerForRemoteNotifications()

    // Set Firebase Messaging delegate
    Messaging.messaging().delegate = self

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle APNs token registration
  override func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    // The token is read and sent to the server by the Flutter plugin. It is
    // not printed: device logs are readable by anything attached to them.
  }
}
