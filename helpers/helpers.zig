const std = @import("std");
const File = std.fs.File;

pub const GeneralErrors = error{UnexpectedFormat};

pub const FileLineReader = struct {
    allocator: std.mem.Allocator,
    current_line: std.ArrayList(u8),
    file: File,

    pub fn fromAdventDay(comptime day: usize, allocator: std.mem.Allocator) !FileLineReader {
        return FileLineReader.init(allocator, "./inputs/" ++ std.fmt.comptimePrint("day{}", .{day}) ++ "_input.txt");
    }

    pub fn init(allocator: std.mem.Allocator, path: []const u8) !FileLineReader {
        return FileLineReader{ .allocator = allocator, .current_line = std.ArrayList(u8).init(allocator), .file = try std.fs.cwd().openFile(path, .{}) };
    }

    pub fn deinit(self: *FileLineReader) void {
        self.file.close();
        self.current_line.deinit();
    }

    pub fn next(self: *FileLineReader) ?[]const u8 {
        self.current_line.clearAndFree();
        self.file.reader().streamUntilDelimiter(self.current_line.writer(), '\n', null) catch {
            return null;
        };
        return self.current_line.items;
    }

    pub fn skip(self: *FileLineReader, num: usize) void {
        for (0..num) |_| {
            _ = self.next() orelse return;
        }
    }

    pub fn collect(self: *FileLineReader) !std.ArrayList(std.ArrayList(u8)) {
        var ret_arr = std.ArrayList(std.ArrayList(u8)).init(self.allocator);
        errdefer ret_arr.deinit();
        while (self.next()) |line| {
            var line_arr = std.ArrayList(u8).init(self.allocator);
            errdefer line_arr.deinit();
            try line_arr.appendSlice(line);
            try ret_arr.append(line_arr);
        }
        return ret_arr;
    }

    test "Read Lines Iteratively" {
        var file_reader = try FileLineReader.init(std.testing.allocator, "test_inputs/test_file.txt");
        defer file_reader.deinit();

        var i: usize = 0;
        const expected_test_contents = [_][]const u8{ "hello", "from", "test", "file" };
        while (file_reader.next()) |line| : (i += 1) {
            try std.testing.expectEqualStrings(expected_test_contents[i], line);
        }
    }

    test "Collect Lines" {
        var file_reader = try FileLineReader.init(std.testing.allocator, "test_inputs/test_file.txt");
        defer file_reader.deinit();

        var all_lines = try file_reader.collect();
        defer {
            for (all_lines.items) |line| {
                line.deinit();
            }
            all_lines.deinit();
        }
        const expected_test_contents = [_][]const u8{ "hello", "from", "test", "file" };
        for (all_lines.items, 0..) |line, i| {
            try std.testing.expectEqualStrings(expected_test_contents[i], line.items);
        }
    }
};

pub fn FixedBufferLineReader(buffer_size: usize) type {
    return FixedBufferDelimitedReader('\n', buffer_size);
}

pub fn FixedBufferCSVReader(buffer_size: usize) type {
    return FixedBufferDelimitedReader(',', buffer_size);
}

pub fn FixedBufferDelimitedReader(delim: u8, buffer_size: usize) type {
    return struct {
        const BufferArray = std.BoundedArray(u8, buffer_size);
        const Self = @This();
        current_line: BufferArray,
        file: File,

        pub fn fromAdventDay(comptime day: usize) !Self {
            return Self.init("./inputs/" ++ std.fmt.comptimePrint("day{}", .{day}) ++ "_input.txt");
        }

        pub fn fromTestInput(comptime day: usize) !Self {
            return Self.init("./test_inputs/" ++ std.fmt.comptimePrint("day{}", .{day}) ++ "_input.txt");
        }

        pub fn init(path: []const u8) !Self {
            return Self{ .current_line = try BufferArray.init(0), .file = try std.fs.cwd().openFile(path, .{}) };
        }

        pub fn deinit(self: *Self) void {
            self.file.close();
        }

        pub fn next(self: *Self) ?[]const u8 {
            self.current_line.resize(0) catch unreachable;
            self.file.reader().streamUntilDelimiter(self.current_line.writer(), delim, null) catch |err| switch (err) {
                error.EndOfStream => return null,
                else => unreachable,
            };
            return self.current_line.constSlice();
        }

        pub fn skip(self: *Self, num: usize) void {
            for (0..num) |_| {
                _ = self.next() orelse return;
            }
        }

        pub fn collect(self: *Self, allocator: std.mem.Allocator) !std.ArrayList(std.ArrayList(u8)) {
            var ret_arr = std.ArrayList(std.ArrayList(u8)).init(allocator);
            errdefer ret_arr.deinit();
            while (self.next()) |line| {
                var line_arr = std.ArrayList(u8).init(allocator);
                errdefer line_arr.deinit();
                try line_arr.appendSlice(line);
                try ret_arr.append(line_arr);
            }
            return ret_arr;
        }
    };
}

