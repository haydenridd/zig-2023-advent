const std = @import("std");
const helpers = @import("helpers");

pub const std_options: std.Options = .{
    .log_level = .info,
};

const number_strings = .{ "one", "two", "three", "four", "five", "six", "seven", "eight", "nine" };

fn startsWithWordReprOfDigit(str: []const u8) ?u8 {
    inline for (number_strings, 1..) |s, n| {
        if (std.ascii.startsWithIgnoreCase(str, s)) {
            return n;
        }
    }
    return null;
}

fn decodeLineToTwoDigitNumber(line: []const u8, comptime part2_condition: bool) usize {
    var line_sum: ?usize = null;
    var last_valid_digit: u8 = 0;
    for (line, 0..) |char, idx| {
        const digit = std.fmt.parseInt(u8, &[_]u8{char}, 10) catch a: {
            if (startsWithWordReprOfDigit(line[idx..])) |d| {
                if (part2_condition) break :a d else continue;
            } else {
                continue;
            }
        };
        last_valid_digit = digit;
        if (line_sum) |_| {} else {
            line_sum = digit * 10;
        }
    }
    return line_sum.? + last_valid_digit;
}

fn calculateAnswer() ![2]usize {
    var file_line_reader = try helpers.FixedBufferLineReader(100).fromAdventDay(1);
    defer file_line_reader.deinit();
    var total_sum_part1: usize = 0;
    var total_sum_part2: usize = 0;
    while (file_line_reader.next()) |line| {
        total_sum_part1 += decodeLineToTwoDigitNumber(line, false);
        total_sum_part2 += decodeLineToTwoDigitNumber(line, true);
    }
    return .{ total_sum_part1, total_sum_part2 };
}

pub fn main() !void {
    const answer = try calculateAnswer();
    std.log.info("Answer - [Part1: {d}, Part2: {d}]\n", .{ answer[0], answer[1] });
}

test "Digit parsing" {

    // vanilla
    try std.testing.expectEqual(1, startsWithWordReprOfDigit("one"));
    try std.testing.expectEqual(2, startsWithWordReprOfDigit("two"));
    try std.testing.expectEqual(3, startsWithWordReprOfDigit("three"));
    try std.testing.expectEqual(4, startsWithWordReprOfDigit("four"));
    try std.testing.expectEqual(5, startsWithWordReprOfDigit("five"));
    try std.testing.expectEqual(6, startsWithWordReprOfDigit("six"));
    try std.testing.expectEqual(7, startsWithWordReprOfDigit("seven"));
    try std.testing.expectEqual(8, startsWithWordReprOfDigit("eight"));
    try std.testing.expectEqual(9, startsWithWordReprOfDigit("nine"));

    // Spicier
    try std.testing.expectEqual(1, startsWithWordReprOfDigit("oneandsomestuff"));
    try std.testing.expectEqual(null, startsWithWordReprOfDigit("on"));
    try std.testing.expectEqual(7, startsWithWordReprOfDigit("sEvENasdfasdf"));
}

test "Part 1 string formats" {
    // Normy
    try std.testing.expectEqual(12, decodeLineToTwoDigitNumber("12", false));

    // Watch for no second digit!
    try std.testing.expectEqual(11, decodeLineToTwoDigitNumber("1", false));

    // Watch for digits in between first <--> last
    try std.testing.expectEqual(12, decodeLineToTwoDigitNumber("11114444445555552", false));
}

test "Part 2 string formats" {

    // Getting spicy with letters now
    try std.testing.expectEqual(12, decodeLineToTwoDigitNumber("19two", true));
    try std.testing.expectEqual(13, decodeLineToTwoDigitNumber("onethree", true));
    try std.testing.expectEqual(12, decodeLineToTwoDigitNumber("asdfone777777two", true));
}
