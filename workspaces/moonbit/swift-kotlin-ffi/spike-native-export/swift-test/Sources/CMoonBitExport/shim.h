#ifndef CMOONBITEXPORT_SHIM_H
#define CMOONBITEXPORT_SHIM_H

// Declares the symbol exported by MoonBit's #export_name("add") on the
// native target. The implementation lives in libexportspike_swift.dylib,
// produced by manually linking moonc's native codegen output (see
// research.md's native export spike).
int add(int value);

#endif
