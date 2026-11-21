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
    if let registrar = self.registrar(forPlugin: "BackupExclusion") {
      BackupExclusion.register(with: registrar)
    }
    // The event-day card on the lock screen (EventDayActivities.swift).
    if let registrar = self.registrar(forPlugin: "EventDayActivities") {
      EventDayActivities.register(with: registrar)
    }
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // Opened from a quick action on the icon: UIKit calls
    // application(_:performActionFor:) next -- unless launching answered
    // false, when it is opened here instead.
    if !launched, let item = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem,
      let link = AppShortcuts.link(of: item)
    {
      DispatchQueue.main.async { _ = self.application(application, open: link, options: [:]) }
    }
    // A control (Control Center, the lock screen's buttons, the Action
    // button: Scan, My QR) opens its page the same way. The system runs its
    // intent here, in the app (ios/NextUpWidget/ControlIntents.swift), which
    // hands the page over -- or left it waiting, if it ran before this point.
    AppLinkHandoff.opener = { [weak self] link in
      _ = self?.application(application, open: link, options: [:])
    }
    if let waiting = AppLinkHandoff.takeWaiting() {
      DispatchQueue.main.async { _ = self.application(application, open: waiting, options: [:]) }
    }
    return launched
  }

  // A quick action on the app's icon (Info.plist UIApplicationShortcutItems):
  // Scan, My QR, Network, My tickets. Its link is opened as a link to the
  // website is, through Flutter's deep linking, so the app's router takes
  // it -- with sign-in first where the page needs an account.
  override func application(
    _ application: UIApplication,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) {
    guard let link = AppShortcuts.link(of: shortcutItem) else {
      super.application(
        application, performActionFor: shortcutItem, completionHandler: completionHandler)
      return
    }
    completionHandler(self.application(application, open: link, options: [:]))
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

// MARK: - Quick actions on the app's icon
/// The quick actions (touch and hold the icon) are static: Info.plist's
/// UIApplicationShortcutItems, each with the website address it opens under
/// `link` in its user info (docs/HOME_WIDGETS.md). The router reads the
/// address as the app's own page (lib/app/router/web_links.dart).
enum AppShortcuts {
  static let linkKey = "link"
  static let siteHost = "myotherapp.in"

  /// The link [item] opens: only an https address on the website.
  static func link(of item: UIApplicationShortcutItem) -> URL? {
    guard let text = item.userInfo?[linkKey] as? String,
      let url = URL(string: text),
      url.scheme == "https", url.host == siteHost
    else { return nil }
    return url
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

// MARK: - Folders left out of backups
/// Marks a folder or file of the app's own as not to be backed up to iCloud
/// or a computer, from Dart (lib/core/storage/backup_exclusion.dart): a
/// volunteer's unsent door scans, the person's kept tickets and
/// certificates. A folder marked this way is left out with everything in
/// it. Only paths inside the app's own container are accepted.
enum BackupExclusion {
  static let channelName = "finnet/backup"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "exclude" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let path = call.arguments as? String else {
        result(FlutterError(code: "bad_path", message: "exclude takes a path, a string", details: nil))
        return
      }
      exclude(path, result: result)
    }
  }

  private static func exclude(_ path: String, result: @escaping FlutterResult) {
    let home = URL(fileURLWithPath: NSHomeDirectory()).resolvingSymlinksInPath().path
    var url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
    guard url.path.hasPrefix(home + "/") else {
      result(FlutterError(code: "outside_app", message: "not one of the app's own files", details: nil))
      return
    }
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    do {
      try url.setResourceValues(values)
      result(nil)
    } catch {
      result(FlutterError(code: "exclude_failed", message: error.localizedDescription, details: nil))
    }
  }
}
