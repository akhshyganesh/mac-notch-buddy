import UniformTypeIdentifiers
import AppKit

@MainActor
final class DropManager: ObservableObject {
    static let shared = DropManager()
    
    @Published var isDropping: Bool = false
    
    private init() {}

    /// Used by the AppKit overlay window drag handler (Finder drops).
    func handleDroppedFiles(urls: [URL]) async -> Bool {
        guard !urls.isEmpty else { return false }
        for url in urls {
            do {
                try await StorageManager.shared.storeFile(at: url)
            } catch {
                #if DEBUG
                print("Notch Buddy: error storing dropped file \(url): \(error)")
                #endif
            }
        }
        return true
    }

    /// Used by the AppKit overlay window drag handler (Finder drops).
    func handleAirDrop(urls: [URL]) async -> Bool {
        guard !urls.isEmpty else { return false }
        await MainActor.run {
            let airDropServiceName = NSSharingService.Name("com.apple.share.AirDrop.send")
            if let service = NSSharingService(named: airDropServiceName) {
                service.perform(withItems: urls)
            }
        }
        return true
    }
}
