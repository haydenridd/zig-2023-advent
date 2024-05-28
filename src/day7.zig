const std = @import("std");
const helpers = @import("helpers");
const FileLineReader = helpers.FileLineReader;
const GeneralErrors = helpers.GeneralErrors;

const HandType = enum(u8) { HighCard = 0, OnePair = 1, TwoPair = 2, ThreeOfAKind = 3, FullHouse = 4, FourOfAKind = 5, FiveOfAKind = 6 };

const VALID_RANKED_CARDS_PT1 = "AKQJT98765432";
const VALID_RANKED_CARDS_PT2 = "AKQT98765432J";

fn HandVariantForPart(comptime part: u8) type {
    const pt2 = part != 1;
    return struct {
        cards: [5]u8,
        bid: u64,
        hand_type: HandType,
        const Self = @This();
        pub fn fromSlice(slice: []const u8) !Self {
            var hand: Self = Self{ .cards = .{0} ** 5, .bid = 0, .hand_type = .HighCard };
            var slice_tok = std.mem.tokenizeAny(u8, slice, " ");
            const card_slice = slice_tok.next() orelse {
                return GeneralErrors.UnexpectedFormat;
            };
            if (card_slice.len != hand.cards.len) {
                return GeneralErrors.UnexpectedFormat;
            }
            std.mem.copyForwards(u8, &hand.cards, card_slice);

            const bid_slice = slice_tok.next() orelse {
                return GeneralErrors.UnexpectedFormat;
            };
            hand.bid = try std.fmt.parseInt(u64, bid_slice, 10);
            hand.hand_type = try determineHand(hand.cards);
            return hand;
        }

        pub fn compare(self: Self, other: Self) std.math.Order {
            if (@intFromEnum(self.hand_type) > @intFromEnum(other.hand_type)) {
                return .gt;
            } else if (@intFromEnum(self.hand_type) < @intFromEnum(other.hand_type)) {
                return .lt;
            } else {
                for (self.cards, other.cards) |cs, co| {
                    const self_idx = std.mem.indexOfScalar(u8, if (pt2) VALID_RANKED_CARDS_PT2 else VALID_RANKED_CARDS_PT1, cs).?;
                    const other_idx = std.mem.indexOfScalar(u8, if (pt2) VALID_RANKED_CARDS_PT2 else VALID_RANKED_CARDS_PT1, co).?;
                    if (self_idx < other_idx) {
                        return .gt;
                    } else if (self_idx > other_idx) {
                        return .lt;
                    }
                }
                return .eq;
            }
        }

        // For sorting
        pub fn lessThan(_: @TypeOf(.{}), lhs: Self, rhs: Self) bool {
            return lhs.compare(rhs) == .lt;
        }

        fn determineHand(cards: [5]u8) !HandType {
            // Sanitize
            for (cards) |c| {
                if (std.mem.indexOfScalar(u8, VALID_RANKED_CARDS_PT1, c)) |_| {} else {
                    return GeneralErrors.UnexpectedFormat;
                }
            }

            // Determine highest rank
            var already_visited = try std.BoundedArray(u8, 5).init(0);

            // Special logic for jacks
            var jack_count: usize = 0;
            if (pt2) {
                jack_count = std.mem.count(u8, &cards, "J");
                if (jack_count > 0) {
                    try already_visited.append('J');
                }
            }

            var counts = try std.BoundedArray(usize, 5).init(0);
            for (cards) |card| {
                if (std.mem.indexOfScalar(u8, already_visited.slice(), card)) |_| {} else {
                    const card_count = std.mem.count(u8, &cards, &[1]u8{card});
                    try already_visited.append(card);
                    try counts.append(card_count);
                }
            }

            // Edge case for 5 jacks
            if (jack_count == 5) {
                return .FiveOfAKind;
            }

            var max_count = std.mem.max(usize, counts.slice());
            const max_idx = std.mem.indexOfScalar(usize, counts.slice(), max_count).?;
            max_count += jack_count;
            counts.slice()[max_idx] = max_count;

            switch (max_count) {
                5 => {
                    return .FiveOfAKind;
                },
                4 => {
                    return .FourOfAKind;
                },
                3 => {
                    if (std.mem.indexOfScalar(usize, counts.slice(), 2)) |_| {
                        return .FullHouse;
                    } else {
                        return .ThreeOfAKind;
                    }
                },
                2 => {
                    if (std.mem.count(usize, counts.slice(), &[1]usize{2}) > 1) {
                        return .TwoPair;
                    } else {
                        return .OnePair;
                    }
                },
                1 => {
                    return .HighCard;
                },
                else => {
                    return GeneralErrors.UnexpectedFormat;
                },
            }
        }

        pub fn format(
            self: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;

            try writer.print("Cards: {s} Type: {any} Bid: {d}", .{ self.cards, self.hand_type, self.bid });
        }
    };
}