test "Read Lines Iteratively" {
    var file_reader = try FixedBufferLineReader(100).init("test_inputs/test_file.txt");
    defer file_reader.deinit();

    var i: usize = 0;
    const expected_test_contents = [_][]const u8{ "hello", "from", "test", "file" };
    while (file_reader.next()) |line| : (i += 1) {
        try std.testing.expectEqualStrings(expected_test_contents[i], line);
    }
}

test "Read CSV Iteratively" {
    var file_reader = try FixedBufferCSVReader(100).init("test_inputs/test_file.txt");
    defer file_reader.deinit();

    var i: usize = 0;
    const expected_test_contents = [_][]const u8{ "hello", "from", "test", "file" };
    while (file_reader.next()) |line| : (i += 1) {
        try std.testing.expectEqualStrings(expected_test_contents[i], line);
    }
}

pub fn LineCollector(max_line_width: usize, max_num_lines: usize) type {
    return struct {
        pub const LineBuffer = std.BoundedArray(u8, max_line_width);
        pub const LineArray = std.BoundedArray(LineBuffer, max_num_lines);

        fn collectInternal(comptime advent_day: usize, comptime use_test: bool) LineArray {
            var line_reader = if (use_test) FixedBufferLineReader(max_line_width).fromTestInput(advent_day) catch unreachable else FixedBufferLineReader(max_line_width).fromAdventDay(advent_day) catch unreachable;
            defer line_reader.deinit();

            var ret = LineArray.init(0) catch unreachable;
            while (line_reader.next()) |line| {
                const item = ret.addOne() catch unreachable;
                item.* = LineBuffer.init(0) catch unreachable;
                item.*.appendSlice(line) catch unreachable;
            }
            return ret;
        }

        pub fn collectFromAdventDay(comptime advent_day: usize) LineArray {
            return collectInternal(advent_day, false);
        }

        pub fn collectFromTestInput(comptime advent_day: usize) LineArray {
            return collectInternal(advent_day, true);
        }
    };
}

pub fn NewLineArray(max_line_width: usize, max_num_lines: usize) type {
    return struct {
        _internal_buffer: OverallBuffer,
        _outer_slice_mem: [max_num_lines][]u8,

        const Self = @This();
        pub const BufferPerLine = std.BoundedArray(u8, max_line_width);
        pub const OverallBuffer = std.BoundedArray(BufferPerLine, max_num_lines);

        fn collectInternal(comptime advent_day: usize, comptime use_test: bool) Self {
            var line_reader = if (use_test) FixedBufferLineReader(max_line_width).fromTestInput(advent_day) catch unreachable else FixedBufferLineReader(max_line_width).fromAdventDay(advent_day) catch unreachable;
            defer line_reader.deinit();

            var ret: Self = undefined;

            ret._internal_buffer = OverallBuffer.init(0) catch unreachable;

            var idx: usize = 0;
            while (line_reader.next()) |line| : (idx += 1) {
                const item = ret._internal_buffer.addOne() catch unreachable;
                item.* = BufferPerLine.init(0) catch unreachable;
                item.*.appendSlice(line) catch unreachable;
            }

            return ret;
        }

        pub fn fromAdventDay(comptime advent_day: usize) Self {
            return collectInternal(advent_day, false);
        }

        pub fn fromTestInput(comptime advent_day: usize) Self {
            return collectInternal(advent_day, true);
        }

        pub fn slice(self: *Self) []const []u8 {
            for (self._internal_buffer.slice(), 0..) |*itm, idx| {
                self._outer_slice_mem[idx] = itm.*.slice();
            }
            return self._outer_slice_mem[0..self._internal_buffer.len];
        }
    };
}

fn additionalLayer(slice: []const []u8) !void {
    const expected_slice: []const []const u8 = &.{
        "X....#....",
        "O.OO#....#",
        ".....##...",
        "OO.#X....O",
        ".O.....O#.",
        "O.#..O.#.#",
        "..O..#O..O",
        ".......O..",
        "#....###..",
        "#OO..#...X",
    };
    slice[0][0] = 'X';
    slice[3][4] = 'X';
    slice[9][9] = 'X';
    try std.testing.expectEqualDeep(expected_slice, slice);
}

test "NewLineArray" {
    const expected_slice: []const []const u8 = &.{
        "O....#....",
        "O.OO#....#",
        ".....##...",
        "OO.#O....O",
        ".O.....O#.",
        "O.#..O.#.#",
        "..O..#O..O",
        ".......O..",
        "#....###..",
        "#OO..#....",
    };

    var nla = NewLineArray(100, 100).fromTestInput(14);
    try std.testing.expectEqualDeep(expected_slice, nla.slice());
    try additionalLayer(nla.slice());
}

comptime {
    std.testing.refAllDecls(FileLineReader);
    std.testing.refAllDecls(FixedBufferLineReader(100));
}
