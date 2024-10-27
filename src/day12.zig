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

fn sumSlice(slice: []const usize) usize {
    var ret: usize = 0;
    for (slice) |v| {
        ret += v;
    }
    return ret;
}

fn findPossibilitiesImproved(springs: []const u8, groups: []const usize) usize {
    assert(groups.len > 0);

    const InnerTrackerArr = std.BoundedArray(usize, 50);
    const OuterTrackerArr = std.BoundedArray(InnerTrackerArr, 250);
    var tracking_arr = OuterTrackerArr.init(springs.len + groups[groups.len - 1] + 1) catch unreachable;
    for (tracking_arr.slice()) |*inner| {
        inner.* = InnerTrackerArr.init(groups.len) catch unreachable;
    }
    var min_j: usize = 0;
    outer: for (0..springs.len) |i| {
        inner: for (0..groups.len) |j| {
            const curr_char = springs[i];

            // If first group is at a broken spring, we skip it from now on
            // The first group decides all the valid starting positions and its placement can never
            // be past the first #.
            // TODO: I don't get it :(
            if (j < min_j) continue :inner;
            if (curr_char == '#' and j == 0) {
                min_j = 1;
            }

            // Periods are skipped over
            if (curr_char == '.') continue :outer;

            // If group can't be placed here according to previous logic, continue
            if (j > 0 and tracking_arr.constSlice()[i].constSlice()[j - 1] == 0) continue :inner;

            // If remaining groups don't fit in remaining springs, continue
            if (sumSlice(groups[j..]) + groups[j..].len - 1 > springs[i..].len)
                continue :inner;

            // If we are at last group and there are springs remaining, group isn't valid
            if (j == groups.len - 1) {
                if (std.mem.indexOfScalarPos(u8, springs, i + groups[j], '#')) |_| continue :inner;
            }

            // Check if current group is valid
            const max_idx = std.mem.min(usize, &.{ springs.len, i + groups[j] });
            const end_reached = max_idx == springs.len;
            const next_char: ?u8 = if (max_idx >= springs.len) null else springs[max_idx];
            const group_valid = v: {
                if (end_reached or (next_char != '#')) {
                    if (std.mem.indexOfScalar(u8, springs[i .. i + groups[j]], '.')) |_| break :v false else break :v true;
                } else break :v false;
            };
            if (!group_valid) continue :inner;

            // If our current group is valid, we add the amount of ways we can reach the next
            // starting location, to all indices up to and including a broken spring.
            // If there are no broken springs, that means all remaining positions are valid for the
            // next group. During next iterations, we can check if the next group fits there.
            // If it does, we can do the same thing and add the amount of ways we could get to the starting index for the group after that,
            // and so forth.
            // --------------------------------------------------
            //             01234567
            // Scenario 1: ??.??.?? 1,1,1
            // --------------------------------------------------
            //
            //       dp[0]      dp[1]      dp[2]      dp[3]      dp[4]      dp[5]      dp[6]      dp[7]      dp[8]       dp[9]     ]
            //     [ [0, 0, 0], [0, 0, 0], [1, 0, 0], [2, 0, 0], [2, 0, 0], [2, 2, 0], [2, 4, 0], [2, 4, 0], [2, 4, 4],  [2, 4, 8] ]
            // --------------------------------------------------
            //             0123456
            // Scenario 2: ??.#.?? 1,1,1
            // --------------------------------------------------
            //
            //       dp[0]      dp[1]      dp[2]      dp[3]      dp[4]      dp[5]      dp[6]      dp[7]      dp[8]     ]
            //     [ [0, 0, 0], [0, 0, 0], [1, 0, 0], [2, 0, 0], [0, 0, 0], [0, 2, 0], [0, 2, 0], [0, 2, 2], [0, 2, 4] ]
            const next_start_idx = std.mem.min(usize, &.{ springs.len, i + groups[j] + 1 });
            const next_broken_idx = if (std.mem.indexOfScalar(u8, springs[next_start_idx..], '#')) |n| next_start_idx + n else tracking_arr.len - 1;
            for (next_start_idx..next_broken_idx + 1) |k| {
                if (j > 0) {
                    tracking_arr.slice()[k].slice()[j] += tracking_arr.slice()[i].slice()[j - 1];
                } else {
                    tracking_arr.slice()[k].slice()[j] += 1;
                }
            }
        }
    }

    const outer_len = tracking_arr.len;
    const inner_len = tracking_arr.slice()[tracking_arr.len - 1].len;
    return tracking_arr.slice()[outer_len - 1].slice()[inner_len - 1];
}

