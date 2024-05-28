const std = @import("std");
const helpers = @import("helpers");
const FileLineReader = helpers.FileLineReader;
const GeneralErrors = helpers.GeneralErrors;
const DaySpecificErrors = error{NoPathFound};

const UniverseMatrix = std.ArrayList(std.ArrayList(u8));

const Expansions = struct {
    rows: []const usize,
    cols: []const usize,
    expansion_factor: isize,
};

fn expandUniverse(allocator: std.mem.Allocator, matrix: UniverseMatrix, expansion_factor: isize) !Expansions {

    // Tracking array for if a column is all "."
    var expandable_column_indices = std.ArrayList(usize).init(allocator);
    defer expandable_column_indices.deinit();

    // We will "remove" invalid columns as we find them
    for (0..matrix.items.len) |i| {
        try expandable_column_indices.append(i);
    }

    // Tracking array for if a row is all "."
    var expandable_row_indices = std.ArrayList(usize).init(allocator);
    defer expandable_row_indices.deinit();

    for (matrix.items, 0..) |row, row_idx| {
        var empty_row = true;
        for (row.items, 0..) |char, col_idx| {
            if (char != '.') {
                empty_row = false;
                if (std.mem.indexOfScalar(usize, expandable_column_indices.items, col_idx)) |col_to_remove| {
                    _ = expandable_column_indices.orderedRemove(col_to_remove);
                }
            }
        }
        if (empty_row) try expandable_row_indices.append(row_idx);
    }

    return .{ .rows = try expandable_row_indices.toOwnedSlice(), .cols = try expandable_column_indices.toOwnedSlice(), .expansion_factor = expansion_factor };
}

const Coord = struct {
    x: isize,
    y: isize,

    pub fn addDir(self: Coord, dir: Dir) Coord {
        return .{ .x = self.x + dir.x, .y = self.y + dir.y };
    }

    pub fn eql(self: Coord, other: Coord) bool {
        return (self.x == other.x) and (self.y == other.y);
    }

    pub fn adjustGivenExpansions(self: *Coord, expansions: Expansions) void {
        const init_x: isize = self.x;
        const init_y: isize = self.y;
        for (expansions.cols) |x| {
            if (init_x > x) self.x += expansions.expansion_factor - 1;
        }
        for (expansions.rows) |y| {
            if (init_y > y) self.y += expansions.expansion_factor - 1;
        }
    }
};

const CoordPair = struct {
    first: Coord,
    second: Coord,

    pub fn eql(self: CoordPair, other: CoordPair) bool {
        return (self.first.eql(other.first) and self.second.eql(other.second)) or (self.first.eql(other.second) and self.second.eql(other.first));
    }

    pub fn isIn(self: CoordPair, slice: []const CoordPair) bool {
        for (slice) |other| {
            if (self.eql(other)) return true;
        }
        return false;
    }
};

test "Adjust coordinate given expansions" {
    const expansions: Expansions = .{ .rows = &.{ 3, 7 }, .cols = &.{ 2, 5, 8 }, .expansion_factor = 2 };

    var coord: Coord = .{ .x = 0, .y = 0 };
    coord.adjustGivenExpansions(expansions);
    try std.testing.expectEqual(Coord{ .x = 0, .y = 0 }, coord);

    coord = .{ .x = 3, .y = 0 };
    coord.adjustGivenExpansions(expansions);
    try std.testing.expectEqual(Coord{ .x = 4, .y = 0 }, coord);
}

const Dir = struct { x: isize, y: isize };

const DIRECTIONS: []const Dir = &.{
    .{ .x = 0, .y = -1 },
    .{ .x = 0, .y = 1 },
    .{ .x = -1, .y = 0 },
    .{ .x = 1, .y = 0 },
};

