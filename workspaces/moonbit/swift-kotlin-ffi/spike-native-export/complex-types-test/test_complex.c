#include <moonbit.h>
#include <stdio.h>

extern moonbit_string_t make_greeting(void);
extern int string_length(moonbit_string_t s);
extern void *make_point(int x, int y);
extern int point_x(void *p);
extern int point_y(void *p);

static void print_moonbit_string(moonbit_string_t s) {
    int32_t len = Moonbit_array_length(s);
    printf("length=%d, chars=\"", len);
    for (int32_t i = 0; i < len; i++) {
        putchar((char)s[i]);
    }
    printf("\"\n");
}

int main(void) {
    // --- String: MoonBit -> C ---
    moonbit_string_t greeting = make_greeting();
    print_moonbit_string(greeting);

    // --- String: C -> MoonBit ---
    // Build "Kotlin" as a MoonBit string by writing UTF-16 code units directly
    // (ASCII range: 1 UTF-16 code unit per character).
    const char *name = "Kotlin";
    int32_t name_len = 0;
    while (name[name_len] != '\0') name_len++;

    moonbit_string_t mb_name = moonbit_make_string_raw(name_len);
    for (int32_t i = 0; i < name_len; i++) {
        mb_name[i] = (uint16_t)name[i];
    }

    int len_result = string_length(mb_name);
    printf("string_length(\"%s\") = %d\n", name, len_result);
    if (len_result != name_len) {
        fprintf(stderr, "FAIL: expected %d, got %d\n", name_len, len_result);
        return 1;
    }

    // --- Struct: opaque handle pattern ---
    void *p = make_point(3, 4);
    int x = point_x(p);
    int y = point_y(p);
    printf("point = (%d, %d)\n", x, y);
    if (x != 3 || y != 4) {
        fprintf(stderr, "FAIL: expected (3, 4), got (%d, %d)\n", x, y);
        return 1;
    }

    printf("OK\n");
    return 0;
}
