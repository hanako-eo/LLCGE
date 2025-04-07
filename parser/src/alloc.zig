const std = @import("std");

const parser_zig = @import("./lib.zig");
const LoopPattern = parser_zig.LoopPattern;
const Parser = parser_zig.Parser;
const ParseResult = parser_zig.ParseResult;

const error_zig = @import("./error.zig");
const ParseErrorKind = error_zig.ParseErrorKind;

const meta = @import("./utils/meta.zig");

const Result = @import("./utils/types.zig").Result;

const Pair = @import("utils").Pair;

pub const ListRule = enum {
    explicite_separation,
    optional_separation,
};

pub fn separated_list(
    comptime T: type,
    comptime raw_parser: anytype,
    comptime sep: anytype,
    comptime pattern: LoopPattern,
    comptime rule: ListRule,
    // AllocatableType need to return a type with the method init, append and deinit.
    comptime AllocatableType: type,
) Parser(AllocatableType) {
    const parser = comptime meta.callable(fn ([]const u8, std.mem.Allocator) ParseResult(T, []const u8), raw_parser) orelse
        @compileError("the input parser must be callable.");
    if (!meta.is_parser_like(sep))
        @compileError("the separator must be a parser (or look like a parser).");

    const min = pattern.min();
    const max = pattern.max();
    return Parser(AllocatableType).init(struct {
        pub fn call(first_input: []const u8, allocator: std.mem.Allocator) ParseResult(AllocatableType, []const u8) {
            var parsed_list = AllocatableType.init(allocator);
            var input = first_input;
            var iteration: usize = 0;

            while (true) {
                if (max > 0 and iteration == max)
                    break;

                switch (parser(input, allocator)) {
                    .err => |err| if (iteration != 0 and rule == .explicite_separation) {
                        parsed_list.deinit();
                        return ParseResult(AllocatableType, []const u8).Err(err);
                    } else {
                        break;
                    },
                    .ok => |result| {
                        parsed_list.append(result.first) catch {
                            parsed_list.deinit();
                            return ParseResult(AllocatableType, []const u8).Err(.{
                                .input = input,
                                .kind = .allocator_out_of_memory,
                            });
                        };
                        input = result.second;
                    },
                }
                iteration += 1;

                switch (sep.run(input, allocator)) {
                    .err => break,
                    .ok => |result| input = result.second,
                }
            }

            if (min > iteration)
                return ParseResult(AllocatableType, []const u8).Err(.{
                    .input = input,
                    .kind = .{
                        .unsatify_min_patern = .{
                            .expected = min,
                            .actual = iteration,
                        },
                    },
                });

            return ParseResult(AllocatableType, []const u8).Ok(Pair(AllocatableType, []const u8).init(parsed_list, input));
        }
    });
}
