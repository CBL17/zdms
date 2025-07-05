//! `LeadIn` is basically a header that contains info about the rest of the file
const std = @import("std");

const Self = @This();

const u1Stringify = @import("utils.zig").u1ToBoolStr;

const TDSM_TAG = "TDSm";

const Version = enum(u32) {
    VERSION_1 = 4712,
    VERSION_2 = 4713,

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("Version: {s}\n", .{if (self.version == .VERSION_1) "TDMS 1.0" else "TDMS 2.0"});
    }
};

toc_mask: ToC,
version: Version,
/// Represents offset to next segment
///
/// If `next_segment` equals 0xFFFFFFFF, the writer encountered some kind
/// of error. This only occurs for the last segment in a file.
next_segment: u64,
/// Represents the size of the metadata
///
/// Offsetting from it's address + itself + the size of itself (8 bytes)
/// is the start of the raw data section
data_offset: u64,

// by spec, always little endian
/// Table of Contents
const ToC = packed struct {
    _padding_1: u1 = 0,
    contains_meta_data: u1,
    new_obj_list: u1,
    raw_data: u1,
    _padding_2: u1 = 0,
    interleaved: u1,
    big_endian: u1,
    daqmx_data: u1,
    _padding_0: u24 = 0,

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;
        _ = fmt;

        try writer.print("Contains meta data: {s}\n", .{u1Stringify(self.contains_meta_data)});
        try writer.print("New object list: {s}\n", .{u1Stringify(self.new_obj_list)});
        try writer.print("Contains raw data: {s}\n", .{u1Stringify(self.raw_data)});
        try writer.print("Contains DAQmx raw data: {s}\n", .{u1Stringify(self.daqmx_data)});
        try writer.print("Raw data is interleaved: {s}\n", .{u1Stringify(self.interleaved)});
        try writer.print("Endianess: {s}", .{if (self.big_endian == 1) "big" else "little"});
    }
};

const LeadInError = error{
    IncorrectTDSmTag,
    InvalidVersion,
    BufferTooSmall,
};

const empty = Self{
    .toc_mask = .{
        .raw_data = 0,
        .big_endian = 0,
        .daqmx_data = 0,
        .interleaved = 0,
        .new_obj_list = 0,
        .contains_meta_data = 0,
    },
    .version = .VERSION_1,
    .data_offset = 0,
    .next_segment = 0,
};

pub fn parse(buf: []u8) LeadInError!Self {
    if (buf.len < @sizeOf(Self)) return LeadInError.BufferTooSmall;

    if (!std.mem.eql(u8, TDSM_TAG, buf[0..4])) return LeadInError.IncorrectTDSmTag;

    var result: Self = .empty;

    result.toc_mask = std.mem.bytesToValue(ToC, buf[4 .. 4 + @sizeOf(@TypeOf(result.toc_mask))]);

    const version_number = std.mem.bytesToValue(u32, buf[8 .. 8 + @sizeOf(@TypeOf(result.version))]);
    result.version = std.enums.fromInt(
        Version,
        version_number,
    ).?;
    result.next_segment = std.mem.bytesToValue(u32, buf[12 .. 12 + @sizeOf(@TypeOf(result.version))]);
    result.data_offset = std.mem.bytesToValue(u32, buf[20 .. 20 + @sizeOf(@TypeOf(result.version))]);

    if ((result.version == .VERSION_1) or (result.version == .VERSION_2)) return result else {
        std.log.err("Invalid Version: {d}!! Expected 4713 or 4712.\n", .{version_number});
        return LeadInError.InvalidVersion;
    }
}

pub fn format(
    self: @This(),
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;
    _ = fmt;

    try writer.print("{s}\n", .{self.toc_mask});
    try writer.print("{s}\n", .{self.version});
    try writer.print("Next Segment: +{d}\n", .{self.next_segment});
    try writer.print("Data Segment: +{d}", .{self.data_offset});
}

test "size of LeadIn" {
    try std.testing.expectEqual(@sizeOf(Self), 24);
}

test "buffer too small" {
    var buf: [12]u8 = [_]u8{0} ** 12;

    try std.testing.expectError(LeadInError.BufferTooSmall, Self.parse(&buf));
}
