const std = @import("std");
const helpers = @import("helpers");
const FileLineReader = helpers.FileLineReader;
const MyErrors = helpers.MyErrors;

const Coordinate = struct { x: usize, y: usize };
const Direction = enum { N, E, S, W };

// zig fmt: off
const VALID_NORTH_MOVES = .{
    .{'|', '|'},
    .{'|', '7'},
    .{'|', 'F'},
    .{'L', '|'},
    .{'L', '7'},
    .{'L', 'F'},
    .{'J', '|'},
    .{'J', '7'},
    .{'J', 'F'},
    .{'S', '|'},
    .{'S', '7'},
    .{'S', 'F'},
};

const VALID_EAST_MOVES = .{
    .{'-', '-'},
    .{'-', '7'},
    .{'-', 'J'},
    .{'F', '-'},
    .{'F', '7'},
    .{'F', 'J'},
    .{'L', '-'},
    .{'L', '7'},
    .{'L', 'J'},
    .{'S', '-'},
    .{'S', '7'},
    .{'S', 'J'},
};

const VALID_SOUTH_MOVES = .{
    .{'|', '|'},
    .{'|', 'J'},
    .{'|', 'L'},
    .{'F', '|'},
    .{'F', 'J'},
    .{'F', 'L'},
    .{'7', '|'},
    .{'7', 'J'},
    .{'7', 'L'},
    .{'S', '|'},
    .{'S', 'J'},
    .{'S', 'L'},
};

const VALID_WEST_MOVES = .{
    .{'-', '-'},
    .{'-', 'F'},
    .{'-', 'L'},
    .{'J', '-'},
    .{'J', 'F'},
    .{'J', 'L'},
    .{'7', '-'},
    .{'7', 'F'},
    .{'7', 'L'},
    .{'S', '-'},
    .{'S', 'F'},
    .{'S', 'L'},
};
// zig fmt: on

fn validMovementDirection(curr: u8, next: u8, direction: Direction) bool {
    switch (direction) {
        .N => {
            inline for (VALID_NORTH_MOVES) |moveset| {
                if ((curr == moveset[0]) and (next == moveset[1])) return true;
            }
            return false;
        },
        .E => {
            inline for (VALID_EAST_MOVES) |moveset| {
                if ((curr == moveset[0]) and (next == moveset[1])) return true;
            }
            return false;
        },
        .S => {
            inline for (VALID_SOUTH_MOVES) |moveset| {
                if ((curr == moveset[0]) and (next == moveset[1])) return true;
            }
            return false;
        },
        .W => {
            inline for (VALID_WEST_MOVES) |moveset| {
                if ((curr == moveset[0]) and (next == moveset[1])) return true;
            }
            return false;
        },
    }
}

pub fn possibleMovementDirections(matrix: [][]const u8, location: Coordinate, previous_dir: ?Direction) !std.BoundedArray(Direction, 4) {
    var possible_directions = try std.BoundedArray(Direction, 4).init(0);

    // Map boundary conditions, then movement checks
    const curr_char = matrix[location.y][location.x];
    const x_max_coord = matrix[0].len - 1;
    const y_max_coord = matrix.len - 1;

    const Dirs = struct { n: bool = true, e: bool = true, s: bool = true, w: bool = true };
    var valid_dirs = Dirs{};

    if (previous_dir) |dir| {
        switch (dir) {
            .N => {
                valid_dirs.s = false;
            },
            .E => {
                valid_dirs.w = false;
            },
            .S => {
                valid_dirs.n = false;
            },
            .W => {
                valid_dirs.e = false;
            },
        }
    }

    if (location.x == 0) {
        valid_dirs.w = false;
    } else if (!validMovementDirection(curr_char, matrix[location.y][location.x - 1], .W)) {
        valid_dirs.w = false;
    }

    if (location.x == x_max_coord) {
        valid_dirs.e = false;
    } else if (!validMovementDirection(curr_char, matrix[location.y][location.x + 1], .E)) {
        valid_dirs.e = false;
    }

    if (location.y == 0) {
        valid_dirs.n = false;
    } else if (!validMovementDirection(curr_char, matrix[location.y - 1][location.x], .N)) {
        valid_dirs.n = false;
    }

    if (location.y == y_max_coord) {
        valid_dirs.s = false;
    } else if (!validMovementDirection(curr_char, matrix[location.y + 1][location.x], .S)) {
        valid_dirs.s = false;
    }
    if (valid_dirs.n) try possible_directions.append(.N);
    if (valid_dirs.e) try possible_directions.append(.E);
    if (valid_dirs.s) try possible_directions.append(.S);
    if (valid_dirs.w) try possible_directions.append(.W);
    return possible_directions;
}

