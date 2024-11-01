const std = @import("std");
const helpers = @import("helpers");
const GeneralErrors = helpers.GeneralErrors;

pub const std_options: std.Options = .{
    .log_level = .info,
};

const DaySpecificErrors = error{Something};
const assert = std.debug.assert;

const PatternLineArray = std.BoundedArray(u8, 20);
const PatternArray = std.BoundedArray(PatternLineArray, 20);

const PatternReader = struct {
    const LineReader = helpers.FixedBufferLineReader(30);

    line_reader: LineReader,

    pub fn init(comptime test_input: bool) !PatternReader {
        return PatternReader{ .line_reader = if (test_input) try LineReader.fromTestInput(13) else try LineReader.fromAdventDay(13) };
    }

    pub fn deinit(self: *PatternReader) void {
        self.line_reader.deinit();
    }

    pub fn next(self: *PatternReader) ?PatternArray {
        var ret = PatternArray.init(0) catch unreachable;
        while (self.line_reader.next()) |line| {
            if (line.len == 0) break;
            const item = ret.addOne() catch unreachable;
            item.* = PatternLineArray.init(0) catch unreachable;
            item.*.appendSlice(line) catch unreachable;
        }
        return if (ret.len == 0) null else ret;
    }
};

fn printPattern(pattern: PatternArray) void {
    for (pattern.slice()) |ln| {
        std.log.info("{s}", .{ln.slice()});
    }
}

const part1 = struct {
    fn columnsEqual(pattern: PatternArray, col_idx1: usize, col_idx2: usize) bool {
        for (pattern.constSlice()) |ln| {
            const ln_slice = ln.constSlice();
            if (ln_slice[col_idx1] != ln_slice[col_idx2]) return false;
        }
        return true;
    }

    fn debugPrintColumns(pattern: PatternArray, col_idx1: usize, col_idx2: usize) void {
        for (pattern.constSlice()) |ln| {
            const ln_slice = ln.constSlice();
            std.log.debug("{c}{c}", .{ ln_slice[col_idx1], ln_slice[col_idx2] });
        }
    }

    fn solvePattern(pattern: PatternArray) usize {

        // Check for a horizontal line first
        const pat_slice = pattern.constSlice();
        for (0..pat_slice.len - 1) |row_idx| {
            if (std.mem.eql(u8, pat_slice[row_idx].constSlice(), pat_slice[row_idx + 1].constSlice())) {
                const found_row_mirror = v: {
                    if ((row_idx == 0) or ((row_idx + 1) == pat_slice.len - 1)) {
                        // If we're at endpoints, then this is a match!
                        break :v true;
                    } else {
                        // Otherwise have to check other indices
                        var start_idx = row_idx;
                        var end_idx = row_idx + 1;
                        while ((start_idx > 0 and end_idx < pat_slice.len - 1)) {
                            start_idx -= 1;
                            end_idx += 1;
                            if (!std.mem.eql(u8, pat_slice[start_idx].constSlice(), pat_slice[end_idx].constSlice())) {
                                break :v false;
                            }
                        }
                        break :v true;
                    }
                };
                if (found_row_mirror) return 100 * (row_idx + 1);
            }
        }

        // Then vertical
        for (0..pat_slice[0].len - 1) |col_idx| {
            if (columnsEqual(pattern, col_idx, col_idx + 1)) {
                const found_col_mirror = v: {
                    if ((col_idx == 0) or ((col_idx + 1) == pat_slice[0].len - 1)) {
                        // If we're at endpoints, then this is a match!
                        break :v true;
                    } else {
                        // Otherwise have to check other indices
                        var start_idx = col_idx;
                        var end_idx = col_idx + 1;
                        while ((start_idx > 0 and end_idx < pat_slice[0].len - 1)) {
                            start_idx -= 1;
                            end_idx += 1;
                            if (!columnsEqual(pattern, start_idx, end_idx)) {
                                break :v false;
                            }
                        }
                        break :v true;
                    }
                };
                if (found_col_mirror) return col_idx + 1;
            }
        }
        unreachable; // Must be a single reflection
    }

    test "solvePattern" {
        var pattern_reader = try PatternReader.init(true);
        defer pattern_reader.deinit();
        var pattern = pattern_reader.next().?;
        try std.testing.expectEqual(5, solvePattern(pattern));
        pattern = pattern_reader.next().?;
        try std.testing.expectEqual(400, solvePattern(pattern));
    }
};

