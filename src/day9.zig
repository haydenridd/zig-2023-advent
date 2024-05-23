const std = @import("std");
const helpers = @import("helpers");
const FileLineReader = helpers.FileLineReader;
const MyErrors = helpers.MyErrors;

fn nextDataVector(line_reader: *FileLineReader) ?[]i64 {
    const ln = line_reader.next() orelse return null;
    var ret_arr = std.ArrayList(i64).init(line_reader.allocator);
    defer ret_arr.deinit();
    var nm_tok = std.mem.tokenizeAny(u8, ln, " ");
    while (nm_tok.next()) |num_str| {
        ret_arr.append(std.fmt.parseInt(i64, num_str, 10) catch unreachable) catch unreachable;
    }
    return ret_arr.toOwnedSlice() catch unreachable;
}

fn calculateAnswer(allocator: std.mem.Allocator) ![2]i64 {
    const debug_print = false;
    const limit_output = false;

    var file_line_reader = try helpers.lineReaderFromAdventDay(9, allocator);
    defer file_line_reader.deinit();
    var answer: i64 = 0;
    var answer2: i64 = 0;
    var tmp: usize = 0;
    while (nextDataVector(&file_line_reader)) |data_vec| {
        defer allocator.free(data_vec);

        var init_values = try std.BoundedArray(i64, 50).init(0);
        try init_values.appendSlice(data_vec);

        // Keep track of derivative start/end points
        var deriv_points = try std.BoundedArray([2]i64, 50).init(0);

        var differoni = data_vec;
        if (debug_print) std.debug.print("Orig: {any}\n", .{differoni});
        while (!std.mem.allEqual(i64, differoni, 0)) {
            std.mem.reverse(i64, differoni);
            for (0.., 1..differoni.len) |t1_idx, t0_idx| {
                differoni[t1_idx] = differoni[t1_idx] - differoni[t0_idx];
            }
            std.mem.reverse(i64, differoni);
            differoni = differoni[1..];
            if (debug_print) std.debug.print("Diff: {any}\n", .{differoni});
            try deriv_points.append(.{ differoni[0], differoni[differoni.len - 1] });
        }

        var new_end_val: i64 = 0;
        var new_start_val: i64 = 0;

        while (deriv_points.len > 0) {
            const dpts = deriv_points.swapRemove(deriv_points.len - 1);
            new_end_val += dpts[1];
            new_start_val = dpts[0] - new_start_val;
            if (debug_print) std.debug.print("Diff pt: {any}, start_sum: {d}, end_sum: {d}\n", .{ dpts, new_start_val, new_end_val });
        }
        new_end_val = init_values.slice()[init_values.len - 1] + new_end_val;
        new_start_val = init_values.slice()[0] - new_start_val;
        if (debug_print) {
            try init_values.append(new_end_val);
            if (debug_print) std.debug.print("Part1 seq adj is: {any}\n", .{init_values.slice()});
            try init_values.insert(0, new_start_val);
            if (debug_print) std.debug.print("Part2 seq adj is: {any}\n", .{init_values.slice()[0 .. init_values.len - 1]});
        }
        answer += new_end_val;
        answer2 += new_start_val;
        tmp += 1;
        if ((tmp > 3) and limit_output) break;
    }
    return .{ answer, answer2 };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const answer = try calculateAnswer(alloc);
    std.debug.print("Answer part 1: {d}\n", .{answer[0]});
    std.debug.print("Answer part 2: {?}\n", .{answer[1]});
    std.debug.assert(!gpa.detectLeaks());
}
