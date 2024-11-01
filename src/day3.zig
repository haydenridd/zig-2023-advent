const std = @import("std");
const helpers = @import("helpers");
const GeneralErrors = helpers.GeneralErrors;

pub const std_options: std.Options = .{
    .log_level = .info,
};

fn isSymbol(byte: u8) bool {
    return !std.ascii.isDigit(byte) and (byte != '.');
}

test "isSymbol" {
    try std.testing.expect(isSymbol('#'));
    try std.testing.expect(isSymbol('&'));
    try std.testing.expect(isSymbol('*'));
    try std.testing.expect(isSymbol('('));
    try std.testing.expect(!isSymbol('.'));
    try std.testing.expect(!isSymbol('9'));
}

fn isPartNumber(pn_start_idx: usize, pn_end_idx: usize, previous_line: ?[]const u8, current_line: []const u8, next_line: ?[]const u8) bool {
    const range_to_look_start_idx = if (pn_start_idx == 0) 0 else pn_start_idx - 1;
    const range_to_look_end_idx = if (pn_end_idx == current_line.len - 1) current_line.len - 1 else pn_end_idx + 1;
    var is_pn = false;

    // Line above contains adjacent symbol
    if (previous_line) |line| {
        for (line[range_to_look_start_idx .. range_to_look_end_idx + 1]) |chunk| {
            if (isSymbol(chunk)) {
                is_pn = true;
                break;
            }
        }
    }
    if (is_pn) return is_pn;

    // Current line contains adjacent symbol
    for (current_line[range_to_look_start_idx .. range_to_look_end_idx + 1]) |chunk| {
        if (isSymbol(chunk)) {
            is_pn = true;
            break;
        }
    }

    // Line below contains adjacent symbol
    if (next_line) |line| {
        for (line[range_to_look_start_idx .. range_to_look_end_idx + 1]) |chunk| {
            if (isSymbol(chunk)) {
                is_pn = true;
                break;
            }
        }
    }
    return is_pn;
}

test "isPartNumber" {

    // Normal stuff
    try std.testing.expect(isPartNumber(1, 2, "*.........", ".10.......", ".........."));
    try std.testing.expect(isPartNumber(1, 2, ".*........", ".10.......", ".........."));
    try std.testing.expect(isPartNumber(1, 2, "..*.......", ".10.......", ".........."));
    try std.testing.expect(isPartNumber(1, 2, "...*......", ".10.......", ".........."));
    try std.testing.expect(isPartNumber(1, 2, "..........", ".10.......", "*........."));
    try std.testing.expect(isPartNumber(1, 2, "..........", ".10.......", ".*........"));
    try std.testing.expect(isPartNumber(1, 2, "..........", ".10.......", "..*......."));
    try std.testing.expect(isPartNumber(1, 2, "..........", ".10.......", "...*......"));
    try std.testing.expect(!isPartNumber(1, 2, "..........", ".10.......", ".........."));
    try std.testing.expect(!isPartNumber(0, 1, "..........", "..........", ".........."));

    // Edge cases
    try std.testing.expect(isPartNumber(1, 2, "*.........", ".10.......", null));
    try std.testing.expect(isPartNumber(1, 2, null, ".10.......", "*........."));
    try std.testing.expect(isPartNumber(0, 1, "..*.......", "10........", ".........."));
    try std.testing.expect(isPartNumber(8, 9, ".........*", "........10", ".........."));
}

const NumberSlice = struct { value: usize, start_idx: usize, end_idx: usize };

const StringNumberSlicer = struct {
    string: []const u8,
    curr_idx: usize,

    pub fn next(self: *StringNumberSlicer) ?NumberSlice {
        if (self.curr_idx >= self.string.len) return null;

        // Seek next digit
        while (self.curr_idx < self.string.len and !std.ascii.isDigit(self.string[self.curr_idx])) : (self.curr_idx += 1) {}
        if (self.curr_idx >= self.string.len) return null;

        // Found one, seek until not a digit
        const digit_start_idx = self.curr_idx;
        while (self.curr_idx < self.string.len and std.ascii.isDigit(self.string[self.curr_idx])) : (self.curr_idx += 1) {}
        return NumberSlice{ .value = std.fmt.parseInt(usize, self.string[digit_start_idx..self.curr_idx], 10) catch unreachable, .start_idx = digit_start_idx, .end_idx = self.curr_idx - 1 };
    }

    pub fn init(string: []const u8) StringNumberSlicer {
        return StringNumberSlicer{ .string = string, .curr_idx = 0 };
    }
};

test "Number slicer" {
    var ns = StringNumberSlicer.init("......123...");
    try std.testing.expectEqual(NumberSlice{ .value = 123, .start_idx = 6, .end_idx = 8 }, ns.next().?);
    try std.testing.expect(ns.next() == null);

    ns = StringNumberSlicer.init("11...12.13");
    try std.testing.expectEqual(NumberSlice{ .value = 11, .start_idx = 0, .end_idx = 1 }, ns.next().?);
    try std.testing.expectEqual(NumberSlice{ .value = 12, .start_idx = 5, .end_idx = 6 }, ns.next().?);
    try std.testing.expectEqual(NumberSlice{ .value = 13, .start_idx = 8, .end_idx = 9 }, ns.next().?);
    try std.testing.expect(ns.next() == null);

    ns = StringNumberSlicer.init("1.......");
    try std.testing.expectEqual(NumberSlice{ .value = 1, .start_idx = 0, .end_idx = 0 }, ns.next().?);
    try std.testing.expect(ns.next() == null);
}