const part2 = struct {
    fn rowsMismatchCount(pattern: PatternArray, row_idx1: usize, row_idx2: usize) usize {
        var mismatch_count: usize = 0;
        const row1 = pattern.constSlice()[row_idx1].constSlice();
        const row2 = pattern.constSlice()[row_idx2].constSlice();
        for (0..row1.len) |i| {
            if (row1[i] != row2[i]) {
                mismatch_count += 1;
            }
        }
        return mismatch_count;
    }

    fn colsMismatchCount(pattern: PatternArray, col_idx1: usize, col_idx2: usize) usize {
        var mismatch_count: usize = 0;
        for (pattern.constSlice()) |ln| {
            const ln_slice = ln.constSlice();
            if (ln_slice[col_idx1] != ln_slice[col_idx2]) {
                mismatch_count += 1;
            }
        }
        return mismatch_count;
    }

    fn solvePattern(pattern: PatternArray) usize {

        // Check for a horizontal line first
        const pat_slice = pattern.constSlice();
        for (0..pat_slice.len - 1) |row_idx| {
            const initial_match_scenario: enum { NoMatch, Match, MatchWithMismatch } = switch (rowsMismatchCount(pattern, row_idx, row_idx + 1)) {
                0 => .Match,
                1 => .MatchWithMismatch,
                else => .NoMatch,
            };

            if (initial_match_scenario != .NoMatch) {
                const found_row_mirror = v: {
                    var has_mismatch: bool = initial_match_scenario == .MatchWithMismatch;
                    if ((row_idx == 0) or ((row_idx + 1) == pat_slice.len - 1)) {
                        // If we're at endpoints, and have a single point of mismatch, then this is a mirror
                        break :v has_mismatch;
                    } else {
                        // Otherwise have to check other indices
                        var start_idx = row_idx;
                        var end_idx = row_idx + 1;
                        while ((start_idx > 0 and end_idx < pat_slice.len - 1)) {
                            start_idx -= 1;
                            end_idx += 1;
                            switch (rowsMismatchCount(pattern, start_idx, end_idx)) {
                                0 => {},
                                1 => {
                                    if (has_mismatch) {
                                        break :v false;
                                    } else {
                                        has_mismatch = true;
                                    }
                                },
                                else => break :v false,
                            }
                        }
                        break :v has_mismatch;
                    }
                };
                if (found_row_mirror) return 100 * (row_idx + 1);
            }
        }

        // Then vertical
        for (0..pat_slice[0].len - 1) |col_idx| {
            const initial_match_scenario: enum { NoMatch, Match, MatchWithMismatch } = switch (colsMismatchCount(pattern, col_idx, col_idx + 1)) {
                0 => .Match,
                1 => .MatchWithMismatch,
                else => .NoMatch,
            };

            if (initial_match_scenario != .NoMatch) {
                const found_col_mirror = v: {
                    var has_mismatch: bool = initial_match_scenario == .MatchWithMismatch;
                    if ((col_idx == 0) or ((col_idx + 1) == pat_slice[0].len - 1)) {
                        // If we're at endpoints, and have a single point of mismatch, then this is a mirror
                        break :v has_mismatch;
                    } else {
                        // Otherwise have to check other indices
                        var start_idx = col_idx;
                        var end_idx = col_idx + 1;
                        while ((start_idx > 0 and end_idx < pat_slice[0].len - 1)) {
                            start_idx -= 1;
                            end_idx += 1;

                            switch (colsMismatchCount(pattern, start_idx, end_idx)) {
                                0 => {},
                                1 => {
                                    if (has_mismatch) {
                                        break :v false;
                                    } else {
                                        has_mismatch = true;
                                    }
                                },
                                else => break :v false,
                            }
                        }
                        break :v has_mismatch;
                    }
                };
                if (found_col_mirror) return col_idx + 1;
            }
        }
        unreachable; // Must be a single reflection
    }

    test "solvePattern" {
        var pattern_reader = try PatternReader.init(true);
        defer pattern_reader.deinit();
        var pattern = pattern_reader.next().?;
        try std.testing.expectEqual(300, solvePattern(pattern));
        pattern = pattern_reader.next().?;
        try std.testing.expectEqual(100, solvePattern(pattern));
    }
};

fn calculateAnswer() ![2]usize {
    var answer1: usize = 0;
    var answer2: usize = 0;

    var pattern_reader = try PatternReader.init(false);

    defer pattern_reader.deinit();
    while (pattern_reader.next()) |pattern| {
        answer1 += part1.solvePattern(pattern);
        answer2 += part2.solvePattern(pattern);
    }

    return .{ answer1, answer2 };
}

pub fn main() !void {
    const answer = try calculateAnswer();
    std.log.info("Answer part 1: {d}", .{answer[0]});
    std.log.info("Answer part 2: {?}", .{answer[1]});
}

comptime {
    std.testing.refAllDecls(part1);
    std.testing.refAllDecls(part2);
}
