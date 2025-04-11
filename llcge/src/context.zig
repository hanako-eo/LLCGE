const std = @import("std");
const Allocator = std.mem.Allocator;

const TargetMachine = @import("./target_machine.zig");

allocator: Allocator,
target_machine: TargetMachine,
// TODO: passes: void,
