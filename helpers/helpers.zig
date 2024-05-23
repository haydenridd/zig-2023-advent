const std = @import("std");
const File = std.fs.File;

pub const MyErrors = error{UnexpectedFormat};

pub fn lineReaderFromAdventDay(comptime day: usize, allocator: std.mem.Allocator) !FileLineReader {
    return FileLineReader.init(allocator, "./inputs/" ++ std.fmt.comptimePrint("day{}", .{day}) ++ "_input.txt");
}

pub const FileLineReader = struct {
    allocator: std.mem.Allocator,
    current_line: std.ArrayList(u8),
    file: File,

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
};

test "FileLineReader" {
    var file_reader = try FileLineReader.init(std.testing.allocator, "inputs/test_file.txt");
    defer file_reader.deinit();

    var i: usize = 0;
    const expected_test_contents = [_][]const u8{ "hello", "from", "test", "file" };
    while (file_reader.next()) |line| : (i += 1) {
        try std.testing.expectEqualStrings(expected_test_contents[i], line);
    }
}
