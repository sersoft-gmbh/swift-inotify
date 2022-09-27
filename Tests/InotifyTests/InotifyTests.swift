import Foundation
import XCTest
import SystemPackage
@testable import Inotify

final class InotifyTests: XCTestCase {
    func testEventNotifying() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        addTeardownBlock {
            try FileManager.default.removeItem(at: tempDir)
        }
        let notifier = try Inotifier()
        let expectedEventCount = 3
        let eventsTask = Task<Array<InotifyEvent>, Error>.detached {
            var collectedEvents = Array<InotifyEvent>()
            for await event in try await notifier.events(for: FilePath(tempDir.path)) {
                collectedEvents.append(event)
                if collectedEvents.count >= expectedEventCount { break }
            }
            return collectedEvents
        }
        let testFile = tempDir.appendingPathComponent("some_file.txt")
        try "some test".write(to: testFile, atomically: true, encoding: .utf8)
        let anotherTestFile = tempDir.appendingPathComponent("some_other_file.txt")
        try FileManager.default.moveItem(at: testFile, to: anotherTestFile)
        try FileManager.default.removeItem(at: anotherTestFile)
        let events = try await eventsTask.value
        XCTAssertEqual(events.count, expectedEventCount)
    }
}
