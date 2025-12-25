import AppKit
import Combine

@MainActor
final class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    
    @Published var history: [ClipboardItem] = []
    @Published var isMonitoring = false
    
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    
    private init() {}
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        lastChangeCount = NSPasteboard.general.changeCount

        // Capture the current clipboard immediately so the UI isn't blank until the next copy.
        captureCurrentPasteboardItem()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPasteboard()
            }
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
    }
    
    private func checkPasteboard() {
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        captureCurrentPasteboardItem()
    }

    private func captureCurrentPasteboardItem() {
        // Text
        if let str = NSPasteboard.general.string(forType: .string), !str.isEmpty {
            let item = ClipboardItem(content: str, type: .text, fileURL: nil)
            history.insert(item, at: 0)
            trimHistory()
            return
        }

        // File URLs (best-effort)
        if let urls = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], let first = urls.first {
            let item = ClipboardItem(content: first.lastPathComponent, type: .file, fileURL: first)
            history.insert(item, at: 0)
            trimHistory()
            return
        }
    }

    private func trimHistory() {
        if history.count > 20 {
            history.removeLast(history.count - 20)
        }
    }
}

struct ClipboardItem: Identifiable {
    let id = UUID()
    let content: String
    let type: ClipboardType
    let fileURL: URL?
    let date = Date()
}

enum ClipboardType {
    case text
    case image
    case file
}
