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

// Building our own hasher... YAY!
//
//
//

const CacheKey = struct {
    springs: []const u8,
    groups: []const usize,
};

const CacheContext = struct {
    pub fn hash(_: CacheContext, key: CacheKey) u64 {
        var hasher = std.hash.Wyhash.init(0);
        std.hash.autoHashStrat(&hasher, key, .Deep);
        // hasher.update(key.springs);
        // hasher.update(std.mem.sliceAsBytes(key.groups));
        return hasher.final();
    }

    pub fn eql(_: CacheContext, a: CacheKey, b: CacheKey) bool {
        return std.mem.eql(u8, a.springs, b.springs) and std.mem.eql(usize, a.groups, b.groups);
    }
};

const Cache = std.HashMap(CacheKey, usize, CacheContext, std.hash_map.default_max_load_percentage);

test "Cache HashMap" {
    var hash_map = Cache.init(std.testing.allocator);
    defer hash_map.deinit();
    const dummy_key: CacheKey = .{ .springs = "..##..", .groups = &.{ 1, 2, 3 } };

    try hash_map.put(dummy_key, 100);
    try std.testing.expectEqual(100, hash_map.get(dummy_key).?);
    try std.testing.expectEqual(null, hash_map.get(.{ .springs = "...", .groups = &.{ 1, 2, 3 } }));
}

var cache: Cache = undefined;

fn findPossibilities(springs: []const u8, groups: []const usize) usize {

    // End conditions:
    if (groups.len == 0) {
        // No more groups
        if (springs.len == 0) {
            // Also no more springs, valid
            return 1;
        } else {
            // If more springs, but all '.' or '?', valid, else invalid
            return if (std.mem.indexOfScalar(u8, springs, '#')) |_| 0 else 1;
        }
    } else if (springs.len < groups[0]) {
        // Less springs than required group, invalid
        return 0;
    }

    if (springs[0] == '.') {
        // Skip to next character
        return findPossibilities(springs[1..], groups);
    } else {
        const is_valid = v: {
            // Can't have any '.' within a group
            if (std.mem.indexOfScalar(u8, springs[0..groups[0]], '.')) |_| break :v false;

            // Last character can not be '#'
            if (springs.len > groups[0]) {
                if (springs[groups[0]] == '#') {
                    break :v false;
                }
            } else {
                // Special case where we exhausted springs so can immediately determine if this is a valid sequence
                if (groups.len > 1) return 0 else return 1;
            }

            break :v true;
        };
        var ret: usize = 0;
        const key: CacheKey = .{ .springs = springs, .groups = groups };
        if (cache.get(key)) |v| {
            ret = v;
        } else {
            if (is_valid) {
                if (springs[0] == '?') {
                    // Try both paths, ? is a # and thus valid group, or a . and skip to next char
                    ret = findPossibilities(springs[1..], groups) + findPossibilities(springs[groups[0] + 1 ..], groups[1..]);
                } else {
                    // Continue on since this group must go here
                    ret = findPossibilities(springs[groups[0] + 1 ..], groups[1..]);
                }
            } else if (springs[0] == '#') {
                // If group is invalid but the first char is # then this combo can't be valid
                ret = 0;
            } else {
                // Still a chance this group could be valid, continue
                ret = findPossibilities(springs[1..], groups);
            }
            const v = cache.getOrPut(key) catch unreachable;
            if (!v.found_existing) {
                v.value_ptr.* = ret;
            }
        }
        return ret;
    }
}

test "findPossibilities - Normal" {
    cache = Cache.init(std.testing.allocator);
    defer cache.deinit();
    try std.testing.expectEqual(1, findPossibilities("???.###", &.{ 1, 1, 3 }));
    try std.testing.expectEqual(4, findPossibilities(".??..??...?##.", &.{ 1, 1, 3 }));
    try std.testing.expectEqual(1, findPossibilities("?#?#?#?#?#?#?#?", &.{ 1, 3, 1, 6 }));
    try std.testing.expectEqual(1, findPossibilities("????.#...#...", &.{ 4, 1, 1 }));
    try std.testing.expectEqual(4, findPossibilities("????.######..#####.", &.{ 1, 6, 5 }));
    try std.testing.expectEqual(10, findPossibilities("?###????????", &.{ 3, 2, 1 }));
}

test "findPossibilities - Folded" {
    cache = Cache.init(std.testing.allocator);
    defer cache.deinit();
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

fn calculateAnswer(allocator: std.mem.Allocator) ![2]usize {
    var answer1: usize = 0;
    var answer2: usize = 0;

    var file_line_reader = try helpers.lineReaderFromAdventDay(12, allocator);
    defer file_line_reader.deinit();
    while (file_line_reader.next()) |line| {
        cache = Cache.init(allocator);
        defer cache.deinit();
        const spring_data = try parseLine(line, false);
        answer1 += findPossibilities(spring_data.spring_str.slice(), spring_data.group_sizes.slice());
        const spring_data_folded = try parseLine(line, true);
        answer2 += findPossibilities(spring_data_folded.spring_str.slice(), spring_data_folded.group_sizes.slice());
        answer2 += 0;
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
