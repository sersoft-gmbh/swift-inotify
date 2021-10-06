#if os(Linux)
import Glibc
#else
import Darwin.C
#endif
import Dispatch
import SystemPackage
import FileStreamer
#if swift(>=5.4)
@_implementationOnly import Cinotify
#else
import Cinotify
#endif

@available(*, deprecated, renamed: "Inotifier")
public typealias Inotify = Inotifier

/// The notifier object.
public final class Inotifier { // FIXME: Make struct again once release builds don't crash with SIGSEGV!
    /// The callback that is called for read events.
    public typealias Callback = (FilePath, Array<InotifyEvent>) -> ()

    /// A watch identifier.
    @frozen
    public struct Watch: Hashable {
        /// The callback data.
        struct Callback {
            /// The observed file path.
            let filePath: FilePath
            /// The callback queue.
            let queue: DispatchQueue
            /// The callback closure.
            let callback: Inotifier.Callback

            func callAsFunction(with events: Array<InotifyEvent>) {
                queue.async { callback(filePath, events) }
            }
        }
        /// The internal descriptor.
        let descriptor: CInt
    }

    /// The collection of watches.
    final class Watches {
        private let lock = DispatchQueue(label: "de.sersoft.inotify.watches.lock")
        private var watches = Dictionary<CInt, Array<Watch.Callback>>()

        func withWatches<T>(do work: (inout Dictionary<CInt, Array<Watch.Callback>>) throws -> T) rethrows -> T {
            dispatchPrecondition(condition: .notOnQueue(lock))
            return try lock.sync { try work(&watches) }
        }
    }

    /// The stream of events.
    let stream: FileStream<cinotify_event>
    /// The watches collection.
    let watches: Watches

    /// The underlying file descriptor of the stream.
    var fileDescriptor: FileDescriptor { stream.fileDescriptor }

    /// Creates a new instance.
    public init() throws {
        guard case let fd = inotify_init1(0), fd != -1 else { throw Errno(rawValue: errno) }
        let _watches = Watches()
        stream = .init(fileDescriptor: .init(rawValue: fd)) {
            // FIXME: Deal with connected events using `event.cookie`.
            let grouped = Dictionary(grouping: $0, by: \.wd).mapValues {
                $0.map(InotifyEvent.init)
            }
            _watches.withWatches { watches in
                grouped.forEach { (wd, events) in
                    watches[wd]?.forEach { $0(with: events) }
                }
            }
        }
        watches = _watches
    }

    /// Closes this inotify instance. All further calls to this instance will fail.
    public func close() throws {
        try watches.withWatches {
            try fileDescriptor.close()
            $0.removeAll()
        }
    }

    /// Adds a watch for a given file path, calling back on the given queue using the given closure.
    /// - Parameters:
    ///   - filePath: The file path to watch.
    ///   - queue: The queue on which to call the `callback` closure.
    ///   - callback: The closure to call with events.
    /// - Returns: The added watch. This is needed to later remove it again.
    public func addWatch(for filePath: FilePath, on queue: DispatchQueue, calling callback: @escaping Callback) throws -> Watch {
        try watches.withWatches {
            let wd = filePath.withCString {
                inotify_add_watch(fileDescriptor.rawValue, $0, cin_all_events)
            }
            guard wd != -1 else { throw Errno(rawValue: errno) }
            $0[wd, default: []].append(Watch.Callback(filePath: filePath, queue: queue, callback: callback))
            stream.beginStreaming()
            return Watch(descriptor: wd)
        }
    }

    private func _removeWatch(forDescriptor wd: CInt) throws {
        let status = inotify_rm_watch(fileDescriptor.rawValue, wd)
        guard status != -1 else { throw Errno(rawValue: errno) }
    }

    /// Removes a given watch.
    /// - Parameter watch: The watch to remove.
    public func removeWatch(_ watch: Watch) throws {
        try watches.withWatches {
            try _removeWatch(forDescriptor: watch.descriptor)
            $0.removeValue(forKey: watch.descriptor)
            if $0.isEmpty {
                stream.endStreaming()
            }
        }
    }
}