const Map = struct {
    allocator: std.mem.Allocator,
    start: Coordinate,
    matrix: [][]const u8,

    pub fn initFromPuzzleInput(allocator: std.mem.Allocator) !Map {
        var file_line_reader = try helpers.lineReaderFromAdventDay(10, allocator);
        defer file_line_reader.deinit();
        var init_len: ?usize = null;

        var matrix = std.ArrayList([]const u8).init(allocator);
        defer matrix.deinit();

        var y: usize = 0;
        var start_coord: Coordinate = .{ .x = 0, .y = 0 };
        while (file_line_reader.next()) |line| {
            // Some loose sanitation that each line is same length
            if (init_len) |_| {} else {
                init_len = line.len;
            }
            if (init_len.? != line.len) {
                return MyErrors.UnexpectedFormat;
            }
            for (line, 0..) |char, x| {
                if (char == 'S') {
                    start_coord.x = x;
                    start_coord.y = y;
                }
            }
            const owned_slice = try allocator.dupe(u8, line);
            errdefer allocator.free(owned_slice);
            try matrix.append(owned_slice);
            y += 1;
        }
        const matrix_slice = try matrix.toOwnedSlice();
        return Map{ .allocator = allocator, .start = start_coord, .matrix = matrix_slice };
    }

    pub fn deinit(self: *Map) void {
        for (self.matrix) |slice| {
            self.allocator.free(slice);
        }
        self.allocator.free(self.matrix);
    }

    pub fn potentialPathFinderStarts(self: Map) !std.BoundedArray(Coordinate, 4) {
        var ret_coords = try std.BoundedArray(Coordinate, 4).init(0);
        const possible_movements = try possibleMovementDirections(self.matrix, self.start, null);
        for (possible_movements.slice()) |direction| {
            switch (direction) {
                .N => {
                    // Bound sanity checks
                    if (self.start.y == 0) return MyErrors.UnexpectedFormat;
                    try ret_coords.append(Coordinate{ .x = self.start.x, .y = self.start.y - 1 });
                },
                .E => {
                    // Bound sanity checks
                    if (self.start.x == self.matrix[0].len - 1) return MyErrors.UnexpectedFormat;
                    try ret_coords.append(Coordinate{ .x = self.start.x + 1, .y = self.start.y });
                },
                .S => {
                    // Bound sanity checks
                    if (self.start.y == self.matrix.len - 1) return MyErrors.UnexpectedFormat;
                    try ret_coords.append(Coordinate{ .x = self.start.x, .y = self.start.y + 1 });
                },
                .W => {
                    // Bound sanity checks
                    if (self.start.x == 0) return MyErrors.UnexpectedFormat;
                    try ret_coords.append(Coordinate{ .x = self.start.x - 1, .y = self.start.y });
                },
            }
        }
        return ret_coords;
    }
};

const PathFinderErrors = error{ MoreThanOneValidMove, NoValidMoves };

