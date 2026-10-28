import Flutter
import UIKit
import UserNotifications
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
    if let registrar = self.registrar(forPlugin: "AppIconBadge") {
      AppIconBadge.register(with: registrar)
    }
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

// MARK: - The number on the app's icon
/// Sets the number on the app's icon from Dart (lib/core/services/app_badge.dart):
/// the person's unread inbox count, or 0. Pushes set it too (APNs' `badge`),
/// but only the app knows when lines are read, so it sets it whenever it
/// learns the count.
enum AppIconBadge {
  static let channelName = "finnet/app_badge"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "set" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let count = call.arguments as? Int else {
        result(FlutterError(code: "bad_count", message: "set takes the count, an int", details: nil))
        return
      }
      set(max(0, count), result: result)
    }
  }

  private static func set(_ count: Int, result: @escaping FlutterResult) {
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(count) { error in
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(code: "badge_failed", message: error.localizedDescription, details: nil))
          } else {
            result(nil)
          }
        }
      }
    } else {
      // Deprecated from iOS 17, which never reaches this branch.
      UIApplication.shared.applicationIconBadgeNumber = count
      result(nil)
    }
  }
}
