#include <moonbit.h>
#include <stdio.h>

extern moonbit_string_t make_greeting(void);
extern void *make_point(int x, int y);
extern int point_x(void *p);
extern int point_y(void *p);

static int32_t rc_of(void *obj) {
    struct moonbit_object *header = Moonbit_object_header(obj);
    return Moonbit_rc_count(header);
}

// Churn a large number of unrelated short-lived allocations to disturb the
// allocator/heap in between uses of the object under test.
static void churn(int n) {
    long sum = 0;
    for (int i = 0; i < n; i++) {
        void *garbage = make_point(i, i);
        sum += point_x(garbage);
    }
    if (sum == -1) {
        // never true; prevents the optimizer from eliding the loop
        printf("unreachable %ld\n", sum);
    }
}

int main(void) {
    printf("=== String literal lifetime ===\n");
    moonbit_string_t g = make_greeting();
    printf("make_greeting() rc = %d (raw rc word behavior: -1 means static/immortal)\n", rc_of(g));

    printf("\n=== Point lifetime: passive observation ===\n");
    void *p = make_point(3, 4);
    printf("after make_point:      rc = %d\n", rc_of(p));

    int x1 = point_x(p);
    printf("after 1st point_x(p):  rc = %d, x = %d\n", rc_of(p), x1);

    int y1 = point_y(p);
    printf("after 1st point_y(p):  rc = %d, y = %d\n", rc_of(p), y1);

    printf("\n=== churn: 500000 unrelated allocations in between ===\n");
    churn(500000);

    int x2 = point_x(p);
    int y2 = point_y(p);
    printf("after churn, re-read:  rc = %d, x = %d, y = %d\n", rc_of(p), x2, y2);
    if (x2 != 3 || y2 != 4) {
        fprintf(stderr, "FAIL: value corrupted after churn (expected 3,4, got %d,%d)\n", x2, y2);
        return 1;
    }

    printf("\n=== explicit incref/decref control ===\n");
    printf("before incref:         rc = %d\n", rc_of(p));
    moonbit_incref(p);
    printf("after incref:          rc = %d\n", rc_of(p));
    moonbit_decref(p);
    printf("after matching decref: rc = %d\n", rc_of(p));

    int x3 = point_x(p);
    int y3 = point_y(p);
    printf("after incref/decref, still usable: x = %d, y = %d\n", x3, y3);
    if (x3 != 3 || y3 != 4) {
        fprintf(stderr, "FAIL: value corrupted after incref/decref (expected 3,4, got %d,%d)\n", x3, y3);
        return 1;
    }

    printf("\nOK\n");
    return 0;
}
