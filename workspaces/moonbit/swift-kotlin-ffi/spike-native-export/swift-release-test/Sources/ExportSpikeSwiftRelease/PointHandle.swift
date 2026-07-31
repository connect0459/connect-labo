import CMoonBitExportRelease

/// Owns one MoonBit-managed `Point` reference obtained from `make_point`.
/// Unlike the JNI/Kotlin wrapper, this relies on Swift's deterministic ARC
/// `deinit` to release the reference — no explicit `close()` is required
/// for correctness, since `deinit` always runs exactly once when the last
/// strong reference to a `PointHandle` goes away.
final class PointHandle {
    private var ptr: UnsafeMutableRawPointer?

    private init(ptr: UnsafeMutableRawPointer) {
        self.ptr = ptr
    }

    static func create(x: Int32, y: Int32) -> PointHandle {
        PointHandle(ptr: make_point(x, y))
    }

    var x: Int32 {
        guard let ptr else { fatalError("PointHandle already released") }
        return point_x(ptr)
    }

    var y: Int32 {
        guard let ptr else { fatalError("PointHandle already released") }
        return point_y(ptr)
    }

    deinit {
        if let ptr {
            moonbit_decref(ptr)
        }
    }
}