fn fallsWithinLine(coord: Coord, pair: CoordPair) bool {

    // Special case for a vertical line
    if (pair.first.x == pair.second.x) {
        return coord.x == pair.first.x;
    }
    // Calculate the equation for the line that connects two points, and bound results to within +/- 1 from this line
    const m: f32 = @as(f32, @floatFromInt(pair.first.y - pair.second.y)) / @as(f32, @floatFromInt(pair.first.x - pair.second.x));
    const b: f32 = @as(f32, @floatFromInt(pair.first.y)) - @as(f32, @floatFromInt(pair.first.x)) * m;

    if (@abs(m) > 1.0) {
        const x_from_eq = @as(isize, @intFromFloat((@as(f32, @floatFromInt(coord.y)) - b) / m));
        return !((coord.x > x_from_eq + 2) or (coord.x < x_from_eq - 2));
    } else {
        const y_from_eq = @as(isize, @intFromFloat(@as(f32, @floatFromInt(coord.x)) * m + b));
        return !((coord.y > y_from_eq + 2) or (coord.y < y_from_eq - 2));
    }
}

test "fallsWithinLine" {
    try std.testing.expectEqual(true, fallsWithinLine(.{ .x = 0, .y = 0 }, .{ .first = .{ .x = 0, .y = 0 }, .second = .{ .x = 2, .y = 2 } }));
    try std.testing.expectEqual(false, fallsWithinLine(.{ .x = 8, .y = 0 }, .{ .first = .{ .x = 0, .y = 0 }, .second = .{ .x = 2, .y = 2 } }));

    // Spicier cases

    // Horizontal line
    try std.testing.expectEqual(true, fallsWithinLine(.{ .x = 8, .y = 0 }, .{ .first = .{ .x = 0, .y = 0 }, .second = .{ .x = 10, .y = 0 } }));
    try std.testing.expectEqual(false, fallsWithinLine(.{ .x = 8, .y = 3 }, .{ .first = .{ .x = 0, .y = 0 }, .second = .{ .x = 10, .y = 0 } }));

    // Vertical line
    try std.testing.expectEqual(true, fallsWithinLine(.{ .x = 0, .y = 5 }, .{ .first = .{ .x = 0, .y = 0 }, .second = .{ .x = 0, .y = 10 } }));
    try std.testing.expectEqual(false, fallsWithinLine(.{ .x = 1, .y = 5 }, .{ .first = .{ .x = 0, .y = 0 }, .second = .{ .x = 0, .y = 10 } }));
}

fn shouldVisit(coord: Coord, visited: []const Coord, max_coord: Coord, pair: CoordPair) bool {

    // Bounds check
    if ((coord.x < 0) or (coord.y < 0)) {
        return false;
    }
    if ((coord.x > max_coord.x) or (coord.y > max_coord.y)) {
        return false;
    }

    // Already visited
    for (visited) |vc| {
        if (coord.eql(vc)) return false;
    }

    // Our own constraints to reduce CPU time
    return fallsWithinLine(coord, pair);
}

fn universeSet(allocator: std.mem.Allocator, matrix: UniverseMatrix, expansions: Expansions) ![]const CoordPair {
    var universe_coords = std.ArrayList(Coord).init(allocator);
    defer universe_coords.deinit();
    for (matrix.items, 0..) |row, y| {
        for (row.items, 0..) |char, x| {
            if (char == '#') {
                var coord_to_append: Coord = .{ .x = @intCast(x), .y = @intCast(y) };
                coord_to_append.adjustGivenExpansions(expansions);
                try universe_coords.append(coord_to_append);
            }
        }
    }

    var universe_sets = std.ArrayList(CoordPair).init(allocator);
    defer universe_sets.deinit();

    for (universe_coords.items) |item1| {
        for (universe_coords.items) |item2| {
            if (!item1.eql(item2)) {
                const pair: CoordPair = .{ .first = item1, .second = item2 };
                if (!pair.isIn(universe_sets.items)) {
                    try universe_sets.append(pair);
                }
            }
        }
    }

    return try universe_sets.toOwnedSlice();
}

/// Calculates the shortest path between two points given
/// you can only move in whole integer steps:
/// https://en.wikipedia.org/wiki/Taxicab_geometry
fn manhattanDistance(pair: CoordPair) usize {
    return @intCast(@abs(pair.second.x - pair.first.x) + @abs(pair.second.y - pair.first.y));
}

