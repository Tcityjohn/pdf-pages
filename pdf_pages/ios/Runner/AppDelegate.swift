import Flutter
import UIKit
import Intents

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var speechHandler: SpeechRecognitionHandler?
  private var siriChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Initialize speech recognition handler
    if let controller = window?.rootViewController as? FlutterViewController {
      speechHandler = SpeechRecognitionHandler(messenger: controller.binaryMessenger)

      // Initialize Siri shortcuts channel
      siriChannel = FlutterMethodChannel(name: "com.pdfpages.siri", binaryMessenger: controller.binaryMessenger)
      siriChannel?.setMethodCallHandler { [weak self] (call, result) in
        self?.handleSiriMethodCall(call, result: result)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle user activity from Siri Shortcuts
  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if userActivity.activityType == "com.pdfpages.extractPages" {
      if let pageSelection = userActivity.userInfo?["pageSelection"] as? Int {
        // Send intent data to Flutter
        siriChannel?.invokeMethod("onSiriIntent", arguments: [
          "pageSelection": pageSelection
        ])
      }
      return true
    }

    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }

  private func handleSiriMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "donateShortcut":
      donateShortcut(call.arguments as? [String: Any], result: result)
    case "isAvailable":
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func donateShortcut(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
    guard let args = arguments,
          let selectionType = args["selectionType"] as? String else {
      result(false)
      return
    }

    // Create user activity for Siri suggestion
    let activity = NSUserActivity(activityType: "com.pdfpages.extractPages")
    activity.title = "Extract \(selectionType) from PDF"
    activity.isEligibleForSearch = true
    activity.isEligibleForPrediction = true
    activity.suggestedInvocationPhrase = "Extract \(selectionType) from my PDF"
    activity.userInfo = ["pageSelection": selectionType]

    // Make it current to donate
    activity.becomeCurrent()

    result(true)
  }
}
