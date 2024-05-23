const std = @import("std");
const helpers = @import("helpers");
const FileLineReader = helpers.FileLineReader;
const MyErrors = helpers.MyErrors;

const Direction = enum(u8) { Left = 'L', Right = 'R' };

const Node = struct {
    name: [3]u8,
    left: ?*Node = null,
    right: ?*Node = null,

    pub fn format(
        self: Node,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("Node: {s} Left: {s} Right: {s}", .{ self.name, if (self.left) |l| &l.name else "[None]", if (self.right) |r| &r.name else "[None]" });
    }
};

fn generateTreeFromFile(comptime part2: bool, allocator: std.mem.Allocator) !Tree(part2) {
    var file_line_reader = try helpers.lineReaderFromAdventDay(8, allocator);
    defer file_line_reader.deinit();
    file_line_reader.skip(2);
    return try Tree(part2).initFromLineReader(allocator, &file_line_reader);
}

fn Tree(comptime part2: bool) type {
    return struct {
        allocator: std.mem.Allocator,
        storage: []Node,
        start: *Node,
        current: *Node,
        const Self = @This();
        pub fn traverse(self: *Self, direction: Direction) void {
            self.current = if (direction == .Right) self.current.right.? else self.current.left.?;
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.storage);
        }

        pub fn done(self: Self) bool {
            if (part2) {
                return self.current.name[2] == 'Z';
            } else {
                return std.mem.eql(u8, &self.current.name, "ZZZ");
            }
        }

        pub fn resetToNamedNode(self: *Self, node_name: []const u8) void {
            const node = findNodeInArray(node_name, self.storage).?;
            self.start = node;
            self.current = node;
        }

        fn findNodeInArray(node_name: []const u8, node_arr: []Node) ?*Node {
            for (node_arr, 0..) |node, idx| {
                if (std.mem.eql(u8, &node.name, node_name)) {
                    return &node_arr[idx];
                }
            }
            return null;
        }

        pub fn initFromLineReader(allocator: std.mem.Allocator, file_line_reader: *FileLineReader) !Self {

            // Assumes directions have already been scooped off!
            var node_storage = std.ArrayList(Node).init(allocator);
            defer node_storage.deinit();

            const LinkingInfo = struct { parent: [3]u8, left: [3]u8, right: [3]u8 };

            var linking_info = std.ArrayList(LinkingInfo).init(allocator);
            defer linking_info.deinit();

            // First pass stores all Nodes unlinked + linking information
            while (file_line_reader.next()) |line| {
                var node_it = std.mem.tokenizeAny(u8, line, " =(,)");
                const main_node_name = node_it.next() orelse return MyErrors.UnexpectedFormat;
                const left_node_name = node_it.next() orelse return MyErrors.UnexpectedFormat;
                const right_node_name = node_it.next() orelse return MyErrors.UnexpectedFormat;

                try linking_info.append(LinkingInfo{ .parent = main_node_name[0..3].*, .left = left_node_name[0..3].*, .right = right_node_name[0..3].* });

                if (findNodeInArray(main_node_name, node_storage.items)) |_| {} else {
                    try node_storage.append(Node{ .name = main_node_name[0..3].*, .left = null, .right = null });
                }
                if (findNodeInArray(left_node_name, node_storage.items)) |_| {} else {
                    try node_storage.append(Node{ .name = left_node_name[0..3].*, .left = null, .right = null });
                }
                if (findNodeInArray(right_node_name, node_storage.items)) |_| {} else {
                    try node_storage.append(Node{ .name = right_node_name[0..3].*, .left = null, .right = null });
                }
            }

            // Now that pointers will be valid, second pass links all nodes together
            const owned_storage = try node_storage.toOwnedSlice();

            for (linking_info.items) |link_info| {
                var parent = findNodeInArray(&link_info.parent, owned_storage).?;
                parent.left = findNodeInArray(&link_info.left, owned_storage).?;
                parent.right = findNodeInArray(&link_info.right, owned_storage).?;
            }

            const start = findNodeInArray("AAA", owned_storage).?;

            return Self{ .allocator = allocator, .storage = owned_storage, .start = start, .current = start };
        }

        pub fn format(
            self: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;

            try writer.print("Tree: Start: {any} Current: {any} Done: {s}", .{ self.start, self.current, if (self.done()) "YES" else "NO" });
        }
    };
}

fn calculateAnswerPart1(allocator: std.mem.Allocator) !u64 {
    var file_line_reader = try helpers.lineReaderFromAdventDay(8, allocator);
    defer file_line_reader.deinit();
    const dir_line = file_line_reader.next() orelse return MyErrors.UnexpectedFormat;
    var dirs = std.ArrayList(Direction).init(allocator);
    defer dirs.deinit();
    for (dir_line) |dir| {
        if (dir == 'L') {
            try dirs.append(.Left);
        } else {
            try dirs.append(.Right);
        }
    }

    var tree = try generateTreeFromFile(false, allocator);
    defer tree.deinit();

    var step_count: u64 = 0;
    while (!tree.done()) {
        tree.traverse(dirs.items[@mod(step_count, dirs.items.len)]);
        step_count += 1;
    }

    return step_count;
}

fn allTreesDone(trees: []const Tree(true)) bool {
    for (trees) |tree| {
        if (!tree.done()) {
            return false;
        }
    }
    return true;
}

fn calculateAnswerPart2(allocator: std.mem.Allocator) !u128 {
    var file_line_reader = try helpers.lineReaderFromAdventDay(8, allocator);
    defer file_line_reader.deinit();
    const dir_line = file_line_reader.next() orelse return MyErrors.UnexpectedFormat;
    var dirs = std.ArrayList(Direction).init(allocator);
    defer dirs.deinit();
    for (dir_line) |dir| {
        if (dir == 'L') {
            try dirs.append(.Left);
        } else {
            try dirs.append(.Right);
        }
    }

    var tree = try generateTreeFromFile(true, allocator);
    defer tree.deinit();
    // Find how many steps it takes for each individual search to complete
    var finish_points = try std.BoundedArray(u64, 10).init(0);

    for (tree.storage) |node| {
        if (node.name[2] == 'A') {
            var step_count: u64 = 0;
            tree.resetToNamedNode(&node.name);
            while (!tree.done()) {
                tree.traverse(dirs.items[@mod(step_count, dirs.items.len)]);
                step_count += 1;
            }
            try finish_points.append(step_count);
        }
    }

    // LCM gives us the answer
    var answer: ?u128 = null;
    for (finish_points.slice()) |fp| {
        if (answer) |_| {
            answer = (answer.? * fp) / std.math.gcd(answer.?, fp);
        } else {
            answer = fp;
        }
    }

    return answer.?;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const answer_part1 = try calculateAnswerPart1(alloc);
    std.debug.print("Answer Part 1: {d}\n", .{answer_part1});
    const answer_part2 = try calculateAnswerPart2(alloc);
    std.debug.print("Answer Part 2: {d}\n", .{answer_part2});
    std.debug.assert(!gpa.detectLeaks());
}
