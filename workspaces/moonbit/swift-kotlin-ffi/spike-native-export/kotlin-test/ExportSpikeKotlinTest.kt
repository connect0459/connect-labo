external fun add(value: Int): Int

fun main() {
    System.loadLibrary("exportspike_jni_kotlin")
    val result = add(41)
    println("add(41) = $result")
    check(result == 42) { "unexpected result: $result" }
}
