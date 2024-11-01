const std = @import("std");
const helpers = @import("helpers");
const GeneralErrors = helpers.GeneralErrors;

pub const std_options: std.Options = .{
    .log_level = .info,
};

const DaySpecificErrors = error{Something};
const assert = std.debug.assert;

const build_options = @import("build_options");

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

const cache_method = struct {
    const CacheKey = struct {
        spring_idx: usize,
        group_idx: usize,
    };

    const Cache = std.AutoHashMap(CacheKey, usize);

    test "Cache HashMap" {
        var hash_map = Cache.init(std.testing.allocator);
        defer hash_map.deinit();
        const dummy_key: CacheKey = .{ .spring_idx = 0, .group_idx = 1 };

        try hash_map.put(dummy_key, 100);
        try std.testing.expectEqual(100, hash_map.get(dummy_key).?);
        try std.testing.expectEqual(null, hash_map.get(.{ .spring_idx = 0, .group_idx = 0 }));
    }

    fn findPossibilitiesInternal(springs: []const u8, spring_idx: usize, groups: []const usize, group_idx: usize, cache: *Cache) usize {

        // End conditions:
        if (group_idx >= groups.len) {
            // No more groups
            if (spring_idx >= springs.len) {
                // Also no more springs, valid
                return 1;
            } else {
                // If more springs, but all '.' or '?', valid, else invalid
                return if (std.mem.indexOfScalar(u8, springs[spring_idx..], '#')) |_| 0 else 1;
            }
        } else if (springs[spring_idx..].len < groups[group_idx]) {
            // Less springs than required group, invalid
            return 0;
        }

        if (springs[spring_idx] == '.') {
            // Skip to next character
            return findPossibilitiesInternal(springs, spring_idx + 1, groups, group_idx, cache);
        } else {
            const is_valid = v: {
                // Can't have any '.' within a group
                if (std.mem.indexOfScalar(u8, springs[spring_idx .. spring_idx + groups[group_idx]], '.')) |_| break :v false;

                // Last character can not be '#'
                if (springs[spring_idx..].len > groups[group_idx]) {
                    if (springs[spring_idx + groups[group_idx]] == '#') {
                        break :v false;
                    }
                } else {
                    // Special case where we exhausted springs so can immediately determine if this is a valid sequence
                    if ((groups.len - group_idx) > 1) return 0 else return 1;
                }

                break :v true;
            };
            var ret: usize = 0;
            const key: CacheKey = .{ .spring_idx = spring_idx, .group_idx = group_idx };
            if (cache.get(key)) |v| {
                ret = v;
            } else {
                if (is_valid) {
                    if (springs[spring_idx] == '?') {
                        // Try both paths, ? is a # and thus valid group, or a . and skip to next char
                        ret = findPossibilitiesInternal(springs, spring_idx + 1, groups, group_idx, cache) + findPossibilitiesInternal(springs, spring_idx + groups[group_idx] + 1, groups, group_idx + 1, cache);
                    } else {
                        // Continue on since this group must go here
                        ret = findPossibilitiesInternal(springs, spring_idx + groups[group_idx] + 1, groups, group_idx + 1, cache);
                    }
                } else if (springs[spring_idx] == '#') {
                    // If group is invalid but the first char is # then this combo can't be valid
                    ret = 0;
                } else {
                    // Still a chance this group could be valid, continue
                    ret = findPossibilitiesInternal(springs, spring_idx + 1, groups, group_idx, cache);
                }
                const v = cache.getOrPut(key) catch unreachable;
                if (!v.found_existing) {
                    v.value_ptr.* = ret;
                }
            }
            return ret;
        }
    }

    fn findPossibilities(springs: []const u8, groups: []const usize, allocator: std.mem.Allocator) usize {
        var cache = Cache.init(allocator);
        defer cache.deinit();
        return findPossibilitiesInternal(springs, 0, groups, 0, &cache);
    }

    test "findPossibilities - Normal" {
        try std.testing.expectEqual(1, findPossibilities("???.###", &.{ 1, 1, 3 }, std.testing.allocator));
        try std.testing.expectEqual(4, findPossibilities(".??..??...?##.", &.{ 1, 1, 3 }, std.testing.allocator));
        try std.testing.expectEqual(1, findPossibilities("?#?#?#?#?#?#?#?", &.{ 1, 3, 1, 6 }, std.testing.allocator));
        try std.testing.expectEqual(1, findPossibilities("????.#...#...", &.{ 4, 1, 1 }, std.testing.allocator));
        try std.testing.expectEqual(4, findPossibilities("????.######..#####.", &.{ 1, 6, 5 }, std.testing.allocator));
        try std.testing.expectEqual(10, findPossibilities("?###????????", &.{ 3, 2, 1 }, std.testing.allocator));
    }

    test "findPossibilities - Folded" {
        var data = try parseLine("???.### 1,1,3", true);
        try std.testing.expectEqual(1, findPossibilities(data.spring_str.slice(), data.group_sizes.slice(), std.testing.allocator));

        data = try parseLine(".??..??...?##. 1,1,3", true);
        try std.testing.expectEqual(16384, findPossibilities(data.spring_str.slice(), data.group_sizes.slice(), std.testing.allocator));

        data = try parseLine("?#?#?#?#?#?#?#? 1,3,1,6", true);
        try std.testing.expectEqual(1, findPossibilities(data.spring_str.slice(), data.group_sizes.slice(), std.testing.allocator));

        data = try parseLine("????.#...#... 4,1,1", true);
        try std.testing.expectEqual(16, findPossibilities(data.spring_str.slice(), data.group_sizes.slice(), std.testing.allocator));

        data = try parseLine("????.######..#####. 1,6,5", true);
        try std.testing.expectEqual(2500, findPossibilities(data.spring_str.slice(), data.group_sizes.slice(), std.testing.allocator));

        data = try parseLine("?###???????? 3,2,1", true);
        try std.testing.expectEqual(506250, findPossibilities(data.spring_str.slice(), data.group_sizes.slice(), std.testing.allocator));
    }

    fn calculateAnswer(allocator: std.mem.Allocator) ![2]usize {
        var answer1: usize = 0;
        var answer2: usize = 0;

        var file_line_reader = try helpers.FileLineReader.fromAdventDay(12, allocator);
        defer file_line_reader.deinit();
        while (file_line_reader.next()) |line| {
            const spring_data = try parseLine(line, false);
            answer1 += findPossibilities(spring_data.spring_str.slice(), spring_data.group_sizes.slice(), allocator);
            const spring_data_folded = try parseLine(line, true);
            answer2 += findPossibilities(spring_data_folded.spring_str.slice(), spring_data_folded.group_sizes.slice(), allocator);
            answer2 += 0;
        }

        return .{ answer1, answer2 };
    }
};

