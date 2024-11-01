const std = @import("std");
const helpers = @import("helpers");
const GeneralErrors = helpers.GeneralErrors;

pub const std_options: std.Options = .{
    .log_level = .info,
};

const CubeDrawing = struct {
    red: usize,
    green: usize,
    blue: usize,

    pub fn initFromString(string: []const u8) !CubeDrawing {
        var cd = CubeDrawing{ .red = 0, .green = 0, .blue = 0 };
        var comma_tok = std.mem.tokenizeScalar(u8, string, ',');
        while (comma_tok.next()) |draw_str| {
            var space_tok = std.mem.tokenizeAny(u8, draw_str, " ");
            const draw_num = try std.fmt.parseInt(u8, space_tok.next() orelse return GeneralErrors.UnexpectedFormat, 10);
            const color_str = space_tok.next() orelse return GeneralErrors.UnexpectedFormat;
            if (std.mem.eql(u8, "red", color_str)) {
                cd.red = draw_num;
            } else if (std.mem.eql(u8, "green", color_str)) {
                cd.green = draw_num;
            } else if (std.mem.eql(u8, "blue", color_str)) {
                cd.blue = draw_num;
            } else {
                return GeneralErrors.UnexpectedFormat;
            }
        }
        return cd;
    }
};

test "Drawing parsing from string" {
    var drawing = try CubeDrawing.initFromString(" 3 blue, 4 red, 1 green");
    try std.testing.expectEqual(3, drawing.blue);
    try std.testing.expectEqual(4, drawing.red);
    try std.testing.expectEqual(1, drawing.green);
    drawing = try CubeDrawing.initFromString(" 3 blue");
    try std.testing.expectEqual(3, drawing.blue);
    try std.testing.expectEqual(0, drawing.red);
    try std.testing.expectEqual(0, drawing.green);
}

const Game = struct {
    allocator: std.mem.Allocator,
    id: usize,
    drawings: []const CubeDrawing,

    pub fn initFromLine(allocator: std.mem.Allocator, line: []const u8) !Game {

        // Get Game ID
        var game_tok = std.mem.tokenizeSequence(u8, line, ": ");
        const game_str = game_tok.next() orelse return GeneralErrors.UnexpectedFormat;
        const drawings_str = game_tok.next() orelse return GeneralErrors.UnexpectedFormat;
        var game_str_tok = std.mem.tokenizeScalar(u8, game_str, ' ');
        _ = game_str_tok.next() orelse return GeneralErrors.UnexpectedFormat;
        const game_id = try std.fmt.parseInt(u8, game_str_tok.next() orelse return GeneralErrors.UnexpectedFormat, 10);

        // Get Drawings
        var drawings = std.ArrayList(CubeDrawing).init(allocator);
        defer drawings.deinit();

        var drawing_tok = std.mem.tokenizeScalar(u8, drawings_str, ';');
        while (drawing_tok.next()) |drawing_str| {
            const some_drawing = try CubeDrawing.initFromString(drawing_str);
            try drawings.append(some_drawing);
        }

        return Game{ .allocator = allocator, .id = game_id, .drawings = try drawings.toOwnedSlice() };
    }

    pub fn deinit(self: Game) void {
        self.allocator.free(self.drawings);
    }
};

test "Game parsing from line" {
    var game1 = try Game.initFromLine(std.testing.allocator, "Game 1: 3 blue, 4 red, 1 green");
    defer game1.deinit();
    try std.testing.expectEqual(1, game1.id);
    try std.testing.expectEqual(3, game1.drawings[0].blue);
    try std.testing.expectEqual(4, game1.drawings[0].red);
    try std.testing.expectEqual(1, game1.drawings[0].green);

    var game2 = try Game.initFromLine(std.testing.allocator, "Game 1: 3 blue, 4 red, 1 green; 1 red, 2 green, 5 blue");
    defer game2.deinit();
    try std.testing.expectEqual(1, game2.id);
    try std.testing.expectEqual(3, game2.drawings[0].blue);
    try std.testing.expectEqual(4, game2.drawings[0].red);
    try std.testing.expectEqual(1, game2.drawings[0].green);
    try std.testing.expectEqual(1, game2.drawings[1].red);
    try std.testing.expectEqual(2, game2.drawings[1].green);
    try std.testing.expectEqual(5, game2.drawings[1].blue);
}

fn calculateAnswer(allocator: std.mem.Allocator, game_limits_for_part1: CubeDrawing) ![2]usize {
    var answer_part1: usize = 0;
    var answer_part2: usize = 0;
    var file_line_reader = try helpers.FixedBufferLineReader(300).fromAdventDay(2);
    defer file_line_reader.deinit();

    while (file_line_reader.next()) |line| {
        const game = try Game.initFromLine(allocator, line);
        defer game.deinit();

        var max_seen = CubeDrawing{ .red = 0, .green = 0, .blue = 0 };
        var game_possible = true;
        for (game.drawings) |drawing| {
            // Part 1 Logic
            if (drawing.red > game_limits_for_part1.red) game_possible = false;
            if (drawing.green > game_limits_for_part1.green) game_possible = false;
            if (drawing.blue > game_limits_for_part1.blue) game_possible = false;

            // Part 2 Logic
            if (drawing.red > max_seen.red) max_seen.red = drawing.red;
            if (drawing.green > max_seen.green) max_seen.green = drawing.green;
            if (drawing.blue > max_seen.blue) max_seen.blue = drawing.blue;
        }
        if (game_possible) answer_part1 += game.id;
        answer_part2 += max_seen.red * max_seen.green * max_seen.blue;
    }

    return .{ answer_part1, answer_part2 };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const answer = try calculateAnswer(alloc, .{ .red = 12, .green = 13, .blue = 14 });
    std.log.info("Answer - [Part1: {d}, Part2: {d}]\n", .{ answer[0], answer[1] });
    std.debug.assert(!gpa.detectLeaks());
}
