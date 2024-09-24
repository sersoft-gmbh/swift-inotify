#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
import ucrt
#else
#error("Unknown platform")
#endif
public import SystemPackage
internal import CInotify

/// An event sent by inotify.
public struct InotifyEvent: Equatable, @unchecked Sendable { // unchecked because of FilePath
    /// The file path of the event. If nil, the event is not for a file inside of the watch.
    public let path: FilePath?
    /// The flags of the event.
    public let flags: Flags

    init(cEvent event: cinotify_event) {
        path = cin_event_name(event).map { FilePath(platformString: $0) }
        flags = .init(rawValue: event.mask)
    }
}

extension InotifyEvent {
    /// A set of flags that can be set on an event.
    @frozen
    public struct Flags: OptionSet, Hashable, Sendable {
        public typealias RawValue = UInt32

        public let rawValue: RawValue

        public init(rawValue: RawValue) {
            self.rawValue = rawValue
        }
    }
}

extension InotifyEvent.Flags {
    /// File was accessed.
    public static let accessed = InotifyEvent.Flags(rawValue: numericCast(IN_ACCESS))
    /// File was modified.
    public static let modified = InotifyEvent.Flags(rawValue: numericCast(IN_MODIFY))
    /// Metadata changed.
    public static let attributesChanged = InotifyEvent.Flags(rawValue: numericCast(IN_ATTRIB))
    /// A writeable file was closed.
    public static let writableFileClosed = InotifyEvent.Flags(rawValue: numericCast(IN_CLOSE_WRITE))
    /// A non-writable file was closed.
    public static let nonWritableFileClosed = InotifyEvent.Flags(rawValue: numericCast(IN_CLOSE_NOWRITE))
    /// File was opened.
    public static let opened = InotifyEvent.Flags(rawValue: numericCast(IN_OPEN))
    /// File was moved from X.
    public static let movedFrom = InotifyEvent.Flags(rawValue: numericCast(IN_MOVED_FROM))
    /// File was moved to Y.
    public static let movedTo = InotifyEvent.Flags(rawValue: numericCast(IN_MOVED_TO))
    /// File was created inside the watched path.
    public static let fileCreated = InotifyEvent.Flags(rawValue: numericCast(IN_CREATE))
    /// File was deleted inside the watched path.
    public static let fileDeleted = InotifyEvent.Flags(rawValue: numericCast(IN_DELETE))
    /// The watched path was deleted.
    public static let selfDeleted = InotifyEvent.Flags(rawValue: numericCast(IN_DELETE_SELF))
    /// The watched path was moved.
    public static let selfMoved = InotifyEvent.Flags(rawValue: numericCast(IN_MOVE_SELF))

    /// Event occurred against a directory.
    public static let isDirectory = InotifyEvent.Flags(rawValue: numericCast(IN_ISDIR))
}

// FIXME: We should somehow deal with those as well.
/* Events sent by the kernel.  */
//#define IN_UNMOUNT   0x00002000 /* Backing fs was unmounted.  */
//#define IN_Q_OVERFLOW    0x00004000 /* Event queued overflowed.  */
//#define IN_IGNORED   0x00008000 /* File was ignored.  */

// TODO: These need to go into a separate struct for flags that can be added to a watch.
/* Special flags.  */
//#define IN_ONLYDIR   0x01000000 /* Only watch the path if it is a directory.  */
//#define IN_DONT_FOLLOW   0x02000000 /* Do not follow a sym link.  */
//#define IN_EXCL_UNLINK   0x04000000 /* Exclude events on unlinked objects.  */
//#define IN_MASK_CREATE   0x10000000 /* Only create watches.  */
//#define IN_MASK_ADD  0x20000000 /* Add to the mask of an already existing watch.  */
//#define IN_ONESHOT   0x80000000 /* Only send event once.  */