const PathFinder = struct {
    allocator: std.mem.Allocator,
    current: Coordinate,
    map_matrix: [][]const u8,
    path_taken: std.ArrayList(Coordinate),
    dir_chars: std.ArrayList(u8),
    previous_dir: ?Direction = null,

    pub fn init(allocator: std.mem.Allocator, map: Map, pathfinder_start: Coordinate) !PathFinder {
        var path_taken = std.ArrayList(Coordinate).init(allocator);
        try path_taken.append(map.start);
        var dir_chars = std.ArrayList(u8).init(allocator);
        try dir_chars.append('S');
        return .{
            .allocator = allocator,
            .current = pathfinder_start,
            .map_matrix = map.matrix,
            .path_taken = path_taken,
            .dir_chars = dir_chars,
        };
    }

    pub fn deinit(self: *PathFinder) void {
        self.path_taken.deinit();
        self.dir_chars.deinit();
    }

    pub fn touchingStart(self: PathFinder) bool {
        if (self.current.x == 0) {
            if (self.map_matrix[self.current.y][self.current.x + 1] == 'S') {
                return true;
            }
        } else if (self.current.x == self.map_matrix[0].len - 1) {
            if (self.map_matrix[self.current.y][self.current.x - 1] == 'S') {
                return true;
            }
        } else {
            if ((self.map_matrix[self.current.y][self.current.x + 1] == 'S') or (self.map_matrix[self.current.y][self.current.x - 1] == 'S')) {
                return true;
            }
        }

        if (self.current.y == 0) {
            if (self.map_matrix[self.current.y + 1][self.current.x] == 'S') {
                return true;
            }
        } else if (self.current.y == self.map_matrix.len - 1) {
            if (self.map_matrix[self.current.y - 1][self.current.x] == 'S') {
                return true;
            }
        } else {
            if ((self.map_matrix[self.current.y + 1][self.current.x] == 'S') or (self.map_matrix[self.current.y - 1][self.current.x] == 'S')) {
                return true;
            }
        }
        return false;
    }

    pub fn traverse(self: *PathFinder) !void {
        try self.path_taken.append(self.current);
        const possible_movements = try possibleMovementDirections(self.map_matrix, self.current, self.previous_dir);
        if (possible_movements.len > 1) {
            try self.dir_chars.append('X');
            return PathFinderErrors.MoreThanOneValidMove;
        } else if (possible_movements.len == 0) {
            try self.dir_chars.append('X');
            return PathFinderErrors.NoValidMoves;
        }

        const direction = possible_movements.slice()[0];
        switch (direction) {
            .N => {
                // Bound sanity checks
                if (self.current.y == 0) unreachable;
                self.current.y -= 1;
                try self.dir_chars.append('^');
            },
            .E => {
                // Bound sanity checks
                if (self.current.x == self.map_matrix[0].len - 1) unreachable;
                self.current.x += 1;
                try self.dir_chars.append('>');
            },
            .S => {
                // Bound sanity checks
                if (self.current.y == self.map_matrix.len - 1) unreachable;
                self.current.y += 1;
                try self.dir_chars.append('v');
            },
            .W => {
                // Bound sanity checks
                if (self.current.x == 0) unreachable;
                self.current.x -= 1;
                try self.dir_chars.append('<');
            },
        }
        self.previous_dir = direction;
    }
};