test "determineHand" {
    const Hand = HandVariantForPart(1);
    try std.testing.expectEqual(HandType.FiveOfAKind, Hand.determineHand(.{'5'} ** 5) catch unreachable);
    try std.testing.expectEqual(HandType.FourOfAKind, Hand.determineHand(.{'4'} ** 4 ++ .{'3'}) catch unreachable);
    try std.testing.expectEqual(HandType.FullHouse, Hand.determineHand(.{'4'} ** 3 ++ .{'2'} ** 2) catch unreachable);
    try std.testing.expectEqual(HandType.ThreeOfAKind, Hand.determineHand(.{'4'} ** 3 ++ .{ '2', 'A' }) catch unreachable);
    try std.testing.expectEqual(HandType.TwoPair, Hand.determineHand(.{'4'} ** 2 ++ .{ '2', '2', 'A' }) catch unreachable);
    try std.testing.expectEqual(HandType.OnePair, Hand.determineHand(.{'4'} ** 2 ++ .{ '3', '2', 'A' }) catch unreachable);
    try std.testing.expectEqual(HandType.HighCard, Hand.determineHand(.{ '5', '4', '3', '2', 'A' }) catch unreachable);
}

test "Hand" {
    const Hand = HandVariantForPart(1);
    const slice = "32T3K 765";
    const hand = try Hand.fromSlice(slice);
    try std.testing.expectEqualStrings("32T3K", &hand.cards);
    try std.testing.expectEqual(765, hand.bid);
    try std.testing.expectEqual(.OnePair, hand.hand_type);
}

test "Hand comparison" {
    const Hand = HandVariantForPart(1);
    try std.testing.expectEqual(std.math.Order.eq, (try Hand.fromSlice("32T3K 765")).compare((try Hand.fromSlice("32T3K 765"))));
    try std.testing.expectEqual(std.math.Order.gt, (try Hand.fromSlice("33T3K 765")).compare((try Hand.fromSlice("32T3K 765"))));
    try std.testing.expectEqual(std.math.Order.gt, (try Hand.fromSlice("77888 765")).compare((try Hand.fromSlice("77788 765"))));
}

test "Hand sorting" {
    const Hand = HandVariantForPart(1);
    var hand_arr = [_]Hand{ try Hand.fromSlice("32T3K 765"), try Hand.fromSlice("3333K 765"), try Hand.fromSlice("3223K 765") };
    std.mem.sort(Hand, &hand_arr, .{}, Hand.lessThan);
    try std.testing.expectEqual(try Hand.fromSlice("32T3K 765"), hand_arr[0]);
    try std.testing.expectEqual(try Hand.fromSlice("3223K 765"), hand_arr[1]);
    try std.testing.expectEqual(try Hand.fromSlice("3333K 765"), hand_arr[2]);

    const HandPt2 = HandVariantForPart(2);
    var hand_arr2 = [_]HandPt2{
        try HandPt2.fromSlice("32T3K 765"),
        try HandPt2.fromSlice("T55J5 684"),
        try HandPt2.fromSlice("KK677 28"),
        try HandPt2.fromSlice("KTJJT 220"),
        try HandPt2.fromSlice("QQQJA 483"),
    };
    std.mem.sort(HandPt2, &hand_arr2, .{}, HandPt2.lessThan);
    try std.testing.expectEqual(try HandPt2.fromSlice("32T3K 765"), hand_arr2[0]);
    try std.testing.expectEqual(try HandPt2.fromSlice("KK677 28"), hand_arr2[1]);
    try std.testing.expectEqual(try HandPt2.fromSlice("T55J5 684"), hand_arr2[2]);
    try std.testing.expectEqual(try HandPt2.fromSlice("QQQJA 483"), hand_arr2[3]);
    try std.testing.expectEqual(try HandPt2.fromSlice("KTJJT 220"), hand_arr2[4]);
}

fn calculateAnswer(HandVariant: type, allocator: std.mem.Allocator, file_line_reader: *FileLineReader) !u64 {
    var hand_arr = std.ArrayList(HandVariant).init(allocator);
    defer hand_arr.deinit();
    while (file_line_reader.next()) |line| {
        try hand_arr.append(try HandVariant.fromSlice(line));
    }
    const hand_slice = try hand_arr.toOwnedSlice();
    defer allocator.free(hand_slice);
    std.mem.sort(HandVariant, hand_slice, .{}, HandVariant.lessThan);
    var answer: u64 = 0;
    for (hand_slice, 1..) |item, rank| {
        answer += rank * item.bid;
        if (HandVariant == HandVariantForPart(2)) {
            std.debug.print("Hand: {any}\n", .{item});
        }
    }
    return answer;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    inline for (1..3) |part| {
        var file_line_reader = try helpers.lineReaderFromAdventDay(7, alloc);
        defer file_line_reader.deinit();
        const answer = try calculateAnswer(HandVariantForPart(part), alloc, &file_line_reader);
        std.debug.print("Answer part {d}: {d}\n", .{ part, answer });
    }

    std.debug.assert(!gpa.detectLeaks());
}
