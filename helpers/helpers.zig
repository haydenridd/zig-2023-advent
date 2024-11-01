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
    return struct {
        const BufferArray = std.BoundedArray(u8, buffer_size);
        const Self = FixedBufferLineReader(buffer_size);
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
            self.file.reader().streamUntilDelimiter(self.current_line.writer(), '\n', null) catch |err| switch (err) {
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

        test "Read Lines Iteratively" {
            var file_reader = try Self.init("test_inputs/test_file.txt");
            defer file_reader.deinit();

            var i: usize = 0;
            const expected_test_contents = [_][]const u8{ "hello", "from", "test", "file" };
            while (file_reader.next()) |line| : (i += 1) {
                try std.testing.expectEqualStrings(expected_test_contents[i], line);
            }
        }
    };
}

comptime {
    std.testing.refAllDecls(FileLineReader);
    std.testing.refAllDecls(FixedBufferLineReader(100));
}
