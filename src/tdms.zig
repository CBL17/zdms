const std = @import("std");

pub const metadata = @import("metadata.zig");
pub const LeadIn = @import("LeadIn.zig");
pub const Timestamp = @import("Timestamp.zig");

pub const Group = struct {
    header: LeadIn,
    objects: metadata.ObjectList,
};

pub const GroupList = std.MultiArrayList(Group);

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
    // f32
    float = 9,
    // f64
    double = 10,
    extended_float = 11,
    /// From docs: "LabVIEW floating-point types with unit translate into
    /// a floating-point channel with a property named unit_string that
    /// contains the unit as a string."
    float_unit = 0x19,
    /// From docs: "LabVIEW floating-point types with unit translate into
    /// a floating-point channel with a property named unit_string that
    /// contains the unit as a string."
    double_unit,
    /// From docs: "LabVIEW floating-point types with unit translate into
    /// a floating-point channel with a property named unit_string that
    /// contains the unit as a string."
    extended_float_unit,
    string = 0x20,
    bool = 0x21,
    /// a `timestamp` in LabView is actually a `{ i64, u64 }` where the former represents
    /// seconds since 1/1/1904 00:00:00.00 UTC and the latter is fractions of a second
    timestamp = 0x44,
    fixed_point = 0x4F,
    /// just two f32s for the real and imaginary parts.
    complex_float = 0x08000C,
    /// just two f64s for the real and imaginary parts.
    complex_double = 0x10000D,
    /// some overly complicated shit that I haven't implemented yet.
    raw_data = 0xFFFFFFFF,

    pub const DataTypeError = error{
        UnsupportedDataType,
    };

    /// Returns the size of a particular data type. Error is returned on variable sized
    /// data types (strings) or unimplemented data types.
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
    _ = @import("Timestamp.zig");
}
