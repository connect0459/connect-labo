import Darwin
import Foundation

func rssBytes() -> UInt64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
    let result = withUnsafeMutablePointer(to: &info) { pointer -> kern_return_t in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    return result == KERN_SUCCESS ? info.resident_size : 0
}

func rssMb() -> Double {
    Double(rssBytes()) / 1024.0 / 1024.0
}

// --- Basic correctness ---
do {
    let p = PointHandle.create(x: 3, y: 4)
    print("point = (\(p.x), \(p.y))")
    precondition(p.x == 3 && p.y == 4)
}
print("basic usage (deinit fires at scope exit) OK")

// --- Leak comparison ---
// "scoped": each handle's only strong reference is the loop-local `let`,
// so ARC calls deinit (and thus moonbit_decref) at the end of each iteration.
// "retained": handles are deliberately kept alive in an array so deinit
// never runs during the loop, mirroring what "forgetting to release"
// looks like in a GC'd language — here it is simply "still referenced".
let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "0"
let retain = mode == "1"
print("mode: \(retain ? "RETAINED (deinit withheld)" : "SCOPED (deinit fires each iteration)")")

let n = 2_000_000
let checkpoints = 5
var retainedHandles: [PointHandle] = []
for i in 0..<n {
    let handle = PointHandle.create(x: Int32(i), y: Int32(i + 1))
    precondition(handle.x == Int32(i) && handle.y == Int32(i + 1))
    if retain {
        retainedHandles.append(handle)
    }
    if (i + 1) % (n / checkpoints) == 0 {
        print("  after \(i + 1) iterations: rss = \(String(format: "%.1f", rssMb())) MB")
    }
}
print("done")
