#if os(Linux)
import Glibc
#else
import Darwin.C
#endif
import Dispatch
import Foundation
import SystemPackage
import FileStreamer
@_implementationOnly import CInotify

/// The notifier object.
public final actor Inotifier {
    /// An asynchronous sequence of events for a certain file path.
    @frozen
    public struct PathEvents: AsyncSequence, Sendable {
        public typealias Element = AsyncIterator.Element

        @frozen
        public struct AsyncIterator: AsyncIteratorProtocol {
            public typealias Element = InotifyEvent

            @usableFromInline
            var underlyingIterator: AsyncStream<Element>.AsyncIterator

            @usableFromInline
            init(underlyingIterator: AsyncStream<Element>.AsyncIterator) {
                self.underlyingIterator = underlyingIterator
            }

            @inlinable
            public mutating func next() async -> Element? {
                await underlyingIterator.next()
            }
        }

        @usableFromInline
        let stream: AsyncStream<Element>

        @usableFromInline
        init(stream: AsyncStream<Element>)  {
            self.stream = stream
        }

        @inlinable
        public func makeAsyncIterator() -> AsyncIterator {
            .init(underlyingIterator: stream.makeAsyncIterator())
        }
    }

    private let fileDescriptor: FileDescriptor
    private var streamTask: Task<Void, Never>?
    private var watches = Dictionary<CInt, Dictionary<UUID, AsyncStream<InotifyEvent>.Continuation>>()

    /// Creates a new instance.
    public init() throws {
        guard case let fd = inotify_init1(0), fd != -1 else { throw Errno(rawValue: errno) }
        fileDescriptor = .init(rawValue: fd)
    }

    deinit {
        streamTask?.cancel()
        streamTask = nil
        try? fileDescriptor.close()
    }

    /// Closes this inotify instance. All further calls to this instance will fail.
    public func close() throws {
        stopStreaming()
        try fileDescriptor.close()
    }

    /// Returns the asynchronous events sequence for the given file path.
    /// - Parameters:
    ///   - filePath: The file path to watch.
    /// - Returns: The asynchronous sequence of events for the given file path.
    public func events(for filePath: FilePath) throws -> PathEvents {
        let wd = filePath.withCString {
            inotify_add_watch(fileDescriptor.rawValue, $0, cin_all_events)
        }
        guard wd != -1 else { throw Errno(rawValue: errno) }
        if streamTask == nil {
            startStreaming()
        }
        let stream = AsyncStream<InotifyEvent> { continuation in
            let sequenceID = UUID()
            watches[wd, default: [:]][sequenceID] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    try await self?.removeWatch(forDescriptor: wd, sequenceID: sequenceID)
                }
            }
        }
        return PathEvents(stream: stream)
    }

    private func startStreaming() {
        assert(streamTask == nil)
        streamTask = Task.detached { [unowned self] in
            for await event in FileStream<cinotify_event>.Sequence(fileDescriptor: fileDescriptor) {
                await self.handle(event)
            }
        }
    }

    private func handle(_ cEvent: cinotify_event) {
        guard var watchesToNotify = watches[cEvent.wd] else { return }
        defer {
            if watchesToNotify.isEmpty {
                watches.removeValue(forKey: cEvent.wd)
            } else {
                watches[cEvent.wd] = watchesToNotify
            }
        }
        // FIXME: Deal with connected events using `event.cookie`.
        let event = InotifyEvent(cEvent: cEvent)
        for (watchID, continuation) in watchesToNotify {
            if case .terminated = continuation.yield(event) {
                watchesToNotify.removeValue(forKey: watchID)
            }
        }
    }

    private func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
    }

    private func removeWatch(forDescriptor wd: CInt, sequenceID: UUID) throws {
        let status = inotify_rm_watch(fileDescriptor.rawValue, wd)
        guard status != -1 else { throw Errno(rawValue: errno) }
        guard var watchSequences = watches[wd] else { return }
        watchSequences.removeValue(forKey: sequenceID)
        guard watchSequences.isEmpty else { return }
        watches.removeValue(forKey: wd)
        guard watches.isEmpty else { return }
        stopStreaming()
    }
}
