#include <jni.h>

extern int add(int);

JNIEXPORT jint JNICALL Java_ExportSpikeTest_add(JNIEnv *env, jclass clazz, jint value) {
    (void)env;
    (void)clazz;
    return add(value);
}
