const std = @import("std");
const helpers = @import("helpers");
const GeneralErrors = helpers.GeneralErrors;

pub const std_options: std.Options = .{
    .log_level = .info,
};

const DaySpecificErrors = error{Something};
const assert = std.debug.assert;

const LineCollector = helpers.LineCollector(110, 110);

const part1 = struct {
    fn slideRocks(lines: LineCollector.LineArray, comptime direction: enum { North, East, South, West }) LineCollector.LineArray {
        var ret = lines;

        switch (direction) {
            .North => {
                for (0..ret.slice()[0].len) |col_idx| {

                    // Tracks where a rock could "slide" to currently
                    var curr_slide_to_idx: usize = 0;

                    for (0..ret.len) |row_idx| {
                        switch (ret.slice()[row_idx].slice()[col_idx]) {
                            'O' => {
                                ret.slice()[row_idx].slice()[col_idx] = '.';
                                ret.slice()[curr_slide_to_idx].slice()[col_idx] = 'O';
                                curr_slide_to_idx += 1;
                            },
                            '.' => {
                                // Do nothing, doesn't change slide to index
                            },
                            '#' => {
                                // New slide to point
                                curr_slide_to_idx = row_idx + 1;
                            },
                            else => unreachable,
                        }
                    }
                }
            },
            .South => {
                for (0..ret.slice()[0].len) |col_idx| {

                    // Tracks where a rock could "slide" to currently
                    var curr_slide_to_idx: usize = ret.len - 1;

                    for (0..ret.len) |temp_row_idx| {
                        const row_idx = ret.len - 1 - temp_row_idx;
                        switch (ret.slice()[row_idx].slice()[col_idx]) {
                            'O' => {
                                ret.slice()[row_idx].slice()[col_idx] = '.';
                                ret.slice()[curr_slide_to_idx].slice()[col_idx] = 'O';
                                curr_slide_to_idx = if (curr_slide_to_idx > 0) curr_slide_to_idx - 1 else 0;
                            },
                            '.' => {
                                // Do nothing, doesn't change slide to index
                            },
                            '#' => {
                                // New slide to point
                                curr_slide_to_idx = if (row_idx > 0) row_idx - 1 else 0;
                            },
                            else => unreachable,
                        }
                    }
                }
            },
            .West => {
                for (0..ret.len) |row_idx| {

                    // Tracks where a rock could "slide" to currently
                    var curr_slide_to_idx: usize = 0;

                    for (0..ret.slice()[0].len) |col_idx| {
                        switch (ret.slice()[row_idx].slice()[col_idx]) {
                            'O' => {
                                ret.slice()[row_idx].slice()[col_idx] = '.';
                                ret.slice()[row_idx].slice()[curr_slide_to_idx] = 'O';
                                curr_slide_to_idx += 1;
                            },
                            '.' => {
                                // Do nothing, doesn't change slide to index
                            },
                            '#' => {
                                // New slide to point
                                curr_slide_to_idx = col_idx + 1;
                            },
                            else => unreachable,
                        }
                    }
                }
            },
            .East => {
                for (0..ret.len) |row_idx| {

                    // Tracks where a rock could "slide" to currently
                    var curr_slide_to_idx: usize = ret.slice()[0].len - 1;

                    for (0..ret.slice()[0].len) |temp_col_idx| {
                        const col_idx = ret.slice()[0].len - 1 - temp_col_idx;
                        switch (ret.slice()[row_idx].slice()[col_idx]) {
                            'O' => {
                                ret.slice()[row_idx].slice()[col_idx] = '.';
                                ret.slice()[row_idx].slice()[curr_slide_to_idx] = 'O';
                                curr_slide_to_idx = if (curr_slide_to_idx > 0) curr_slide_to_idx - 1 else 0;
                            },
                            '.' => {
                                // Do nothing, doesn't change slide to index
                            },
                            '#' => {
                                // New slide to point
                                curr_slide_to_idx = if (col_idx > 0) col_idx - 1 else 0;
                            },
                            else => unreachable,
                        }
                    }
                }
            },
        }

        return ret;
    }

    test "slideRocks" {
        const dummy: LineCollector.LineArray =
            comptime v: {
            var ret = LineCollector.LineArray.init(3) catch unreachable;

            for (&.{ "..#", "O..", "O.O" }, 0..) |slice, idx| {
                ret.slice()[idx] = LineCollector.LineBuffer.init(0) catch unreachable;
                ret.slice()[idx].appendSlice(slice) catch unreachable;
            }
            break :v ret;
        };

        // ..#    O.#
        // O.. -> O.O
        // O.O    ...
        var expected = slideRocks(dummy, .North);
        try std.testing.expectEqualStrings("O.#", expected.slice()[0].slice());
        try std.testing.expectEqualStrings("O.O", expected.slice()[1].slice());
        try std.testing.expectEqualStrings("...", expected.slice()[2].slice());

        // ..#    ..#
        // O.. -> O..
        // O.O    O.O
        expected = slideRocks(dummy, .South);
        try std.testing.expectEqualStrings("..#", expected.slice()[0].slice());
        try std.testing.expectEqualStrings("O..", expected.slice()[1].slice());
        try std.testing.expectEqualStrings("O.O", expected.slice()[2].slice());

        // ..#    ..#
        // O.. -> O..
        // O.O    OO.
        expected = slideRocks(dummy, .West);
        try std.testing.expectEqualStrings("..#", expected.slice()[0].slice());
        try std.testing.expectEqualStrings("O..", expected.slice()[1].slice());
        try std.testing.expectEqualStrings("OO.", expected.slice()[2].slice());

        // ..#    ..#
        // O.. -> ..O
        // O.O    .OO
        expected = slideRocks(dummy, .East);
        try std.testing.expectEqualStrings("..#", expected.slice()[0].slice());
        try std.testing.expectEqualStrings("..O", expected.slice()[1].slice());
        try std.testing.expectEqualStrings(".OO", expected.slice()[2].slice());
    }

    fn calculateLoad(lines: LineCollector.LineArray) usize {
        const num_rows = lines.len;
        var total_force: usize = 0;
        for (lines.constSlice(), 0..) |row, row_idx| {
            total_force += (num_rows - row_idx) * std.mem.count(u8, row.constSlice(), &.{'O'});
        }
        return total_force;
    }

    test "part1" {
        const line_arr_north = slideRocks(LineCollector.collectFromTestInput(14), .North);
        try std.testing.expectEqual(136, calculateLoad(line_arr_north));
    }
};

