const std = @import("std");
const helpers = @import("helpers");
const GeneralErrors = helpers.GeneralErrors;

pub const std_options: std.Options = .{
    .log_level = .info,
};

fn numStrIntoOwnedSlice(allocator: std.mem.Allocator, num_str: []const u8) ![]usize {
    var num_it = std.mem.tokenizeAny(u8, num_str, " ");
    var i: usize = 0;
    var output = std.ArrayList(usize).init(allocator);
    defer output.deinit();
    while (num_it.next()) |ns| : (i += 1) {
        try output.append(try std.fmt.parseInt(usize, ns, 10));
    }
    return try output.toOwnedSlice();
}

fn calculateAnswer(allocator: std.mem.Allocator) ![2]usize {
    var file_line_reader = try helpers.FixedBufferLineReader(130).fromAdventDay(4);
    defer file_line_reader.deinit();

    var sum_part1: usize = 0;
    var winning_counts = std.ArrayList(usize).init(allocator);
    defer winning_counts.deinit();

    while (file_line_reader.next()) |line| {
        var split_it = std.mem.splitSequence(u8, line, ": ");
        _ = split_it.next() orelse {
            return GeneralErrors.UnexpectedFormat;
        };
        const both_cards = split_it.next() orelse {
            return GeneralErrors.UnexpectedFormat;
        };
        split_it = std.mem.splitSequence(u8, both_cards, " | ");
        const winning_nums_str = split_it.next() orelse {
            return GeneralErrors.UnexpectedFormat;
        };

        const winning_nums = try numStrIntoOwnedSlice(allocator, winning_nums_str);
        defer allocator.free(winning_nums);

        const nums_have_str = split_it.next() orelse {
            return GeneralErrors.UnexpectedFormat;
        };

        const nums_have = try numStrIntoOwnedSlice(allocator, nums_have_str);
        defer allocator.free(nums_have);

        var curr_card_score: usize = 0;
        var num_matches: usize = 0;
        for (nums_have) |num| {
            if (std.mem.indexOfScalar(usize, winning_nums, num)) |_| {
                curr_card_score = if (curr_card_score == 0) 1 else curr_card_score * 2;
                num_matches += 1;
            }
        }
        try winning_counts.append(num_matches);
        sum_part1 += curr_card_score;
    }

    var sum_part2: usize = 0;
    for (0..winning_counts.items.len) |i| {
        sum_part2 += processFirstWinningNumber(winning_counts.items[i..]);
    }

    return .{ sum_part1, sum_part2 };
}

fn processFirstWinningNumber(cards: []const usize) usize {
    if (cards[0] > 0) {
        var sum: usize = 0;
        for (0..cards[0]) |i| {
            sum += processFirstWinningNumber(cards[1 + i ..]);
        }
        return sum + 1;
    } else {
        return 1;
    }
}

test "Process cards" {
    const cards = [_]usize{ 2, 1, 0 };
    var sum: usize = 0;
    for (0..cards.len) |i| {
        sum += processFirstWinningNumber(cards[i..]);
    }
    try std.testing.expectEqual(7, sum);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const answer = try calculateAnswer(alloc);
    std.log.info("Answer - [Part1: {d}, Part2: {d}]\n", .{ answer[0], answer[1] });
    std.debug.assert(!gpa.detectLeaks());
}
