const std = @import("std");
const helpers = @import("helpers");
const GeneralErrors = helpers.GeneralErrors;

pub const std_options: std.Options = .{
    .log_level = .info,
};

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
        var file_line_reader = try helpers.FixedBufferLineReader(150).fromAdventDay(10);
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
                return GeneralErrors.UnexpectedFormat;
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
                    if (self.start.y == 0) return GeneralErrors.UnexpectedFormat;
                    try ret_coords.append(Coordinate{ .x = self.start.x, .y = self.start.y - 1 });
                },
                .E => {
                    // Bound sanity checks
                    if (self.start.x == self.matrix[0].len - 1) return GeneralErrors.UnexpectedFormat;
                    try ret_coords.append(Coordinate{ .x = self.start.x + 1, .y = self.start.y });
                },
                .S => {
                    // Bound sanity checks
                    if (self.start.y == self.matrix.len - 1) return GeneralErrors.UnexpectedFormat;
                    try ret_coords.append(Coordinate{ .x = self.start.x, .y = self.start.y + 1 });
                },
                .W => {
                    // Bound sanity checks
                    if (self.start.x == 0) return GeneralErrors.UnexpectedFormat;
                    try ret_coords.append(Coordinate{ .x = self.start.x - 1, .y = self.start.y });
                },
            }
        }
        return ret_coords;
    }
};

const DaySpecificErrors = error{ MoreThanOneValidMove, NoValidMoves };

const PathFinder = struct {
    allocator: std.mem.Allocator,
    current: Coordinate,
    map_matrix: [][]const u8,
    path_vertices: std.ArrayList(Coordinate),
    previous_dir: ?Direction = null,

    pub fn init(allocator: std.mem.Allocator, map: Map, pathfinder_start: Coordinate) !PathFinder {
        var path_vertices = std.ArrayList(Coordinate).init(allocator);
        try path_vertices.append(map.start); // Starting coordinate is always going to be a vertex
        return .{
            .allocator = allocator,
            .current = pathfinder_start,
            .map_matrix = map.matrix,
            .path_vertices = path_vertices,
        };
    }

    pub fn deinit(self: *PathFinder) void {
        self.path_vertices.deinit();
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
        const possible_movements = try possibleMovementDirections(self.map_matrix, self.current, self.previous_dir);
        if (possible_movements.len > 1) {
            return DaySpecificErrors.MoreThanOneValidMove;
        } else if (possible_movements.len == 0) {
            return DaySpecificErrors.NoValidMoves;
        }

        const direction = possible_movements.slice()[0];

        // A change in direction indicates a vertex
        if (self.previous_dir) |pdir| {
            if (pdir != direction) {
                try self.path_vertices.append(self.current);
            }
        } else {
            try self.path_vertices.append(self.current);
        }

        switch (direction) {
            .N => {
                // Bound sanity checks
                if (self.current.y == 0) unreachable;
                self.current.y -= 1;
            },
            .E => {
                // Bound sanity checks
                if (self.current.x == self.map_matrix[0].len - 1) unreachable;
                self.current.x += 1;
            },
            .S => {
                // Bound sanity checks
                if (self.current.y == self.map_matrix.len - 1) unreachable;
                self.current.y += 1;
            },
            .W => {
                // Bound sanity checks
                if (self.current.x == 0) unreachable;
                self.current.x -= 1;
            },
        }
        self.previous_dir = direction;
    }
};

/// Implementation of the Point-In-Polygon algorithm using ray casting:
/// https://sszczep.dev/blog/ray-casting-in-2d-game-engines#:~:text=Point%2Din%2Dpolygon%20problem&text=Using%20the%20ray%20casting%20algorithm,polygon%20or%20on%20its%20boundary.
fn coordinateIsEnclosedByLoop(coordinate: Coordinate, vertices: []const Coordinate) bool {
    var intersection_count: usize = 0;

    // Special hack, if point has NO points left, it can't be inside!
    var has_something_left = false;

    for (0..vertices.len) |i| {
        const vertex1 = vertices[i];
        const vertex2 = vertices[(i + 1) % vertices.len];

        // If it's in the edge, don't include it
        if ((coordinate.x >= @min(vertex1.x, vertex2.x)) and (coordinate.x <= @max(vertex1.x, vertex2.x)) and (coordinate.y >= @min(vertex1.y, vertex2.y)) and (coordinate.y <= @max(vertex1.y, vertex2.y))) {
            return false;
        }

        if ((vertex1.x == vertex2.x) and (coordinate.y > @min(vertex1.y, vertex2.y)) and (coordinate.y <= @max(vertex1.y, vertex2.y)) and (coordinate.x < vertex1.x)) {
            // Edge is vertical and our pt is left of edge
            intersection_count += 1;
        }

        if ((coordinate.y >= @min(vertex1.y, vertex2.y)) and (coordinate.y <= @max(vertex1.y, vertex2.y)) and (coordinate.x > vertex1.x)) {
            has_something_left = true;
        }
    }

    if (!has_something_left) {
        return false;
    }

    return @mod(intersection_count, 2) != 0;
}

fn areaEnclosedByLoop(vertices: []const Coordinate, map_matrix: [][]const u8) usize {
    var enclosed_count: usize = 0;
    for (map_matrix, 0..) |row, y| {
        for (row, 0..) |_, x| {
            if (coordinateIsEnclosedByLoop(.{ .x = x, .y = y }, vertices)) {
                enclosed_count += 1;
            }
        }
    }
    return enclosed_count;
}

const PrintMethod = enum { Default };

fn printMapWithAreaAnnotations(comptime print_method: PrintMethod, vertices: []const Coordinate, map_matrix: [][]const u8) void {
    for (map_matrix, 0..) |row, y| {
        std.debug.print("\n", .{});
        for (row, 0..) |c, x| {
            switch (print_method) {
                .Default => {
                    if (coordinateIsEnclosedByLoop(.{ .x = x, .y = y }, vertices)) {
                        std.debug.print("I", .{});
                    } else {
                        std.debug.print("{c}", .{c});
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

    const debug_print = false;

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
                DaySpecificErrors.NoValidMoves => {},
                else => return err,
            }
        }
        if (debug_print) std.debug.print("Finished traversal at point: {any}\n", .{path_finder.current});

        if (path_finder.touchingStart()) {
            if (debug_print) std.debug.print("Hooray we found it! Total moves: {d}\n", .{move_count});
            answer = (move_count + 1) / 2;
            if (debug_print) printMapWithAreaAnnotations(.Default, path_finder.path_vertices.items, map.matrix);
            // Now that we have a valid "path", in part2 we need to calculate num of tiles enclosed by path
            answer2 = areaEnclosedByLoop(path_finder.path_vertices.items, map.matrix);
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
    std.log.info("Answer part 1: {d}", .{answer[0]});
    std.log.info("Answer part 2: {?}", .{answer[1]});
    std.debug.assert(!gpa.detectLeaks());
}
