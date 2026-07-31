#ifndef CMOONBITEXPORTRELEASE_SHIM_H
#define CMOONBITEXPORTRELEASE_SHIM_H

// Declarations for the MoonBit-exported functions this spike calls, plus
// the runtime's reference-counting entry point (see moonbit.h in the
// MoonBit toolchain) needed to release ownership of returned objects.
void *make_point(int x, int y);
int point_x(void *p);
int point_y(void *p);
void moonbit_decref(void *obj);

#endif
