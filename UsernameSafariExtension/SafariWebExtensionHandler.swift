//
//  SafariWebExtensionHandler.swift
//  UsernameSafariExtension
//
//  Answers the extension's native messages with usernames from the same generator the app uses,
//  with the options saved in the App Group. Nothing is stored and nothing leaves the device.
//

import SafariServices

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    static let countRange = 1...10

    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem
        let message = request?.userInfo?[SFExtensionMessageKey] as? [String: Any]

        var reply: [String: Any] = [:]
        if message?["action"] as? String == "generate" {
            let requested = (message?["count"] as? Int) ?? 1
            let count = min(max(requested, Self.countRange.lowerBound), Self.countRange.upperBound)
            reply["usernames"] = UsernameGenerator().generateBatch(options: SharedSettings.loadOptions(), count: count)
        }

        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: reply]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
}
