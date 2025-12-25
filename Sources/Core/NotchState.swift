import Foundation

extension Notification.Name {
    static let notchStateDidChange = Notification.Name("NotchBuddy.NotchStateDidChange")
}

@MainActor
final class NotchState: ObservableObject {
    static let shared = NotchState()

    private init() {}

    @Published var isExpanded: Bool = false {
        didSet {
            guard oldValue != isExpanded else { return }
            NotificationCenter.default.post(name: .notchStateDidChange, object: nil)
        }
    }

    /// When pinned, the overlay stays expanded even after the mouse leaves.
    @Published var isPinned: Bool = false

    @Published var selectedTab: NotchTopTab = .tray

    @Published var isDraggingOver: Bool = false

    @Published var activeDropZone: NotchBuddyDropZone? = nil
}

enum NotchBuddyDropZone {
    case store
    case airdrop
}

enum NotchTopTab {
    case home
    case tray
}
