public class ExportSpikeTest {
    static {
        System.loadLibrary("exportspike_jni");
    }

    public static native int add(int value);

    public static void main(String[] args) {
        int result = add(41);
        System.out.println("add(41) = " + result);
        if (result != 42) {
            throw new RuntimeException("unexpected result: " + result);
        }
    }
}
