//! `LeadIn` is basically a header that contains info about the rest of the file
const std = @import("std");

const Self = @This();

const TDSM_TAG = "TDSm";
const GOOD_VERSION = 4712;

toc_mask: ToC,
version: u32,
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
};

const LeadInError = error{
    IncorrectTDSmTag,
    InvalidVersion,
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
    .version = 0,
    .data_offset = 0,
    .next_segment = 0,
};

pub fn init(buf: []u8) LeadInError!Self {
    if (!std.mem.eql(u8, TDSM_TAG, buf[0..4])) return LeadInError.IncorrectTDSmTag;

    var result: Self = .empty;

    result.toc_mask = std.mem.bytesToValue(ToC, buf[4 .. 4 + @sizeOf(@TypeOf(result.toc_mask))]);
    result.version = std.mem.bytesToValue(u32, buf[8 .. 8 + @sizeOf(@TypeOf(result.version))]);
    result.next_segment = std.mem.bytesToValue(u32, buf[12 .. 12 + @sizeOf(@TypeOf(result.version))]);
    result.data_offset = std.mem.bytesToValue(u32, buf[20 .. 20 + @sizeOf(@TypeOf(result.version))]);

    if ((result.version == GOOD_VERSION) or (result.version == (GOOD_VERSION + 1))) return result else {
        std.log.err("Invalid Version: {d}!! Expected 4713 or 4712.\n", .{result.version});
        return LeadInError.InvalidVersion;
    }
}

test "size of LeadIn" {
    try std.testing.expectEqual(@sizeOf(Self), 24);
}
