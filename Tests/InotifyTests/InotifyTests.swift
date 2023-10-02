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
        let eventsTask = Task<Array<InotifyEvent>, any Error>.detached {
            var collectedEvents = Array<InotifyEvent>()
            for await event in try await notifier.events(for: FilePath(tempDir.path)) {
                collectedEvents.append(event)
                if collectedEvents.count >= expectedEventCount { break }
            }
            return collectedEvents
        }
        let testFile = tempDir.appendingPathComponent("some_file.txt")
        try "some test".write(to: testFile, atomically: true, encoding: .utf8)
        try await Task.sleep(nanoseconds: 100)
        let anotherTestFile = tempDir.appendingPathComponent("some_other_file.txt")
        try FileManager.default.moveItem(at: testFile, to: anotherTestFile)
        try await Task.sleep(nanoseconds: 100)
        try FileManager.default.removeItem(at: anotherTestFile)
        let cancellation = Task.detached {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            eventsTask.cancel()
        }
        let events = try await eventsTask.value
        cancellation.cancel()
        XCTAssertFalse(eventsTask.isCancelled)
        XCTAssertEqual(events.count, expectedEventCount)
    }
}
