const std = @import("std");
const helpers = @import("helpers");
const FileLineReader = helpers.FileLineReader;
const GeneralErrors = helpers.GeneralErrors;
const DaySpecificErrors = error{Something};
const assert = std.debug.assert;

const build_options = @import("build_options");

pub const std_options: std.Options = .{
    .log_level = .info,
};

const PatternLineArray = std.BoundedArray(u8, 20);
const PatternArray = std.BoundedArray(PatternLineArray, 20);

const PatternReader = struct {
    file: std.fs.File,

    pub fn init(path: []const u8) !PatternReader {
        return PatternReader{ .file = try std.fs.cwd().openFile(path, .{}) };
    }

    pub fn deinit(self: *PatternReader) void {
        self.file.close();
    }

    pub fn next(self: *PatternReader) ?PatternArray {
        var ret = PatternArray.init(0) catch unreachable;

        var current_line = std.BoundedArray(u8, 300).init(0) catch unreachable;
        current_line.append(' ') catch unreachable;

        while (current_line.len > 0) {
            current_line.resize(0) catch unreachable;
            self.file.reader().streamUntilDelimiter(current_line.writer(), '\n', null) catch {
                break;
            };
            if (current_line.len > 0) {
                const item = ret.addOne() catch unreachable;
                item.* = PatternLineArray.init(0) catch unreachable;
                item.*.appendSlice(current_line.constSlice()) catch unreachable;
            }
        }
        return if (ret.len == 0) null else ret;
    }
};

fn printPattern(pattern: PatternArray) void {
    for (pattern.slice()) |ln| {
        std.debug.print("{s}\n", .{ln.slice()});
    }
}

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
        std.debug.print("{c}{c}\n", .{ ln_slice[col_idx1], ln_slice[col_idx2] });
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

const EqualWithSingleOff = struct {
    equal: bool,
    idx_single_mismatch: ?usize = null,
};

fn rowsEqualSingleOff(pattern: PatternArray, row_idx1: usize, row_idx2: usize) EqualWithSingleOff {
    var mismatch_count: usize = 0;
    var mismatch_idx: usize = 0;
    const row1 = pattern.constSlice()[row_idx1].constSlice();
    const row2 = pattern.constSlice()[row_idx2].constSlice();

    for (0..row1.len) |i| {
        if (row1[i] != row2[i]) {
            mismatch_count += 1;
            mismatch_idx = i;
        }
        if (mismatch_count > 1) return .{ .equal = false, .idx_single_mismatch = null };
    }

    return .{ .equal = true, .idx_single_mismatch = if (mismatch_count > 0) mismatch_idx else null };
}

fn colsEqualSingleOff(pattern: PatternArray, col_idx1: usize, col_idx2: usize) EqualWithSingleOff {
    var mismatch_count: usize = 0;
    var mismatch_idx: usize = 0;
    for (pattern.constSlice()) |ln| {
        const ln_slice = ln.constSlice();
        if (ln_slice[col_idx1] != ln_slice[col_idx2]) {
            mismatch_count += 1;
            mismatch_idx = col_idx1;
        }
        if (mismatch_count > 1) return .{ .equal = false, .idx_single_mismatch = null };
    }
    return .{ .equal = true, .idx_single_mismatch = if (mismatch_count > 0) mismatch_idx else null };
}

fn solvePatternSmudge(pattern: PatternArray) usize {

    // Check for a horizontal line first
    const pat_slice = pattern.constSlice();
    for (0..pat_slice.len - 1) |row_idx| {
        const rows_eql = rowsEqualSingleOff(pattern, row_idx, row_idx + 1);
        var single_off_idx = rows_eql.idx_single_mismatch;
        if (rows_eql.equal) {
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
    unreachable; // Are there allowed to be no reflections?
}

test "solvePattern" {
    var pattern_reader = try PatternReader.init("./test_inputs/day13_input.txt");
    defer pattern_reader.deinit();
    var pattern = pattern_reader.next().?;
    try std.testing.expectEqual(5, solvePattern(pattern));
    pattern = pattern_reader.next().?;
    try std.testing.expectEqual(400, solvePattern(pattern));
}

fn calculateAnswer() ![2]usize {
    var answer1: usize = 0;
    var answer2: usize = 0;

    var pattern_reader = try PatternReader.init("./inputs/day13_input.txt");

    defer pattern_reader.deinit();
    while (pattern_reader.next()) |pattern| {
        answer1 += solvePattern(pattern);
        answer2 = 0;
    }

    return .{ answer1, answer2 };
}

pub fn main() !void {
    const answer = try calculateAnswer();
    std.log.info("Answer part 1: {d}", .{answer[0]});
    std.log.info("Answer part 2: {?}", .{answer[1]});
}
