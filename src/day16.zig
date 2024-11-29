const std = @import("std");
const helpers = @import("helpers");
const GeneralErrors = helpers.GeneralErrors;

pub const std_options: std.Options = .{
    .log_level = .info,
};

const DaySpecificErrors = error{Something};
const assert = std.debug.assert;

const part1 = struct {
    const Direction = enum { R, L, U, D };
    const Position = struct { row: usize, col: usize };

    /// See if a movement would throw out of bounds
    fn boundsCheck(pos: Position, dir: Direction, map: []const []u8) bool {
        switch (dir) {
            .R => return pos.col == map[0].len - 1,
            .L => return pos.col == 0,
            .U => return pos.row == 0,
            .D => return pos.row == map.len - 1,
        }
    }

    fn newPosFromMovementDir(pos: Position, dir: Direction) Position {
        switch (dir) {
            .R => return .{
                .row = pos.row,
                .col = pos.col + 1,
            },
            .L => return .{
                .row = pos.row,
                .col = pos.col - 1,
            },
            .U => return .{
                .row = pos.row - 1,
                .col = pos.col,
            },
            .D => return .{
                .row = pos.row + 1,
                .col = pos.col,
            },
        }
    }

    fn traverse(map: []const []u8, start_pos: Position, start_dir: Direction) !usize {
        const BackTrack = struct {
            position: Position,
            direction: Direction,
        };
        var backtrack = try std.BoundedArray(BackTrack, 10000).init(0);
        var executed_backtracks = try std.BoundedArray(BackTrack, 10000).init(0);
        var energized_positions = try std.BoundedArray(Position, 10000).init(0);

        var pos: Position = start_pos;
        var dir: Direction = start_dir;

        wl: while (true) {
            const chr = map[pos.row][pos.col];
            // std.debug.print("Char: {c} Pos: {d},{d} Dir: {s}\n", .{ chr, pos.row, pos.col, @tagName(dir) });
            // std.time.sleep(std.time.ns_per_ms * 500);

            const in_epos = v: {
                for (energized_positions.constSlice()) |epos| {
                    if ((pos.row == epos.row) and (pos.col == epos.col)) break :v true;
                }
                break :v false;
            };
            if (!in_epos) {
                try energized_positions.append(pos);
            }

            switch (chr) {
                '.', '<', '>', '^', 'v' => {
                    // map[pos.row][pos.col] = switch (dir) {
                    //     .U => '^',
                    //     .D => 'v',
                    //     .L => '<',
                    //     .R => '>',
                    // };
                    if (!boundsCheck(pos, dir, map)) {
                        pos = newPosFromMovementDir(pos, dir);
                        continue :wl;
                    }
                    // BREAK FROM SWITCH AND START ON BACKTRACK
                },
                '|' => {
                    switch (dir) {
                        .R, .L => {

                            // See if Down is valid and can be added to backtrack
                            if (pos.row < map.len - 1) {
                                const in_bt = v: {
                                    for (executed_backtracks.constSlice()) |itm| {
                                        if ((itm.direction == .D) and (itm.position.row == pos.row + 1) and (itm.position.col == pos.col)) break :v true;
                                    }
                                    break :v false;
                                };

                                if (!in_bt) {
                                    try executed_backtracks.append(.{ .position = .{
                                        .row = pos.row + 1,
                                        .col = pos.col,
                                    }, .direction = .D });
                                    try backtrack.append(.{ .position = .{
                                        .row = pos.row + 1,
                                        .col = pos.col,
                                    }, .direction = .D });
                                }
                            }

                            // See if Up is a valid case to continue
                            if (pos.row > 0) {
                                pos = .{
                                    .row = pos.row - 1,
                                    .col = pos.col,
                                };
                                dir = .U;
                                continue :wl;
                            }
                            // BREAK FROM SWITCH AND START ON BACKTRACK
                        },
                        .U, .D => {
                            if (!boundsCheck(pos, dir, map)) {
                                pos = newPosFromMovementDir(pos, dir);
                                continue :wl;
                            }
                            // BREAK FROM SWITCH AND START ON BACKTRACK
                        },
                    }
                },
                '-' => {
                    switch (dir) {
                        .R, .L => {
                            if (!boundsCheck(pos, dir, map)) {
                                pos = newPosFromMovementDir(pos, dir);
                                continue :wl;
                            }
                            // BREAK FROM SWITCH AND START ON BACKTRACK
                        },
                        .U, .D => {
                            // See if Right is valid and can be added to backtrack
                            if (pos.col < map[0].len - 1) {
                                const in_bt = v: {
                                    for (executed_backtracks.constSlice()) |itm| {
                                        if ((itm.direction == .R) and (itm.position.row == pos.row) and (itm.position.col == pos.col + 1)) break :v true;
                                    }
                                    break :v false;
                                };
                                if (!in_bt) {
                                    try executed_backtracks.append(.{ .position = .{
                                        .row = pos.row,
                                        .col = pos.col + 1,
                                    }, .direction = .R });
                                    try backtrack.append(.{ .position = .{
                                        .row = pos.row,
                                        .col = pos.col + 1,
                                    }, .direction = .R });
                                }
                            }

                            // See if Left is a valid case to continue
                            if (pos.col > 0) {
                                pos = .{
                                    .row = pos.row,
                                    .col = pos.col - 1,
                                };
                                dir = .L;
                                continue :wl;
                            }

                            // BREAK FROM SWITCH AND START ON BACKTRACK
                        },
                    }
                },
                '/' => {
                    switch (dir) {
                        .R => {
                            if (!boundsCheck(pos, .U, map)) {
                                dir = .U;
                                pos = newPosFromMovementDir(pos, dir);
                                continue :wl;
                            }
                        },
                        .L => {
                            if (!boundsCheck(pos, .D, map)) {
                                dir = .D;
                                pos = newPosFromMovementDir(pos, dir);
                                continue :wl;
                            }
                        },
                        .U => {
                            if (!boundsCheck(pos, .R, map)) {
                                dir = .R;
                                pos = newPosFromMovementDir(pos, dir);
                                continue :wl;
                            }
                        },
                        .D => {
                            if (!boundsCheck(pos, .L, map)) {
                                dir = .L;
                                pos = newPosFromMovementDir(pos, dir);
                                continue :wl;
                            }
                        },
                    }
                    // BREAK FROM SWITCH AND START ON BACKTRACK
                },
                '\\' => {
                    switch (dir) {
                        .R => {
                            if (!boundsCheck(pos, .D, map)) {
                                dir = .D;
                                pos = newPosFromMovementDir(pos, dir);
                                continue :wl;
                            }
                        },
                        .L => {
                            if (!boundsCheck(pos, .U, map)) {
                                dir = .U;
                                pos = newPosFromMovementDir(pos, dir);
                                continue :wl;
                            }
                        },
                        .U => {
                            if (!boundsCheck(pos, .L, map)) {
                                dir = .L;
                                pos = newPosFromMovementDir(pos, dir);
                                continue :wl;
                            }
                        },
                        .D => {
                            if (!boundsCheck(pos, .R, map)) {
                                dir = .R;
                                pos = newPosFromMovementDir(pos, dir);
                                continue :wl;
                            }
                        },
                    }
                    // BREAK FROM SWITCH AND START ON BACKTRACK
                },
                else => {
                    for (map) |ln| {
                        std.debug.print("{s}\n", .{ln});
                    }
                    std.debug.panic("Hit an unknown char: {d}", .{chr});
                },
            }

            // Nothing left to backtrack means we're done
            if (backtrack.len == 0) break :wl;

            const tmp = backtrack.pop();
            pos = tmp.position;
            dir = tmp.direction;
            // std.debug.print("BT: pos: {d},{d} dir: {s}\n", .{ pos.row, pos.col, @tagName(dir) });
        }

        return energized_positions.len;
    }

    fn fromStr(
        str: []const u8,
        ArrType: type,
    ) ArrType {
        var ret: ArrType = undefined;
        std.mem.copyForwards(u8, &ret, str);
        return ret;
    }

    test "part1" {
        var nla = helpers.NewLineArray(100, 100).fromTestInput(16);
        const ans = try traverse(nla.slice(), .{ .row = 0, .col = 0 }, .R);
        try std.testing.expectEqual(46, ans);
    }
};

