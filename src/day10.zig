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

const PossibleNextMovement = struct {
    n: bool,
    e: bool,
    s: bool,
    w: bool,

    pub fn fromLocation(matrix: [][]const u8, location: Coordinate, previous_dir: ?Direction) PossibleNextMovement {
        var possible_movement: PossibleNextMovement = .{ .n = true, .e = true, .s = true, .w = true };

        // Map boundary conditions, then movement checks
        const curr_char = matrix[location.y][location.x];
        const x_max_coord = matrix[0].len - 1;
        const y_max_coord = matrix.len - 1;

        if (previous_dir) |dir| {
            switch (dir) {
                .N => {
                    possible_movement.s = false;
                },
                .E => {
                    possible_movement.w = false;
                },
                .S => {
                    possible_movement.n = false;
                },
                .W => {
                    possible_movement.e = false;
                },
            }
        }

        if (location.x == 0) {
            possible_movement.w = false;
        } else if (!validMovementDirection(curr_char, matrix[location.y][location.x - 1], .W)) {
            possible_movement.w = false;
        }

        if (location.x == x_max_coord) {
            possible_movement.e = false;
        } else if (!validMovementDirection(curr_char, matrix[location.y][location.x + 1], .E)) {
            possible_movement.e = false;
        }

        if (location.y == 0) {
            possible_movement.n = false;
        } else if (!validMovementDirection(curr_char, matrix[location.y - 1][location.x], .N)) {
            possible_movement.n = false;
        }

        if (location.y == y_max_coord) {
            possible_movement.s = false;
        } else if (!validMovementDirection(curr_char, matrix[location.y + 1][location.x], .S)) {
            possible_movement.s = false;
        }

        return possible_movement;
    }

    pub fn numValidDirs(self: PossibleNextMovement) u8 {
        var num_dirs: u8 = 0;
        if (self.n) num_dirs += 1;
        if (self.s) num_dirs += 1;
        if (self.e) num_dirs += 1;
        if (self.w) num_dirs += 1;
        return num_dirs;
    }

    pub fn firstValidDir(self: PossibleNextMovement) ?Direction {
        if (self.n) return .N;
        if (self.s) return .S;
        if (self.e) return .E;
        if (self.w) return .W;
        return null;
    }
};

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
        return Map{ .allocator = allocator, .start = start_coord, .current = start_coord, .previous_dir = null, .current_possible_movement = PossibleNextMovement.fromLocation(matrix_slice, start_coord, null), .matrix = matrix_slice };
    }

    pub fn deinit(self: *Map) void {
        for (self.matrix) |slice| {
            self.allocator.free(slice);
        }
        self.allocator.free(self.matrix);
    }
};

const PathFinder = struct {
    current: Coordinate,
    previous_dir: ?Direction,
    current_possible_movement: PossibleNextMovement,

    pub fn touchingStart(self: Map) bool {
        if (self.current.x == 0) {
            if (self.matrix[self.current.y][self.current.x + 1] == 'S') {
                return true;
            }
        } else if (self.current.x == self.matrix[0].len - 1) {
            if (self.matrix[self.current.y][self.current.x - 1] == 'S') {
                return true;
            }
        } else {
            if ((self.matrix[self.current.y][self.current.x + 1] == 'S') or (self.matrix[self.current.y][self.current.x - 1] == 'S')) {
                return true;
            }
        }

        if (self.current.y == 0) {
            if (self.matrix[self.current.y + 1][self.current.x] == 'S') {
                return true;
            }
        } else if (self.current.y == self.matrix.len - 1) {
            if (self.matrix[self.current.y - 1][self.current.x] == 'S') {
                return true;
            }
        } else {
            if ((self.matrix[self.current.y + 1][self.current.x] == 'S') or (self.matrix[self.current.y - 1][self.current.x] == 'S')) {
                return true;
            }
        }
        return false;
    }

    pub fn resetToStart(self: *Map) void {
        self.current.x = self.start.x;
        self.current.y = self.start.y;
        self.previous_dir = null;
        self.current_possible_movement = PossibleNextMovement.fromLocation(self.matrix, self.current, self.previous_dir);
    }

    pub fn traverse(self: *Map, direction: Direction) void {
        switch (direction) {
            .N => {
                // Bound sanity checks
                if (self.current.y == 0) unreachable;
                self.current.y -= 1;
            },
            .E => {
                // Bound sanity checks
                if (self.current.x == self.matrix[0].len - 1) unreachable;
                self.current.x += 1;
            },
            .S => {
                // Bound sanity checks
                if (self.current.y == self.matrix.len - 1) unreachable;
                self.current.y += 1;
            },
            .W => {
                // Bound sanity checks
                if (self.current.x == 0) unreachable;
                self.current.x -= 1;
            },
        }
        self.previous_dir = direction;
        self.current_possible_movement = PossibleNextMovement.fromLocation(self.matrix, self.current, self.previous_dir);
    }
};

fn calculateAnswer(allocator: std.mem.Allocator) ![2]usize {
    var answer: usize = 0;
    const answer2: usize = 0;
    var map = try Map.initFromPuzzleInput(allocator);
    defer map.deinit();

    const debug_print = false;

    // Collect possible starting directions and try each
    if (debug_print) std.debug.print("Start: {any}\n", .{map.start});
    if (debug_print) std.debug.print("Possible Starting Moves: {any}\n", .{map.current_possible_movement});
    var possible_dirs = try std.BoundedArray(Direction, 4).init(0);
    if (map.current_possible_movement.n) try possible_dirs.append(.N);
    if (map.current_possible_movement.e) try possible_dirs.append(.E);
    if (map.current_possible_movement.s) try possible_dirs.append(.S);
    if (map.current_possible_movement.w) try possible_dirs.append(.W);

    for (possible_dirs.slice()) |dir_to_start_with| {
        var curr_dir: ?Direction = dir_to_start_with;
        var move_count: usize = 0;
        while (map.current_possible_movement.numValidDirs() > 0) {
            map.traverse(curr_dir.?);
            move_count += 1;
            if (debug_print) std.debug.print("Moved {any} to {any}\n", .{ curr_dir.?, map.current });
            if (map.current_possible_movement.numValidDirs() > 1) {
                std.debug.panic("Something has gone hideously wrong!, current coord: {any}, movement: {any}\n", .{ map.current, map.current_possible_movement });
            }
            curr_dir = map.current_possible_movement.firstValidDir();
        }
        if (debug_print) std.debug.print("Finished traversal at point: {any}\n", .{map.current});

        if (map.touchingStart()) {
            if (debug_print) std.debug.print("Hooray we found it! Total moves: {d}\n", .{move_count});
            answer = (move_count + 1) / 2;
            break;
        } else {
            if (debug_print) std.debug.print("Nah that aint it, let's try again\n", .{});
        }
        map.resetToStart();
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
