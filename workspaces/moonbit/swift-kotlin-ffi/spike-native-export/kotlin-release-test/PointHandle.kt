private external fun nativeMakePoint(x: Int, y: Int): Long
private external fun nativePointX(ptr: Long): Int
private external fun nativePointY(ptr: Long): Int
private external fun nativeReleasePoint(ptr: Long)

/**
 * Owns one MoonBit-managed `Point` reference obtained from `make_point`.
 * The reference must be released via [close] exactly once; forgetting to
 * do so leaks the underlying MoonBit object (see research.md's lifetime
 * findings — export functions transfer ownership to the caller and MoonBit
 * never frees it on its own).
 */
class PointHandle private constructor(private var ptr: Long) : AutoCloseable {
    private var closed = false

    val x: Int
        get() {
            check(!closed) { "PointHandle already closed" }
            return nativePointX(ptr)
        }

    val y: Int
        get() {
            check(!closed) { "PointHandle already closed" }
            return nativePointY(ptr)
        }

    override fun close() {
        if (!closed) {
            nativeReleasePoint(ptr)
            closed = true
        }
    }

    companion object {
        init {
            System.loadLibrary("exportspike_jni_release")
        }

        fun create(x: Int, y: Int): PointHandle = PointHandle(nativeMakePoint(x, y))
    }
}