const part2 = struct {
    fn maximizeTraversal(map: []const []u8) !usize {
        var energies = try std.BoundedArray(usize, 1000).init(0);

        // First row + Bottom row
        for (0..map[0].len) |start_col| {
            try energies.append(try part1.traverse(map, .{ .row = 0, .col = start_col }, .D));
            try energies.append(try part1.traverse(map, .{ .row = map.len - 1, .col = start_col }, .U));
        }

        // Left side + Right side
        for (0..map.len) |start_row| {
            try energies.append(try part1.traverse(map, .{ .row = start_row, .col = 0 }, .R));
            try energies.append(try part1.traverse(map, .{ .row = start_row, .col = map[0].len - 1 }, .L));
        }

        return std.mem.max(usize, energies.constSlice());
    }

    test "part2" {
        var nla = helpers.NewLineArray(100, 100).fromTestInput(16);
        const ans = try maximizeTraversal(nla.slice());
        try std.testing.expectEqual(51, ans);
    }
};

fn calculateAnswer() ![2]usize {
    var nla = helpers.NewLineArray(120, 120).fromAdventDay(16);
    const answer1: usize = try part1.traverse(nla.slice(), .{ .row = 0, .col = 0 }, .R);
    const answer2: usize = try part2.maximizeTraversal(nla.slice());
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