/// Checks if a coordinate is enclosed by a "loop" of coordinates by raycasting in each cardinal direction
/// and checking the number of intersections. For a point to be enclosed, it must intersect the loop at
/// least once in each possible direction, AND at least one intersection must be odd.
fn coordinateIsEnclosedByLoop(coordinate: Coordinate, loop: []const Coordinate) bool {
    if (isInLoop(coordinate, loop)) {
        return false;
    }

    var odd_count: usize = 0;
    // Check intersections casting a ray North
    var intersection_count: usize = 0;
    for (loop) |loop_coord| {
        if ((loop_coord.x == coordinate.x) and (loop_coord.y < coordinate.y)) {
            intersection_count += 1;
        }
    }
    if (intersection_count == 0) {
        return false;
    } else if (@mod(intersection_count, 2) != 0) {
        odd_count += 1;
    }

    // North-East
    intersection_count = 0;
    for (loop) |loop_coord| {
        if ((loop_coord.x > coordinate.x) and (loop_coord.y < coordinate.y) and ((coordinate.y - loop_coord.y) == (loop_coord.x - coordinate.x))) {
            intersection_count += 1;
        }
    }
    if (intersection_count == 0) {
        return false;
    } else if (@mod(intersection_count, 2) != 0) {
        odd_count += 1;
    }

    // East
    intersection_count = 0;
    for (loop) |loop_coord| {
        if ((loop_coord.y == coordinate.y) and (loop_coord.x > coordinate.x)) {
            intersection_count += 1;
        }
    }
    if (intersection_count == 0) {
        return false;
    } else if (@mod(intersection_count, 2) != 0) {
        odd_count += 1;
    }

    // South-East
    intersection_count = 0;
    for (loop) |loop_coord| {
        if ((loop_coord.x > coordinate.x) and (loop_coord.y > coordinate.y) and ((loop_coord.y - coordinate.y) == (loop_coord.x - coordinate.x))) {
            intersection_count += 1;
        }
    }
    if (intersection_count == 0) {
        return false;
    } else if (@mod(intersection_count, 2) != 0) {
        odd_count += 1;
    }

    // South
    intersection_count = 0;
    for (loop) |loop_coord| {
        if ((loop_coord.x == coordinate.x) and (loop_coord.y > coordinate.y)) {
            intersection_count += 1;
        }
    }
    if (intersection_count == 0) {
        return false;
    } else if (@mod(intersection_count, 2) != 0) {
        odd_count += 1;
    }

    // South-West
    intersection_count = 0;
    for (loop) |loop_coord| {
        if ((loop_coord.x < coordinate.x) and (loop_coord.y > coordinate.y) and ((loop_coord.y - coordinate.y) == (coordinate.x - loop_coord.x))) {
            intersection_count += 1;
        }
    }
    if (intersection_count == 0) {
        return false;
    } else if (@mod(intersection_count, 2) != 0) {
        odd_count += 1;
    }

    // West
    intersection_count = 0;
    for (loop) |loop_coord| {
        if ((loop_coord.y == coordinate.y) and (loop_coord.x < coordinate.x)) {
            intersection_count += 1;
        }
    }
    if (intersection_count == 0) {
        return false;
    } else if (@mod(intersection_count, 2) != 0) {
        odd_count += 1;
    }

    // North-West
    intersection_count = 0;
    for (loop) |loop_coord| {
        if ((loop_coord.x < coordinate.x) and (loop_coord.y < coordinate.y) and ((coordinate.y - loop_coord.y) == (coordinate.x - loop_coord.x))) {
            intersection_count += 1;
        }
    }
    if (intersection_count == 0) {
        return false;
    } else if (@mod(intersection_count, 2) != 0) {
        odd_count += 1;
    }

    return odd_count > 0;
}

fn areaEnclosedByLoop(loop: []const Coordinate, map_matrix: [][]const u8) usize {
    var enclosed_count: usize = 0;
    for (map_matrix, 0..) |row, y| {
        for (row, 0..) |_, x| {
            if (coordinateIsEnclosedByLoop(.{ .x = x, .y = y }, loop)) {
                enclosed_count += 1;
            }
        }
    }
    return enclosed_count;
}

fn isInLoop(coordinate: Coordinate, loop: []const Coordinate) bool {
    for (loop) |loop_coord| {
        if ((loop_coord.x == coordinate.x) and (loop_coord.y == coordinate.y)) {
            return true;
        }
    }
    return false;
}

fn dirCharFromLoop(coordinate: Coordinate, loop: []const Coordinate, loop_chars: []const u8) u8 {
    for (loop, loop_chars) |loop_coord, c| {
        if ((loop_coord.x == coordinate.x) and (loop_coord.y == coordinate.y)) {
            return c;
        }
    }
    unreachable;
}

