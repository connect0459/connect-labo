#include <moonbit.h>
#include <stdio.h>

extern moonbit_string_t make_greeting(void);

static int32_t rc_of(void *obj) {
    struct moonbit_object *header = Moonbit_object_header(obj);
    return Moonbit_rc_count(header);
}

int main(void) {
    moonbit_string_t g = make_greeting();
    printf("before: rc = %d\n", rc_of(g));
    moonbit_decref(g);
    printf("after 1x decref: rc = %d\n", rc_of(g));
    moonbit_decref(g);
    printf("after 2x decref: rc = %d\n", rc_of(g));
    moonbit_incref(g);
    printf("after 1x incref: rc = %d\n", rc_of(g));

    // Use it again to confirm it's still valid/readable after repeated
    // decref/incref calls on an immortal object.
    int32_t len = Moonbit_array_length(g);
    printf("still readable, length = %d\n", len);
    printf("OK\n");
    return 0;
}
