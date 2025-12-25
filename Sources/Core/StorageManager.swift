import Foundation

@MainActor
final class StorageManager: ObservableObject {
    static let shared = StorageManager()
    
    private let fileManager = FileManager.default
    private var storageRoot: URL
    
    @Published var storedItems: [StoredItem] = []
    
    private init() {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0]

        self.storageRoot = appSupport.appendingPathComponent("NotchBuddy/Storage")

        try? fileManager.createDirectory(at: storageRoot, withIntermediateDirectories: true)

        refreshItems()
    }
    
    func storeFile(at sourceURL: URL) async throws {
        let fileName = sourceURL.lastPathComponent
        let destinationURL = storageRoot.appendingPathComponent(fileName)
        
        // Copy file
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        
        #if DEBUG
        print("Notch Buddy: stored file at \(destinationURL.path)")
        #endif
        refreshItems()
    }
    
    func refreshItems() {
        // List files in directory
        do {
            let urls = try fileManager.contentsOfDirectory(at: storageRoot, includingPropertiesForKeys: nil)
            self.storedItems = urls.map { StoredItem(url: $0) }
        } catch {
            #if DEBUG
            print("Notch Buddy: error listing items: \(error)")
            #endif
        }
    }

    func deleteItem(_ item: StoredItem) {
        do {
            try fileManager.removeItem(at: item.url)
            refreshItems()
        } catch {
            // If the file is already gone, still refresh so the UI stops showing stale items.
            if isNoSuchFile(error) {
                refreshItems()
                return
            }
            #if DEBUG
            print("Notch Buddy: error deleting item \(item.url): \(error)")
            #endif
        }
    }

    func moveItemToTrash(_ item: StoredItem) {
        // `trashItem` moves the file to the user's Trash instead of permanently deleting it.
        guard fileManager.fileExists(atPath: item.url.path) else {
            refreshItems()
            return
        }

        do {
            var resultingURL: NSURL?
            try fileManager.trashItem(at: item.url, resultingItemURL: &resultingURL)
            refreshItems()
        } catch {
            if isNoSuchFile(error) {
                refreshItems()
                return
            }
            #if DEBUG
            print("Notch Buddy: error moving item to trash \(item.url): \(error)")
            #endif
        }
    }

    private func isNoSuchFile(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileNoSuchFileError {
            return true
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.domain == NSPOSIXErrorDomain,
           underlying.code == 2 {
            return true
        }
        return false
    }
}

struct StoredItem: Identifiable {
    let url: URL

    var id: String { url.path }
    
    var name: String {
        url.lastPathComponent
    }
}