const PrintMethod = enum {
    NoAnnotation,
    InAndOut,
    JustIn,
    DirectionalPath,
};

fn printMapWithAreaAnnotations(comptime print_method: PrintMethod, loop: []const Coordinate, loop_chars: []const u8, map_matrix: [][]const u8) void {
    for (map_matrix, 0..) |row, y| {
        std.debug.print("\n", .{});
        for (row, 0..) |c, x| {
            switch (print_method) {
                .NoAnnotation => std.debug.print("{c}", .{c}),
                .InAndOut => {
                    if (isInLoop(.{ .x = x, .y = y }, loop)) {
                        std.debug.print("{c}", .{c});
                    } else {
                        if (coordinateIsEnclosedByLoop(.{ .x = x, .y = y }, loop)) {
                            std.debug.print("I", .{});
                        } else {
                            std.debug.print("O", .{});
                        }
                    }
                },
                .JustIn => {
                    if (isInLoop(.{ .x = x, .y = y }, loop)) {
                        std.debug.print("{c}", .{c});
                    } else {
                        if (coordinateIsEnclosedByLoop(.{ .x = x, .y = y }, loop)) {
                            std.debug.print("I", .{});
                        } else {
                            std.debug.print("{c}", .{c});
                        }
                    }
                },
                .DirectionalPath => {
                    if (isInLoop(.{ .x = x, .y = y }, loop)) {
                        const char = dirCharFromLoop(.{ .x = x, .y = y }, loop, loop_chars);
                        std.debug.print("{c}", .{char});
                    } else {
                        if (coordinateIsEnclosedByLoop(.{ .x = x, .y = y }, loop)) {
                            std.debug.print("I", .{});
                        } else {
                            std.debug.print(".", .{});
                        }
                    }
                },
            }
        }
    }
    std.debug.print("\n", .{});
}

fn calculateAnswer(allocator: std.mem.Allocator) ![2]usize {
    var answer: usize = 0;
    var answer2: usize = 0;
    var map = try Map.initFromPuzzleInput(allocator);
    defer map.deinit();

    const debug_print = true;

    // Collect possible starting directions and try each
    const potential_start_positions = try map.potentialPathFinderStarts();
    if (debug_print) {
        std.debug.print("Possible Starting Positions:\n", .{});
        for (potential_start_positions.slice()) |start_pos| {
            std.debug.print("    X={d} Y={d}\n", .{ start_pos.x, start_pos.y });
        }
    }

    for (potential_start_positions.slice()) |start_position| {
        var move_count: usize = 1; // Account for first "move" from start
        var path_finder = try PathFinder.init(allocator, map, start_position);
        defer path_finder.deinit();
        while (path_finder.traverse()) {
            move_count += 1;
            if (debug_print) std.debug.print("Moved {any} to {any}\n", .{ path_finder.previous_dir.?, path_finder.current });
        } else |err| {
            switch (err) {
                PathFinderErrors.NoValidMoves => {},
                else => return err,
            }
        }
        if (debug_print) std.debug.print("Finished traversal at point: {any}\n", .{path_finder.current});

        if (path_finder.touchingStart()) {
            if (debug_print) std.debug.print("Hooray we found it! Total moves: {d}\n", .{move_count});
            answer = (move_count + 1) / 2;

            // Now that we have a valid "path", in part2 we need to calculate num of tiles enclosed by path
            if (debug_print) printMapWithAreaAnnotations(.DirectionalPath, path_finder.path_taken.items, path_finder.dir_chars.items, map.matrix);
            answer2 = areaEnclosedByLoop(path_finder.path_taken.items, map.matrix);
            break;
        } else {
            if (debug_print) std.debug.print("Nah that aint it, let's try again\n", .{});
        }
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
