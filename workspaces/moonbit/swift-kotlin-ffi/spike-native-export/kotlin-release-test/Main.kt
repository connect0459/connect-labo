private external fun nativeRssBytes(): Long

private fun rssMb(): Double = nativeRssBytes() / 1024.0 / 1024.0

fun main(args: Array<String>) {
    // --- Basic correctness with try-with-resources-style `use` ---
    PointHandle.create(3, 4).use { p ->
        println("point = (${p.x}, ${p.y})")
        check(p.x == 3 && p.y == 4)
    }
    println("basic usage OK")

    // --- Double-close is safe (idempotent) ---
    val p2 = PointHandle.create(1, 2)
    p2.close()
    p2.close()
    println("double-close OK")

    // --- Leak comparison, mirroring the C-side leak_check.c experiment ---
    val withClose = args.isNotEmpty() && args[0] == "1"
    println("mode: ${if (withClose) "WITH close()" else "WITHOUT close() (leak baseline)"}")

    val n = 2_000_000
    val checkpoints = 5
    for (i in 0 until n) {
        val handle = PointHandle.create(i, i + 1)
        check(handle.x == i && handle.y == i + 1)
        if (withClose) {
            handle.close()
        }
        if ((i + 1) % (n / checkpoints) == 0) {
            println("  after ${i + 1} iterations: rss = ${"%.1f".format(rssMb())} MB")
        }
    }
    println("done")
}
