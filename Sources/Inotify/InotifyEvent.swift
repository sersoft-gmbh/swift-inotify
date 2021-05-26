import Foundation
import SystemPackage
#if swift(>=5.4)
@_implementationOnly import Cinotify
#else
import Cinotify
#endif

public struct InotifyEvent: Equatable {
    public let path: FilePath
    public let date: Date
    public let flags: Flags

    init(cEvent event: cinotify_event) {
        path = FilePath(cString: cin_event_name(event))
        date = Date()
        flags = .init(rawValue: event.mask)
    }
}

extension InotifyEvent {
    @frozen
    public struct Flags: OptionSet {
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
    /// Writtable file was closed.
    public static let writableClose = InotifyEvent.Flags(rawValue: numericCast(IN_CLOSE_WRITE))     
    /// Unwrittable file closed.
    public static let unwritableClose = InotifyEvent.Flags(rawValue: numericCast(IN_CLOSE_NOWRITE)) 
    /// File was opened.
    public static let opened = InotifyEvent.Flags(rawValue: numericCast(IN_OPEN))                   
    /// File was moved from X.
    public static let movedFrom = InotifyEvent.Flags(rawValue: numericCast(IN_MOVED_FROM))       
    /// File was moved to Y.
    public static let movedTo = InotifyEvent.Flags(rawValue: numericCast(IN_MOVED_TO))           
    /// Subfile was created.
    public static let fileCreated = InotifyEvent.Flags(rawValue: numericCast(IN_CREATE))               
    /// Subfile was deleted.
    public static let fileDeleted = InotifyEvent.Flags(rawValue: numericCast(IN_DELETE))               
    /// Self was deleted.
    public static let selfDeleted = InotifyEvent.Flags(rawValue: numericCast(IN_DELETE_SELF))     
    /// Self was moved.
    public static let selfMoved = InotifyEvent.Flags(rawValue: numericCast(IN_MOVE_SELF))         

/* Events sent by the kernel.  */
//#define IN_UNMOUNT   0x00002000 /* Backing fs was unmounted.  */
//#define IN_Q_OVERFLOW    0x00004000 /* Event queued overflowed.  */
//#define IN_IGNORED   0x00008000 /* File was ignored.  */

/* Helper events.  */
//#define IN_CLOSE     (IN_CLOSE_WRITE | IN_CLOSE_NOWRITE)    /* Close.  */
//#define IN_MOVE      (IN_MOVED_FROM | IN_MOVED_TO)      /* Moves.  */

/* Special flags.  */
//#define IN_ONLYDIR   0x01000000 /* Only watch the path if it is a directory.  */
//#define IN_DONT_FOLLOW   0x02000000 /* Do not follow a sym link.  */
//#define IN_EXCL_UNLINK   0x04000000 /* Exclude events on unlinked objects.  */
//#define IN_MASK_CREATE   0x10000000 /* Only create watches.  */
//#define IN_MASK_ADD  0x20000000 /* Add to the mask of an already existing watch.  */
//#define IN_ISDIR     0x40000000 /* Event occurred against dir.  */
//#define IN_ONESHOT   0x80000000 /* Only send event once.  */
}