test "Example Input 1" {
    var flr_input = try FileLineReader.init(std.testing.allocator, "test_inputs/day11_input_test1.txt");
    defer flr_input.deinit();

    var universe_matrix = try flr_input.collect();
    defer {
        for (universe_matrix.items) |row| {
            row.deinit();
        }
        universe_matrix.deinit();
    }

    // Universe expansion
    const expansions = try expandUniverse(std.testing.allocator, universe_matrix, 2);
    defer {
        std.testing.allocator.free(expansions.cols);
        std.testing.allocator.free(expansions.rows);
    }
    try std.testing.expectEqualSlices(usize, &.{ 3, 7 }, expansions.rows);
    try std.testing.expectEqualSlices(usize, &.{ 2, 5, 8 }, expansions.cols);

    // Testing the 3 given examples

    // Between galaxy 1 and galaxy 7: 15
    const shortest_path_1_to_7 = manhattanDistance(.{ .first = .{ .x = 4, .y = 0 }, .second = .{ .x = 9, .y = 10 } });
    try std.testing.expectEqual(15, shortest_path_1_to_7);

    // Between galaxy 3 and galaxy 6: 17
    const shortest_path_3_to_6 = manhattanDistance(.{ .first = .{ .x = 0, .y = 2 }, .second = .{ .x = 12, .y = 7 } });
    try std.testing.expectEqual(17, shortest_path_3_to_6);

    // Between galaxy 8 and galaxy 9: 5
    const shortest_path_8_to_9 = manhattanDistance(.{ .first = .{ .x = 0, .y = 11 }, .second = .{ .x = 5, .y = 11 } });
    try std.testing.expectEqual(5, shortest_path_8_to_9);

    // All pairs from example file
    const pairs = try universeSet(std.testing.allocator, universe_matrix, expansions);
    defer std.testing.allocator.free(pairs);
    var sum_of_pairs: usize = 0;
    for (pairs) |pair| {
        sum_of_pairs += manhattanDistance(pair);
    }
    try std.testing.expectEqual(374, sum_of_pairs);
}

fn calculateAnswer(allocator: std.mem.Allocator) ![2]usize {
    var answer1: usize = 0;
    var answer2: usize = 0;

    std.debug.print("Reading universe\n", .{});
    var flr = try helpers.lineReaderFromAdventDay(11, allocator);
    defer flr.deinit();
    var universe_matrix = try flr.collect();
    defer {
        for (universe_matrix.items) |row| {
            row.deinit();
        }
        universe_matrix.deinit();
    }

    const expansion_factors: []const isize = &.{ 2, 1000000 };
    for (expansion_factors) |exp_fct| {
        std.debug.print("Expanding universe\n", .{});
        const expansions = try expandUniverse(allocator, universe_matrix, exp_fct);
        defer {
            allocator.free(expansions.cols);
            allocator.free(expansions.rows);
        }

        std.debug.print("Getting sets of pairs\n", .{});
        const pairs = try universeSet(allocator, universe_matrix, expansions);
        defer allocator.free(pairs);
        const max_x = @as(isize, @intCast(universe_matrix.items[0].items.len - 1));
        const max_y = @as(isize, @intCast(universe_matrix.items.len - 1));
        var max_coord: Coord = .{ .x = max_x, .y = max_y };
        max_coord.adjustGivenExpansions(expansions);

        var sum_of_pairs: usize = 0;
        std.debug.print("Finding shortest paths\n", .{});
        for (pairs) |pair| {
            sum_of_pairs += manhattanDistance(pair);
        }
        if (exp_fct > 1) {
            answer2 = sum_of_pairs;
        } else {
            answer1 = sum_of_pairs;
        }
    }

    return .{ answer1, answer2 };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const answer = try calculateAnswer(alloc);
    std.debug.print("Answer part 1: {d}\n", .{answer[0]});
    std.debug.print("Answer part 2: {?}\n", .{answer[1]});
    std.debug.assert(!gpa.detectLeaks());
}
