const std = @import("std");
const helpers = @import("helpers");
const GeneralErrors = helpers.GeneralErrors;

pub const std_options: std.Options = .{
    .log_level = .info,
};

const RaceInfo = struct {
    time: u64,
    record: u64,

    pub fn winPossibilities(self: RaceInfo) u64 {

        // Equation:
        //     x = time held down
        //     distance_moved = (time - x)*x
        var ways_to_win: u64 = 0;
        for (1..(self.time - 1)) |held_time| {
            if (((self.time - held_time) * held_time) > self.record) {
                ways_to_win += 1;
            }
        }
        return ways_to_win;
    }
};

fn raceInfo() ![4]RaceInfo {
    var file_line_reader = try helpers.FixedBufferLineReader(50).fromAdventDay(6);
    defer file_line_reader.deinit();

    var race_info_arr: [4]RaceInfo = undefined;

    for (0..2) |i| {
        if (file_line_reader.next()) |line| {
            var num_iter = std.mem.tokenizeAny(u8, line, " ");
            _ = num_iter.next() orelse {
                return GeneralErrors.UnexpectedFormat;
            };
            var val_idx: usize = 0;
            while (num_iter.next()) |num_str| {
                if (val_idx >= race_info_arr.len) {
                    return GeneralErrors.UnexpectedFormat;
                }
                if (i == 0) {
                    race_info_arr[val_idx].time = try std.fmt.parseInt(u64, num_str, 10);
                } else {
                    race_info_arr[val_idx].record = try std.fmt.parseInt(u64, num_str, 10);
                }
                val_idx += 1;
            }
        } else {
            return GeneralErrors.UnexpectedFormat;
        }
    }
    return race_info_arr;
}

fn raceInfoPart2() !RaceInfo {
    var file_line_reader = try helpers.FixedBufferLineReader(50).fromAdventDay(6);
    defer file_line_reader.deinit();

    var race_info = RaceInfo{ .record = 0, .time = 0 };
    for (0..2) |i| {
        if (file_line_reader.next()) |line| {
            var split_it = std.mem.splitScalar(u8, line, ':');
            _ = split_it.next() orelse {
                return GeneralErrors.UnexpectedFormat;
            };
            const nums = split_it.next() orelse {
                return GeneralErrors.UnexpectedFormat;
            };

            var temp_num_storage = try std.BoundedArray(u8, 100).init(0);
            var num_tok = std.mem.tokenizeAny(u8, nums, " ");
            while (num_tok.next()) |num_str| {
                try temp_num_storage.appendSlice(num_str);
            }
            const new_num: u64 = try std.fmt.parseInt(u64, temp_num_storage.slice(), 10);
            if (i == 0) {
                race_info.time = new_num;
            } else {
                race_info.record = new_num;
            }
        } else {
            return GeneralErrors.UnexpectedFormat;
        }
    }
    return race_info;
}

fn calculateAnswer() !u64 {
    const race_info_arr = try raceInfo();
    var final_answer: ?u64 = null;

    for (race_info_arr) |info| {
        const ways_to_win = info.winPossibilities();
        if (final_answer) |ans| {
            final_answer = ans * ways_to_win;
        } else {
            final_answer = ways_to_win;
        }
    }

    return final_answer orelse GeneralErrors.UnexpectedFormat;
}

pub fn main() !void {
    const answer = try calculateAnswer();
    std.log.info("Answer part 1: {d}", .{answer});
    const diff_ri = try raceInfoPart2();
    std.log.info("Answer part 2: {d}", .{diff_ri.winPossibilities()});
}
