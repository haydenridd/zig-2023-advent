const std = @import("std");
const helpers = @import("helpers");
const GeneralErrors = helpers.GeneralErrors;

pub const std_options: std.Options = .{
    .log_level = .info,
};

const SeedIter = struct {
    curr: isize,
    direction: i8,
    end: isize,
    started: bool = false,
    finished: bool = false,
    pub fn next(self: *SeedIter) ?usize {
        if (self.finished) {
            return null;
        } else if (!self.started) {
            self.started = true;

            // Special case for length 1 ranges
            if (self.curr == self.end) {
                self.finished = true;
            }

            return @intCast(self.curr);
        }
        self.curr += self.direction;
        if (self.curr == self.end) {
            self.finished = true;
        }
        return @intCast(self.curr);
    }
};

const SeedRange = struct {
    start: usize,
    end: usize,
    pub fn iter(self: SeedRange) SeedIter {
        return SeedIter{ .curr = @intCast(self.start), .direction = if (self.start > self.end) -1 else 1, .end = @intCast(self.end) };
    }

    pub fn len(self: SeedRange) usize {
        return @abs(self.end - self.start) + 1;
    }
};

const TransformationStep = struct {
    source_start: usize,
    destination_start: usize,
    range: usize,

    pub fn transformMaybe(self: TransformationStep, source: usize) ?usize {
        if ((source >= self.source_start) and (source < self.source_start + self.range)) {
            return self.destination_start + (source - self.source_start);
        } else {
            return null;
        }
    }
};

const LineReader = helpers.FixedBufferLineReader(300);

fn transformationStepFromReader(line_reader: *LineReader) ?TransformationStep {
    if (line_reader.next()) |line| {
        if (std.mem.eql(u8, "", line)) {
            return null;
        }
        var tokenizer = std.mem.tokenizeScalar(u8, line, ' ');
        var ret_step: TransformationStep = undefined;
        if (tokenizer.next()) |str| {
            ret_step.destination_start = std.fmt.parseInt(usize, str, 10) catch unreachable;
        } else {
            return null;
        }

        if (tokenizer.next()) |str| {
            ret_step.source_start = std.fmt.parseInt(usize, str, 10) catch unreachable;
        } else {
            return null;
        }

        if (tokenizer.next()) |str| {
            ret_step.range = std.fmt.parseInt(usize, str, 10) catch unreachable;
        } else {
            return null;
        }

        return ret_step;
    } else {
        return null;
    }
}

fn seedRangesFromSeedLine(part2_method: bool, allocator: std.mem.Allocator, seeds_line: []const u8) ![]SeedRange {
    var seed_line_it = std.mem.splitSequence(u8, seeds_line, ": ");
    _ = seed_line_it.next() orelse {
        return GeneralErrors.UnexpectedFormat;
    };
    const just_seeds = seed_line_it.next() orelse {
        return GeneralErrors.UnexpectedFormat;
    };

    var ret_arr = std.ArrayList(SeedRange).init(allocator);
    defer ret_arr.deinit();

    var tokenizer = std.mem.tokenizeScalar(u8, just_seeds, ' ');

    if (part2_method) {
        while (true) {
            var start_seed: usize = undefined;
            var range: usize = undefined;
            if (tokenizer.next()) |val| {
                start_seed = try std.fmt.parseInt(usize, val, 10);
            } else {
                break;
            }
            if (tokenizer.next()) |val| {
                range = try std.fmt.parseInt(usize, val, 10);
            } else {
                // Seeds should always come in pairs of two
                return GeneralErrors.UnexpectedFormat;
            }
            try ret_arr.append(SeedRange{ .start = start_seed, .end = start_seed + range - 1 });
        }
    } else {
        while (tokenizer.next()) |num_str| {
            const start = try std.fmt.parseInt(usize, num_str, 10);
            try ret_arr.append(SeedRange{ .start = start, .end = start });
        }
    }

    return try ret_arr.toOwnedSlice();
}

fn scanUntilString(line_reader: *LineReader, string: []const u8) !void {
    while (line_reader.next()) |line| {
        if (std.mem.indexOf(u8, line, string)) |_| {
            return;
        }
    }
    return GeneralErrors.UnexpectedFormat;
}

fn calculateMinVal(part2_method: bool, allocator: std.mem.Allocator) !usize {
    var file_line_reader = try LineReader.fromAdventDay(5);
    defer file_line_reader.deinit();

    const seeds_line = file_line_reader.next() orelse {
        return GeneralErrors.UnexpectedFormat;
    };

    const debug_print_pipeline = false;

    const seed_arr = try seedRangesFromSeedLine(part2_method, allocator, seeds_line);
    defer allocator.free(seed_arr);

    const map_headers = .{ "seed-to-soil map:", "soil-to-fertilizer map:", "fertilizer-to-water map:", "water-to-light map:", "light-to-temperature map:", "temperature-to-humidity map:", "humidity-to-location map:" };

    // Collect all transformation steps
    var transformation_pipeline: [7]std.ArrayList(TransformationStep) = .{std.ArrayList(TransformationStep).init(allocator)} ** 7;
    defer {
        for (0..transformation_pipeline.len) |i| {
            transformation_pipeline[i].deinit();
        }
    }

    inline for (map_headers, 0..) |map_hdr, pipeline_idx| {
        try scanUntilString(&file_line_reader, map_hdr);

        while (transformationStepFromReader(&file_line_reader)) |step| {
            try transformation_pipeline[pipeline_idx].append(step);
        }
    }

    // Perform transformation on each seed
    var min_value: ?usize = null;

    var total_seeds: usize = 0;
    for (seed_arr) |seed_range| {
        total_seeds += seed_range.len();
    }

    std.log.debug("Total number of seeds: {d}\n", .{total_seeds});

    var seed_counter: usize = 0;
    var prev_pct_done: usize = 0;

    for (seed_arr) |seed_range| {
        var iter = seed_range.iter();
        while (iter.next()) |seed| {
            if (debug_print_pipeline) std.debug.print("Seed transformation pipeline: {d} => ", .{seed});
            seed_counter += 1;

            const tmp_seed_ctr: f64 = @floatFromInt(seed_counter);
            const tmp_seeds: f64 = @floatFromInt(total_seeds);
            const pct_done: usize = @intFromFloat((tmp_seed_ctr / tmp_seeds) * 100);
            if ((@mod(pct_done, 2) == 0) and (pct_done != prev_pct_done)) {
                if (!debug_print_pipeline) std.debug.print("Pct done: {d}\n", .{pct_done});
                prev_pct_done = pct_done;
            }
            var transform_source = seed;
            for (transformation_pipeline, 1..) |possible_steps, step_count| {
                var new_val = transform_source;
                for (possible_steps.items) |step| {
                    if (step.transformMaybe(transform_source)) |v| {
                        new_val = v;
                        break;
                    }
                }
                transform_source = new_val;
                if (step_count == transformation_pipeline.len) {
                    if (debug_print_pipeline) std.debug.print("{d}\n", .{transform_source});
                } else {
                    if (debug_print_pipeline) std.debug.print("{d} => ", .{transform_source});
                }
            }
            if (min_value) |v| {
                if (transform_source < v) {
                    min_value = transform_source;
                }
            } else {
                min_value = transform_source;
            }
        }
    }

    return min_value.?;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const method_arr = [_]bool{ false, true };
    for (method_arr) |part2_method| {
        const min_val = try calculateMinVal(part2_method, alloc);
        const part: usize = if (part2_method) 2 else 1;
        std.log.info("Minval: part{d}: {d}", .{ part, min_val });
    }

    std.debug.assert(!gpa.detectLeaks());
}