test "findPossibilities - Normal" {
    try std.testing.expectEqual(1, findPossibilitiesImproved("???.###", &.{ 1, 1, 3 }));
    try std.testing.expectEqual(4, findPossibilitiesImproved(".??..??...?##.", &.{ 1, 1, 3 }));
    try std.testing.expectEqual(1, findPossibilitiesImproved("?#?#?#?#?#?#?#?", &.{ 1, 3, 1, 6 }));
    try std.testing.expectEqual(1, findPossibilitiesImproved("????.#...#...", &.{ 4, 1, 1 }));
    try std.testing.expectEqual(4, findPossibilitiesImproved("????.######..#####.", &.{ 1, 6, 5 }));
    try std.testing.expectEqual(10, findPossibilitiesImproved("?###????????", &.{ 3, 2, 1 }));
}

test "findPossibilities - Folded" {
    var data = try parseLine("???.### 1,1,3", true);
    try std.testing.expectEqual(1, findPossibilitiesImproved(data.spring_str.slice(), data.group_sizes.slice()));

    data = try parseLine(".??..??...?##. 1,1,3", true);
    try std.testing.expectEqual(16384, findPossibilitiesImproved(data.spring_str.slice(), data.group_sizes.slice()));

    data = try parseLine("?#?#?#?#?#?#?#? 1,3,1,6", true);
    try std.testing.expectEqual(1, findPossibilitiesImproved(data.spring_str.slice(), data.group_sizes.slice()));

    data = try parseLine("????.#...#... 4,1,1", true);
    try std.testing.expectEqual(16, findPossibilitiesImproved(data.spring_str.slice(), data.group_sizes.slice()));

    data = try parseLine("????.######..#####. 1,6,5", true);
    try std.testing.expectEqual(2500, findPossibilitiesImproved(data.spring_str.slice(), data.group_sizes.slice()));

    data = try parseLine("?###???????? 3,2,1", true);
    try std.testing.expectEqual(506250, findPossibilitiesImproved(data.spring_str.slice(), data.group_sizes.slice()));
}

const SpringData = struct {
    pub const SpringArr = std.BoundedArray(u8, 120);
    pub const GroupArr = std.BoundedArray(usize, 120);
    spring_str: SpringArr,
    group_sizes: GroupArr,
};

fn parseLine(line: []const u8, comptime unfold: bool) !SpringData {
    var iter = std.mem.splitScalar(u8, line, ' ');
    const spring_string = iter.next().?;

    var spring_ret = try SpringData.SpringArr.init(0);
    try spring_ret.appendSlice(spring_string);

    if (unfold) {
        for (0..4) |_| {
            try spring_ret.append('?');
            try spring_ret.appendSlice(spring_string);
        }
    }

    const num_string = iter.next().?;
    var num_iter = std.mem.splitScalar(u8, num_string, ',');

    var num_ret = try SpringData.GroupArr.init(0);
    while (num_iter.next()) |num_str| {
        try num_ret.append(try std.fmt.parseInt(usize, num_str, 10));
    }

    if (unfold) {
        const init_term = num_ret.slice().len;
        for (0..4) |_| {
            try num_ret.appendSlice(num_ret.slice()[0..init_term]);
        }
    }

    return .{
        .spring_str = spring_ret,
        .group_sizes = num_ret,
    };
}

test "parseLine" {
    const ret = try parseLine(".# 1", false);
    try std.testing.expectEqualStrings(".#", ret.spring_str.slice());
    try std.testing.expectEqualSlices(usize, &.{1}, ret.group_sizes.slice());

    const ret_folded = try parseLine(".# 1", true);
    try std.testing.expectEqualStrings(".#?.#?.#?.#?.#", ret_folded.spring_str.slice());
    try std.testing.expectEqualSlices(usize, &.{ 1, 1, 1, 1, 1 }, ret_folded.group_sizes.slice());
}

fn calculateAnswer(allocator: std.mem.Allocator) ![2]usize {
    var answer1: usize = 0;
    var answer2: usize = 0;
    inline for (.{ false, true }) |folding| {
        var file_line_reader = try helpers.lineReaderFromAdventDay(12, allocator);
        defer file_line_reader.deinit();
        while (file_line_reader.next()) |line| {
            const spring_data = try parseLine(line, folding);
            if (folding) {
                answer2 += findPossibilitiesImproved(spring_data.spring_str.slice(), spring_data.group_sizes.slice());
            } else {
                answer1 += findPossibilitiesImproved(spring_data.spring_str.slice(), spring_data.group_sizes.slice());
            }
        }
    }

    return .{ answer1, answer2 };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const answer = try calculateAnswer(alloc);

    std.log.info("Answer part 1: {d}", .{answer[0]});
    std.log.info("Answer part 2: {?}", .{answer[1]});
    std.debug.assert(!gpa.detectLeaks());
}
