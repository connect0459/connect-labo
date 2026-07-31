#include <moonbit.h>
#include <stdio.h>

extern moonbit_string_t make_greeting(void);
extern int string_length(moonbit_string_t s);
extern void *make_point(int x, int y);
extern int point_x(void *p);
extern int point_y(void *p);

int main(void) {
    const int N = 2000000;
    long sum = 0;
    for (int i = 0; i < N; i++) {
        moonbit_string_t g = make_greeting();
        sum += Moonbit_array_length(g);

        void *p = make_point(i, i + 1);
        sum += point_x(p) + point_y(p);
    }
    printf("iterations=%d sum=%ld\n", N, sum);
    return 0;
}
