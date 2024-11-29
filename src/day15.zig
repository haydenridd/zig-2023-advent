const std = @import("std");
const helpers = @import("helpers");
const GeneralErrors = helpers.GeneralErrors;

pub const std_options: std.Options = .{
    .log_level = .info,
};

const DaySpecificErrors = error{Something};
const assert = std.debug.assert;

const part1 = struct {
    fn hash(bytes: []const u8) usize {
        var ret: usize = 0;
        for (bytes) |b| {
            ret += b;
            ret *= 17;
            ret %= 256;
        }
        return ret;
    }

    test "hash" {
        try std.testing.expectEqual(52, hash("HASH"));
        try std.testing.expectEqual(30, hash("rn=1"));
    }

    fn answer(comptime use_test: bool) !usize {
        var fbcsv = if (use_test) try helpers.FixedBufferCSVReader(100).fromTestInput(15) else try helpers.FixedBufferCSVReader(100).fromAdventDay(15);
        defer fbcsv.deinit();
        var ans: usize = 0;
        while (fbcsv.next()) |ln| {
            const tmp = hash(ln);
            ans += tmp;
        }
        return ans;
    }

    test "part1" {
        try std.testing.expectEqual(1320, answer(true));
    }
};

const part2 = struct {
    const StringBuffer = [8]u8;
    fn fromStr(str: []const u8) StringBuffer {
        var ret: StringBuffer = .{0} ** 8;
        std.mem.copyForwards(u8, &ret, str);
        return ret;
    }

    const HashMap = std.AutoArrayHashMap(StringBuffer, u4);

    const Command = struct {
        label: []const u8,
        payload: union(enum) { remove: void, add: u4 },
    };

    fn parseCommand(cmd: []const u8) Command {
        if (std.mem.indexOfScalar(u8, cmd, '-')) |idx| {
            return .{
                .label = cmd[0..idx],
                .payload = .remove,
            };
        } else if (std.mem.indexOfScalar(u8, cmd, '=')) |idx| {
            return .{
                .label = cmd[0..idx],
                .payload = .{ .add = std.fmt.parseInt(u4, cmd[idx + 1 ..], 10) catch unreachable },
            };
        } else {
            std.debug.panic("Bad command: {s}", .{cmd});
        }
    }

    test "parseCommand" {
        try std.testing.expectEqualDeep(Command{
            .label = "cm",
            .payload = .remove,
        }, parseCommand("cm-"));

        try std.testing.expectEqualDeep(Command{
            .label = "qp",
            .payload = .{ .add = 3 },
        }, parseCommand("qp=3"));
    }

    fn answer(comptime use_test: bool, allocator: std.mem.Allocator) !usize {
        var hash_maps: [256]HashMap = undefined;
        for (&hash_maps) |*hm| {
            hm.* = HashMap.init(allocator);
        }

        var fbcsv = if (use_test) try helpers.FixedBufferCSVReader(100).fromTestInput(15) else try helpers.FixedBufferCSVReader(100).fromAdventDay(15);
        defer fbcsv.deinit();

        while (fbcsv.next()) |ln| {
            const cmd = parseCommand(ln);
            const tbl_idx = part1.hash(cmd.label);
            const key = fromStr(cmd.label);
            switch (cmd.payload) {
                .remove => {
                    _ = hash_maps[tbl_idx].orderedRemove(key);
                },
                .add => |v| {
                    try hash_maps[tbl_idx].put(key, v);
                },
            }
        }
        var ans: usize = 0;
        for (&hash_maps, 1..) |*hm, box_num| {
            for (hm.*.values(), 1..) |v, slot_num| {
                ans += @as(usize, v) * box_num * slot_num;
            }
            hm.*.deinit();
        }
        return ans;
    }

    test "part2" {
        try std.testing.expectEqual(145, try answer(true, std.testing.allocator));
    }
};

fn calculateAnswer() ![2]usize {
    const answer1: usize = try part1.answer(false);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const answer2: usize = try part2.answer(false, alloc);

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