const part2 = struct {
    fn cycle(lines: LineCollector.LineArray) LineCollector.LineArray {
        return part1.slideRocks(part1.slideRocks(part1.slideRocks(part1.slideRocks(lines, .North), .West), .South), .East);
    }

    fn hashLineArray(lines: LineCollector.LineArray) u64 {
        const Wyhash = std.hash.Wyhash;
        var hasher = Wyhash.init(0);
        for (lines.constSlice()) |ln| {
            hasher.update(ln.constSlice());
        }
        return hasher.final();
    }

    fn calculateLoad(lines: LineCollector.LineArray) !usize {

        // Create storage for hashes
        var hashes = try std.BoundedArray(u64, 1000).init(0);
        try hashes.append(hashLineArray(lines));
        var shuffled = lines;

        var i: usize = 0;
        var repeated_idx: usize = undefined;
        while (true) {
            shuffled = cycle(shuffled);
            i += 1;
            const hsh = hashLineArray(shuffled);
            if (std.mem.indexOfScalar(u64, hashes.constSlice(), hsh)) |hash_idx| {
                repeated_idx = hash_idx;
                break;
            }
            try hashes.append(hsh);
        }

        // (i - repeated_idx) + 1 -> Gets you back to the same value that "shuffled" is currently

        const repetition_number = i - repeated_idx;
        const remaining_cycles = 1_000_000_000 - i;
        const remainder = remaining_cycles % repetition_number;

        for (0..remainder) |_| {
            shuffled = cycle(shuffled);
        }
        return part1.calculateLoad(shuffled);
    }

    test "part2" {
        const lines = LineCollector.collectFromTestInput(14);

        const expected_lines_1 = &.{
            ".....#....",
            "....#...O#",
            "...OO##...",
            ".OO#......",
            ".....OOO#.",
            ".O#...O#.#",
            "....O#....",
            "......OOOO",
            "#...O###..",
            "#..OO#....",
        };
        const shuffled_1 = cycle(lines);

        inline for (expected_lines_1, 0..) |line, i| {
            try std.testing.expectEqualStrings(line, shuffled_1.slice()[i].slice());
        }

        const expected_lines_2 = &.{
            ".....#....",
            "....#...O#",
            ".....##...",
            "..O#......",
            ".....OOO#.",
            ".O#...O#.#",
            "....O#...O",
            ".......OOO",
            "#..OO###..",
            "#.OOO#...O",
        };
        const shuffled_2 = cycle(shuffled_1);

        inline for (expected_lines_2, 0..) |line, i| {
            try std.testing.expectEqualStrings(line, shuffled_2.slice()[i].slice());
        }

        const expected_lines_3 = &.{
            ".....#....",
            "....#...O#",
            ".....##...",
            "..O#......",
            ".....OOO#.",
            ".O#...O#.#",
            "....O#...O",
            ".......OOO",
            "#...O###.O",
            "#.OOO#...O",
        };
        const shuffled_3 = cycle(shuffled_2);

        inline for (expected_lines_3, 0..) |line, i| {
            try std.testing.expectEqualStrings(line, shuffled_3.slice()[i].slice());
        }

        try std.testing.expectEqual(64, try calculateLoad(lines));
    }
};

fn calculateAnswer() ![2]usize {
    var answer1: usize = 0;
    var answer2: usize = 0;
    const lines = LineCollector.collectFromAdventDay(14);

    answer1 = part1.calculateLoad(part1.slideRocks(lines, .North));
    answer2 = try part2.calculateLoad(lines);
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