fn isGear(gear_idx: usize, previous_line: ?[]const u8, current_line: []const u8, next_line: ?[]const u8) ?usize {
    var adjacent_part_count: usize = 0;
    var first_num: ?NumberSlice = null;
    var second_num: ?NumberSlice = null;

    if (previous_line) |line| {
        var slicer = StringNumberSlicer.init(line);
        while (slicer.next()) |part_num| {
            const adj_start_idx: usize = if (part_num.start_idx == 0) 0 else part_num.start_idx - 1;
            if ((gear_idx >= adj_start_idx) and (gear_idx <= part_num.end_idx + 1)) {
                adjacent_part_count += 1;
                if (first_num == null) {
                    first_num = part_num;
                } else if ((second_num == null) and (first_num != null)) {
                    second_num = part_num;
                }
            }
        }
    }
    if (adjacent_part_count > 2) return null;

    var slicer_outer = StringNumberSlicer.init(current_line);
    while (slicer_outer.next()) |part_num| {
        const adj_start_idx: usize = if (part_num.start_idx == 0) 0 else part_num.start_idx - 1;
        if ((gear_idx >= adj_start_idx) and (gear_idx <= part_num.end_idx + 1)) {
            adjacent_part_count += 1;
            if (first_num == null) {
                first_num = part_num;
            } else if ((second_num == null) and (first_num != null)) {
                second_num = part_num;
            }
        }
    }
    if (adjacent_part_count > 2) return null;

    if (next_line) |line| {
        var slicer = StringNumberSlicer.init(line);
        while (slicer.next()) |part_num| {
            const adj_start_idx: usize = if (part_num.start_idx == 0) 0 else part_num.start_idx - 1;
            if ((gear_idx >= adj_start_idx) and (gear_idx <= part_num.end_idx + 1)) {
                adjacent_part_count += 1;
                if (first_num == null) {
                    first_num = part_num;
                } else if ((second_num == null) and (first_num != null)) {
                    second_num = part_num;
                }
            }
        }
    }

    if (adjacent_part_count == 2) {
        return first_num.?.value * second_num.?.value;
    } else {
        return null;
    }
}

test "isGear" {
    try std.testing.expectEqual(100, isGear(0, "10........", "*.........", "10........"));
    try std.testing.expectEqual(null, isGear(1, "1.1.......", ".*........", "10........"));
}

fn calculateAnswer(allocator: std.mem.Allocator) ![2]usize {
    var file_line_reader = try helpers.FixedBufferLineReader(150).fromAdventDay(3);
    defer file_line_reader.deinit();

    var sum_part1: usize = 0;
    var sum_part2: usize = 0;
    var three_lines: [3]?[]const u8 = .{ null, null, null };

    defer {
        for (0..three_lines.len) |i| {
            if (three_lines[i]) |_| {
                allocator.free(three_lines[i].?);
            }
        }
    }

    while (true) {

        // Shift in new line, discard + free end line
        if (three_lines[0]) |_| {
            allocator.free(three_lines[0].?);
        }
        three_lines[0] = three_lines[1];
        three_lines[1] = three_lines[2];
        three_lines[2] = v: {
            var v = std.ArrayList(u8).init(allocator);
            try v.appendSlice(file_line_reader.next() orelse break :v null);
            break :v try v.toOwnedSlice();
        };

        // Start condition
        if ((three_lines[0] == null) and (three_lines[1] == null)) {
            continue;
        }

        // Normal case

        // Part 1
        var ns = StringNumberSlicer.init(three_lines[1].?);
        while (ns.next()) |potential_part_num| {
            if (isPartNumber(potential_part_num.start_idx, potential_part_num.end_idx, if (three_lines[0]) |v| v else null, three_lines[1].?, if (three_lines[2]) |v| v else null)) {
                sum_part1 += potential_part_num.value;
            }
        }

        // Part 2
        var gear_idx: usize = 0;
        while (gear_idx < three_lines[1].?.len) : (gear_idx += 1) {
            if (three_lines[1].?[gear_idx] == '*') {
                if (isGear(gear_idx, if (three_lines[0]) |v| v else null, three_lines[1].?, if (three_lines[2]) |v| v else null)) |gear_ratio| {
                    sum_part2 += gear_ratio;
                }
            }
        }

        // Special case for last line (EOF)
        if (three_lines[2] == null) break;
    }

    return .{ sum_part1, sum_part2 };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const answer = try calculateAnswer(alloc);
    std.log.info("Answer - [Part1: {d}, Part2: {d}]\n", .{ answer[0], answer[1] });
    std.debug.assert(!gpa.detectLeaks());
}
