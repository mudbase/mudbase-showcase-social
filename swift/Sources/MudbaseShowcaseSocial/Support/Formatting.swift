import Foundation

/// Mirrors `../web/src/lib/utils.ts`'s `formatRelativeTime` — short, social-feed-style relative
/// timestamps ("3m", "2h", "5d") rather than a full date, using the platform's own
/// `RelativeDateTimeFormatter` for anything older than a day so it still reads naturally in the
/// user's locale.
enum Formatting {
    static func relativeTime(from date: Date?, now: Date = Date()) -> String {
        guard let date else { return "" }
        let seconds = max(0, now.timeIntervalSince(date))

        switch seconds {
        case ..<60:
            return "now"
        case ..<3600:
            return "\(Int(seconds / 60))m"
        case ..<86400:
            return "\(Int(seconds / 3600))h"
        case ..<604800:
            return "\(Int(seconds / 86400))d"
        default:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}
