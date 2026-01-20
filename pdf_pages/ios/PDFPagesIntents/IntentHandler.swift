import Intents

/// Handles Siri Shortcut intents for PDF Pages
class IntentHandler: INExtension {

    override func handler(for intent: INIntent) -> Any {
        // Return the appropriate intent handler
        if intent is ExtractPagesIntent {
            return ExtractPagesIntentHandler()
        }
        return self
    }
}

/// Handler for ExtractPagesIntent
class ExtractPagesIntentHandler: NSObject, ExtractPagesIntentHandling {

    func handle(intent: ExtractPagesIntent, completion: @escaping (ExtractPagesIntentResponse) -> Void) {
        // Get the page selection type
        let selectionType = intent.pageSelection

        // Since we can't directly extract pages without the PDF loaded,
        // we'll launch the main app with the intent parameters
        let response = ExtractPagesIntentResponse(code: .continueInApp, userActivity: nil)

        // Create user activity to pass to main app
        let userActivity = NSUserActivity(activityType: "com.pdfpages.extractPages")
        userActivity.userInfo = [
            "pageSelection": selectionType.rawValue
        ]

        let finalResponse = ExtractPagesIntentResponse(code: .continueInApp, userActivity: userActivity)
        completion(finalResponse)
    }

    func resolvePageSelection(for intent: ExtractPagesIntent, with completion: @escaping (PageSelectionTypeResolutionResult) -> Void) {
        if intent.pageSelection == .unknown {
            // Ask user to specify
            completion(.needsValue())
        } else {
            completion(.success(with: intent.pageSelection))
        }
    }
}
