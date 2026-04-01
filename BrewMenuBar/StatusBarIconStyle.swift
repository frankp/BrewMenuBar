import Foundation

enum StatusBarIconStyle: String, CaseIterable, Identifiable {
    static let userDefaultsKey = "statusBarIconStyle"

    case systemMug
    case flaskUp
    case bottleRefresh
    case terminalUp

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .systemMug:
            return "System Mug (Current)"
        case .flaskUp:
            return "Flask + Up Arrow"
        case .bottleRefresh:
            return "Bottle + Refresh"
        case .terminalUp:
            return "Terminal + Up Arrow"
        }
    }
}