const iterative_method = struct {
    const InnerGroupsLengthArray = std.BoundedArray(usize, 40);
    const OuterTrackingArray = std.BoundedArray(InnerGroupsLengthArray, 120);

    fn findPossibilitiesInner(springs: []const u8, spring_idx: usize, groups: []const usize, group_idx: usize, tracking_arr: *OuterTrackingArray) usize {

        // End conditions:
        if (group_idx >= groups.len) {
            // No more groups
            if (spring_idx >= springs.len) {
                // Also no more springs, valid
                return 1;
            } else {
                // If more springs, but all '.' or '?', valid, else invalid
                return if (std.mem.indexOfScalar(u8, springs[spring_idx..], '#')) |_| 0 else 1;
            }
        } else if (springs[spring_idx..].len < groups[group_idx]) {
            // Less springs than required group, invalid
            return 0;
        }

        if (springs[spring_idx] == '.') {
            // Skip to next character
            return tracking_arr.*.slice()[spring_idx + 1].slice()[group_idx];
        } else {
            const is_valid = v: {
                // Can't have any '.' within a group
                if (std.mem.indexOfScalar(u8, springs[spring_idx .. spring_idx + groups[group_idx]], '.')) |_| break :v false;

                // Last character can not be '#'
                if (springs[spring_idx..].len > groups[group_idx]) {
                    if (springs[spring_idx + groups[group_idx]] == '#') {
                        break :v false;
                    }
                } else {
                    // Special case where we exhausted springs so can immediately determine if this is a valid sequence
                    if ((groups.len - group_idx) > 1) return 0 else return 1;
                }

                break :v true;
            };
            var ret: usize = 0;

            if (is_valid) {
                if (springs[spring_idx] == '?') {
                    // Try both paths, ? is a # and thus valid group, or a . and skip to next char
                    ret =
                        tracking_arr.*.slice()[spring_idx + 1].slice()[group_idx] + tracking_arr.*.slice()[spring_idx + groups[group_idx] + 1].slice()[group_idx + 1];
                } else {
                    // Continue on since this group must go here
                    ret = tracking_arr.*.slice()[spring_idx + groups[group_idx] + 1].slice()[group_idx + 1];
                }
            } else if (springs[spring_idx] == '#') {
                // If group is invalid but the first char is # then this combo can't be valid
                ret = 0;
            } else {
                // Still a chance this group could be valid, continue
                ret = tracking_arr.*.slice()[spring_idx + 1].slice()[group_idx];
            }

            return ret;
        }
    }

    fn findPossibilities(springs: []const u8, groups: []const usize) usize {

        // Bounds:
        //     spring_idx: 0 -> springs.len
        //     group_idx:  0 -> groups.len
        // Order:
        //     spring_idx, group_idx requires:
        //
        var tracking_arr = OuterTrackingArray.init(springs.len + 1) catch unreachable;
        for (tracking_arr.slice()) |*inner| {
            inner.* = InnerGroupsLengthArray.init(groups.len + 1) catch unreachable;
        }

        for (0..springs.len + 1) |outer_idx| {
            const spring_idx = springs.len - outer_idx;
            for (0..groups.len + 1) |inner_idx| {
                const group_idx = groups.len - inner_idx;
                tracking_arr.slice()[spring_idx].slice()[group_idx] = findPossibilitiesInner(springs, spring_idx, groups, group_idx, &tracking_arr);
            }
        }
        return tracking_arr.slice()[0].slice()[0];
    }

    test "findPossibilities - Normal" {
        try std.testing.expectEqual(1, findPossibilities("???.###", &.{ 1, 1, 3 }));
        try std.testing.expectEqual(4, findPossibilities(".??..??...?##.", &.{ 1, 1, 3 }));
        try std.testing.expectEqual(1, findPossibilities("?#?#?#?#?#?#?#?", &.{ 1, 3, 1, 6 }));
        try std.testing.expectEqual(1, findPossibilities("????.#...#...", &.{ 4, 1, 1 }));
        try std.testing.expectEqual(4, findPossibilities("????.######..#####.", &.{ 1, 6, 5 }));
        try std.testing.expectEqual(10, findPossibilities("?###????????", &.{ 3, 2, 1 }));
    }

    test "findPossibilities - Folded" {
        var data = try parseLine("???.### 1,1,3", true);
        try std.testing.expectEqual(1, findPossibilities(data.spring_str.slice(), data.group_sizes.slice()));

        data = try parseLine(".??..??...?##. 1,1,3", true);
        try std.testing.expectEqual(16384, findPossibilities(data.spring_str.slice(), data.group_sizes.slice()));

        data = try parseLine("?#?#?#?#?#?#?#? 1,3,1,6", true);
        try std.testing.expectEqual(1, findPossibilities(data.spring_str.slice(), data.group_sizes.slice()));

        data = try parseLine("????.#...#... 4,1,1", true);
        try std.testing.expectEqual(16, findPossibilities(data.spring_str.slice(), data.group_sizes.slice()));

        data = try parseLine("????.######..#####. 1,6,5", true);
        try std.testing.expectEqual(2500, findPossibilities(data.spring_str.slice(), data.group_sizes.slice()));

        data = try parseLine("?###???????? 3,2,1", true);
        try std.testing.expectEqual(506250, findPossibilities(data.spring_str.slice(), data.group_sizes.slice()));
    }

    fn calculateAnswer() ![2]usize {
        var answer1: usize = 0;
        var answer2: usize = 0;

        var file_line_reader = try helpers.FixedBufferLineReader(60).fromAdventDay(12);
        defer file_line_reader.deinit();
        while (file_line_reader.next()) |line| {
            const spring_data = try parseLine(line, false);
            answer1 += findPossibilities(spring_data.spring_str.slice(), spring_data.group_sizes.slice());
            const spring_data_folded = try parseLine(line, true);
            answer2 += findPossibilities(spring_data_folded.spring_str.slice(), spring_data_folded.group_sizes.slice());
            answer2 += 0;
        }

        return .{ answer1, answer2 };
    }
};

pub fn main() !void {
    const answer = try iterative_method.calculateAnswer();
    std.log.info("Answer part 1: {d}", .{answer[0]});
    std.log.info("Answer part 2: {?}", .{answer[1]});
}

comptime {
    std.testing.refAllDecls(iterative_method);
    std.testing.refAllDecls(cache_method);
}
