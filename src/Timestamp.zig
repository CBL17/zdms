const std = @import("std");
const time = std.time;

const Self = @This();

fraction: u64,
seconds: i64,

const BASE_YEAR = 1904;
const BASE_MONTH = 1;
const BASE_DAY = 1;

pub const empty = Self{
    .seconds = 0,
    .fraction = 0,
};

pub fn init(sec: i64, decimal: f64) !Self {
    if (decimal >= 1) return Error.invalid_fraction;
    return Self{
        .seconds = sec,
        .fraction = @intFromFloat(decimal * (1 << 64)),
    };
}

pub fn getYear(self: Self) i64 {
    return BASE_YEAR + @divFloor(self.seconds, (60 * 60 * 24 * 365));
}

pub fn getMonth(self: Self) i64 {
    const year: i64 = self.getYear();
    var month: i64 = 1;
    var days_left = self.getDayInYear();

    while (true) {
        const days_in_month = getNumDaysInMonth(year, month);
        if (days_left < days_in_month) break;

        days_left -= days_in_month;
        month += 1;
    }
    return month;
}

pub fn getDayInMonth(self: Self) i64 {
    const year: i64 = self.getYear();
    var month: i64 = 1;
    var days_left = self.getDayInYear();

    while (true) {
        const days_in_month = getNumDaysInMonth(year, month);
        if (days_left < days_in_month) break;

        days_left -= days_in_month;
        month += 1;
    }
    return days_left + 1;
}

// number of days INTO the year (starting at 0)
pub fn getDayInYear(self: Self) i64 {
    var year: i64 = self.getYear();
    var day: i64 = @divFloor(self.seconds, (60 * 60 * 24));

    day = @mod(day, getDaysInYear(year));

    while (true) {
        const year_size = getDaysInYear(year);
        if (day < year_size)
            break;
        day -= year_size;
        year += 1;
    }

    return day;
}

pub fn getFractionalSeconds(self: Self) f64 {
    const fraction_f64 = @as(f64, @floatFromInt(self.fraction));
    const divisor_f64 = @as(f64, @floatFromInt(1 << 64));
    return fraction_f64 / divisor_f64;
}

pub fn getHours(self: Self) i64 {
    return @mod(@divFloor(self.seconds, (60 * 60)), 24);
}

pub fn getMinutes(self: Self) i64 {
    return @mod(@divFloor(self.seconds, (60)), 60);
}

pub fn getSeconds(self: Self) i64 {
    return @mod(self.seconds, 60);
}

pub fn getNumDaysInMonth(year: i64, month: i64) u5 {
    return switch (month) {
        1 => 31,
        2 => @as(u5, switch (isLeapYear(year)) {
            true => 29,
            false => 28,
        }),
        3 => 31,
        4 => 30,
        5 => 31,
        6 => 30,
        7 => 31,
        8 => 31,
        9 => 30,
        10 => 31,
        11 => 30,
        12 => 31,
        else => 0,
    };
}

pub fn format(
    self: @This(),
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;

    try writer.print("{d:0}/{d:0}/{d} {d:}:{d:0}:{d:05.3} UTC", .{
        self.getMonth(),
        self.getDayInMonth(),
        self.getYear(),
        self.getHours(),
        self.getMinutes(),
        @as(f64, @floatFromInt(self.getSeconds())) + self.getFractionalSeconds(),
    });
}

fn isLeapYear(year: i64) bool {
    if (@mod(year, 4) != 0)
        return false;
    if (@mod(year, 100) != 0)
        return true;
    return (0 == @mod(year, 400));
}

fn getDaysInYear(year: i64) u9 {
    return if (isLeapYear(year)) 366 else 365;
}

const Error = error{
    invalid_fraction,
};

test "init: empty" {
    const article = init(0, 0);

    try std.testing.expectEqual(Self.empty, article);
}

test "init: half decimal" {
    const article = init(-1, 0.5);

    try std.testing.expectEqual(Self{ .seconds = -1, .fraction = 0x8000_0000_0000_0000 }, article);
}

test "init: random decimal" {
    // 0.8 does not have a perfectly precise floating point representation so the number below
    // is used which is what the `init` function should approximate using a `f64` as input.
    const article = init(-6, 0.8);

    try std.testing.expectEqual(Self{ .seconds = -6, .fraction = 14757395258967642112 }, article);
}

test "getFractionalSeconds: half decimal" {
    const article = try init(-1, 0.5);

    try std.testing.expectEqual(0.5, article.getFractionalSeconds());
}

test getYear {
    const ts: Self = .{ .seconds = -6, .fraction = 0xCCCCCCCCCCCCCCCD };

    try std.testing.expectEqual(1903, getYear(ts));
}

test getDayInYear {
    const ts: Self = .{ .seconds = -6, .fraction = 0xCCCCCCCCCCCCCCCD };

    try std.testing.expectEqual(364, getDayInYear(ts));
}

test getMonth {
    const ts: Self = .{ .seconds = -6, .fraction = 0xCCCCCCCCCCCCCCCD };

    try std.testing.expectEqual(12, ts.getMonth());
}

test getDayInMonth {
    const ts: Self = .{ .seconds = -6, .fraction = 0xCCCCCCCCCCCCCCCD };

    try std.testing.expectEqual(31, ts.getDayInMonth());
}

test getHours {
    const ts: Self = .{ .seconds = -6, .fraction = 0xCCCCCCCCCCCCCCCD };

    try std.testing.expectEqual(23, ts.getHours());
}

test getMinutes {
    const ts: Self = .{ .seconds = -6, .fraction = 0xCCCCCCCCCCCCCCCD };

    try std.testing.expectEqual(59, ts.getMinutes());
}

test getSeconds {
    const ts: Self = .{ .seconds = -6, .fraction = 0xCCCCCCCCCCCCCCCD };

    try std.testing.expectEqual(54, ts.getSeconds());
}

test getFractionalSeconds {
    const ts: Self = .{ .seconds = -6, .fraction = 0xCCCCCCCCCCCCCCCD };

    try std.testing.expectEqual(0.8, ts.getFractionalSeconds());
}

test "getYear: epoch" {
    const ts: Self = .{ .seconds = 0, .fraction = 0 };

    try std.testing.expectEqual(1904, getYear(ts));
}

test "getDayInYear: epoch" {
    const ts: Self = .{ .seconds = 0, .fraction = 0 };

    try std.testing.expectEqual(0, getDayInYear(ts));
}

test "getMonth: epoch" {
    const ts: Self = .{ .seconds = 0, .fraction = 0 };

    try std.testing.expectEqual(1, ts.getMonth());
}

test "getDayInMonth: epoch" {
    const ts: Self = .{ .seconds = 0, .fraction = 0 };

    try std.testing.expectEqual(1, ts.getDayInMonth());
}

test "getHours: epoch" {
    const ts: Self = .{ .seconds = 0, .fraction = 0 };

    try std.testing.expectEqual(0, ts.getHours());
}

test "getMinutes: epoch" {
    const ts: Self = .{ .seconds = 0, .fraction = 0 };

    try std.testing.expectEqual(0, ts.getMinutes());
}

test "getSeconds: epoch" {
    const ts: Self = .{ .seconds = 0, .fraction = 0 };

    try std.testing.expectEqual(0, ts.getSeconds());
}
