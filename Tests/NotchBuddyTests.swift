#if canImport(XCTest)
import XCTest
@testable import NotchBuddy

final class NotchBuddyTests: XCTestCase {
    func testStoredItemNameUsesLastPathComponent() {
        let item = StoredItem(url: URL(fileURLWithPath: "/tmp/example.txt"))
        XCTAssertEqual(item.name, "example.txt")
    }
}
#endif
