#include <moonbit.h>
#include <stdio.h>
#include <mach/mach.h>

extern void *make_point(int x, int y);
extern int point_x(void *p);
extern int point_y(void *p);

static size_t rss_bytes(void) {
    struct mach_task_basic_info info;
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &count) != KERN_SUCCESS) {
        return 0;
    }
    return info.resident_size;
}

int main(int argc, char **argv) {
    int with_decref = argc > 1 && argv[1][0] == '1';
    printf("mode: %s\n", with_decref ? "WITH explicit moonbit_decref" : "WITHOUT decref (baseline)");

    const int N = 2000000;
    const int CHECKPOINTS = 5;
    long sum = 0;
    for (int i = 0; i < N; i++) {
        void *p = make_point(i, i + 1);
        sum += point_x(p) + point_y(p);
        if (with_decref) {
            moonbit_decref(p);
        }
        if ((i + 1) % (N / CHECKPOINTS) == 0) {
            printf("  after %8d iterations: rss = %.1f MB\n", i + 1, rss_bytes() / 1024.0 / 1024.0);
        }
    }
    printf("sum=%ld\n", sum);
    return 0;
}
