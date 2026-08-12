import Foundation

/// Which Eat day-strip selection a deep link should apply.
/// Same-day widget / Live Activity / Favorite / Opening Alert links omit `date`
/// — those must force today so a stuck future DayStrip doesn't keep
/// `browsingFutureDay` and snap the wrong meal pill.
public enum EatDeepLinkBrowseDay {
    public enum Decision: Equatable, Sendable {
        /// Leave the current DayStrip selection alone (bare `anteats://eat`).
        case keep
        /// Clear future browse — live today (`selectedDate = nil`).
        case today
        /// Browse a future ISO day (`selectedDate = iso`).
        case future(iso: String)
    }

    /// - Parameters:
    ///   - linkDate: Explicit `date=` query (nil when omitted).
    ///   - todayISO: Irvine today.
    ///   - forcesTodayWhenDateOmitted: True when the link carries hall / period /
    ///     dish intent for *today's* live board (no `date=`).
    public static func resolve(
        linkDate: String?,
        todayISO: String?,
        forcesTodayWhenDateOmitted: Bool
    ) -> Decision {
        if let linkDate {
            let trimmed = linkDate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return forcesTodayWhenDateOmitted ? .today : .keep
            }
            if let todayISO, trimmed == todayISO {
                return .today
            }
            return .future(iso: trimmed)
        }
        return forcesTodayWhenDateOmitted ? .today : .keep
    }
}
