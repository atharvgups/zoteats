import Foundation

/// Public App Store listing for Anteats. Id `6790896660` is the live
/// https://apps.apple.com/us/app/anteats/id6790896660 page (same Apple ID
/// App Store Connect uses for com.atharvgupta.zoteats). Never invent a URL.
public enum AnteatsShare: Sendable {
    public static let appStoreURLString = "https://apps.apple.com/us/app/anteats/id6790896660"
    public static let appStoreURL = URL(string: appStoreURLString)!
    public static let message =
        "Anteats shows today's UCI dining board, campus hours, and a quiet library."
    public static let shareText = "\(message)\n\(appStoreURLString)"
    public static let rowTitle = "Share Anteats"
    public static let rowSubtitle = "Send the App Store link"
}
