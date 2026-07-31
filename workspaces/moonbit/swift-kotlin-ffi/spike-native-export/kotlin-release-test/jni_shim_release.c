#include <jni.h>
#include <moonbit.h>
#include <mach/mach.h>
#include <stdint.h>

extern void *make_point(int x, int y);
extern int point_x(void *p);
extern int point_y(void *p);

JNIEXPORT jlong JNICALL Java_PointHandleKt_nativeMakePoint(JNIEnv *env, jclass clazz, jint x, jint y) {
    (void)env;
    (void)clazz;
    return (jlong)(intptr_t)make_point(x, y);
}

JNIEXPORT jint JNICALL Java_PointHandleKt_nativePointX(JNIEnv *env, jclass clazz, jlong ptr) {
    (void)env;
    (void)clazz;
    return point_x((void *)(intptr_t)ptr);
}

JNIEXPORT jint JNICALL Java_PointHandleKt_nativePointY(JNIEnv *env, jclass clazz, jlong ptr) {
    (void)env;
    (void)clazz;
    return point_y((void *)(intptr_t)ptr);
}

JNIEXPORT void JNICALL Java_PointHandleKt_nativeReleasePoint(JNIEnv *env, jclass clazz, jlong ptr) {
    (void)env;
    (void)clazz;
    moonbit_decref((void *)(intptr_t)ptr);
}

JNIEXPORT jlong JNICALL Java_MainKt_nativeRssBytes(JNIEnv *env, jclass clazz) {
    (void)env;
    (void)clazz;
    struct mach_task_basic_info info;
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &count) != KERN_SUCCESS) {
        return 0;
    }
    return (jlong)info.resident_size;
}
