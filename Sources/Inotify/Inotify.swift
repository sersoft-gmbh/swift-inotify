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

public struct Inotify {
    public typealias Callback = (FilePath, Array<InotifyEvent>) -> ()

    @frozen
    public struct Watch: Hashable {
        struct Callback {
            let filePath: FilePath
            let queue: DispatchQueue
            let callback: Inotify.Callback

            func callAsFunction(with events: Array<InotifyEvent>) {
                queue.async { callback(filePath, events) }
            }
        }

        let descriptor: CInt
    }

    final class Watches {
        private let lock = DispatchQueue(label: "de.sersoft.inotify.watches.lock")
        private var watches = Dictionary<CInt, Array<Watch.Callback>>()

        func withWatches<T>(do work: (inout Dictionary<CInt, Array<Watch.Callback>>) throws -> T) rethrows -> T {
            dispatchPrecondition(condition: .notOnQueue(lock))
            return try lock.sync { try work(&watches) }
        }
    }

    let streamer: FileStream<cinotify_event>
    let watches = Watches()

    var fileDescriptor: FileDescriptor { streamer.fileDescriptor }

    public init(filePath: FilePath) throws {
        let fd = inotify_init1(0)
        guard fd != -1 else { throw Errno(rawValue: errno) }
        streamer = .init(fileDescriptor: .init(rawValue: fd)) { [watches] in
            let grouped = Dictionary(grouping: $0, by: \.wd).mapValues {
                $0.lazy.map(InotifyEvent.init).sorted { $0.date < $1.date }
            }            
            watches.withWatches { watches in
                grouped.forEach { (key, value) in
                    watches[key]?.forEach { $0(with: value) }
                }
            }
        }
        streamer.beginStreaming()
    }

    public func addWatch(for filePath: FilePath, on queue: DispatchQueue, calling callback: @escaping Callback) throws -> Watch {
        try watches.withWatches {
            let wd = filePath.withCString {
                inotify_add_watch(fileDescriptor.rawValue, $0, cin_all_events)
            }
            guard wd != -1 else { throw Errno(rawValue: errno) }
            $0[wd, default: []].append(Watch.Callback(filePath: filePath, queue: queue, callback: callback))
            return Watch(descriptor: wd)
        }
    }

    public func removeWatch(_ watch: Watch) throws {
        try watches.withWatches {
            let status = inotify_rm_watch(fileDescriptor.rawValue, watch.descriptor)
            guard status != -1 else { throw Errno(rawValue: errno) }
            $0.removeValue(forKey: watch.descriptor)
        }
    }
}
