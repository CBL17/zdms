//! Unfortunately this johnson needs broken into more files most likely
//! I am a big 'test where your code is' kinda bro so these files are
//! gonna get much longer thus the need for more
//!
//! It will work pretty simply with how this one is spread out rn

const std = @import("std");
pub const metadata = @import("metadata.zig");
pub const LeadIn = @import("LeadIn.zig");

const MultiArrayList = std.MultiArrayList;

/// TDMS supported datatypes
pub const DataType = enum(u32) {
    void = 0,
    i8 = 1,
    i16 = 2,
    i32 = 3,
    i64 = 4,
    u8 = 5,
    u16 = 6,
    u32 = 7,
    u64 = 8,
    float = 9,
    double = 10,
    extended_float = 11,
    float_unit = 0x19,
    double_unit,
    extended_float_unit,
    string = 0x20,
    bool = 0x21,
    /// a `timestamp` in LabView is actually a `{ i64, u64 }` where the former represents
    /// seconds since 1/1/1904 00:00:00.00 UTC and the latter is fractions of a second
    timestamp = 0x44,
    fixed_point = 0x4F,
    complex_float = 0x08000C,
    complex_double = 0x10000D,
    raw_data = 0xFFFFFFFF,

    pub fn size_of(self: DataType) DataTypeError!u32 {
        return switch (self) {
            .void => 0,
            .i8, .u8, .bool => 1,
            .i16, .u16 => 2,
            .i32, .u32, .float, .float_unit => 4,
            .i64, .u64, .double, .double_unit, .fixed_point, .complex_float => 8,
            .timestamp, .extended_float, .extended_float_unit, .complex_double => 16,
            .string, .raw_data => DataTypeError.UnsupportedDataType,
        };
    }
};

pub const DataTypeError = error{
    UnsupportedDataType,
};

const Group = struct {
    header: LeadIn,
    objects: metadata.ObjectList,
};

const GroupList = MultiArrayList(Group);

pub fn read_groups(
    buf: []u8,
    gpa: std.mem.Allocator,
) !GroupList {
    var groups: GroupList = .empty;

    var i: usize = 0;
    while (i < buf.len) {
        const group: Group = .{
            .header = try LeadIn.parse(buf[i..][0..28]),
            .objects = try metadata.parse(gpa, buf[i + 28 ..]),
        };
        try groups.append(gpa, group);
        i += 28;
        i += group.header.next_segment;
    }
    return groups;
}

test {
    _ = @import("metadata.zig");
    _ = @import("LeadIn.zig");
}
