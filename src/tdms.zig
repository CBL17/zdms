//! Unfortunately this johnson needs broken into more files most likely
//! I am a big 'test where your code is' kinda bro so these files are
//! gonna get much longer thus the need for more
//!
//! It will work pretty simply with how this one is spread out rn

const std = @import("std");
pub const MetaData = @import("MetaData.zig");
pub const LeadIn = @import("LeadIn.zig");
pub const utils = @import("utils.zig");

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
};

pub const DataTypeError = error{
    UnsupportedDataType,
};

pub fn format_specifier(dt: DataType) DataTypeError!u32 {
    return switch (dt) {
        .bool => 'b',
        .i8, .i16, .i32, .i64, .u8, .u16, .u32, .u64 => 'd',
        .float, .float_unit, .double, .double_unit, .fixed_point => 'd',
        .string => 's',
        .complex_float, .timestamp, .extended_float, .extended_float_unit, .complex_double, .void, .string, .raw_data => DataTypeError.UnsupportedDataType,
    };
}

pub fn size_of(dt: DataType) DataTypeError!u32 {
    return switch (dt) {
        .void => 0,
        .i8, .u8, .bool => 1,
        .i16, .u16 => 2,
        .i32, .u32, .float, .float_unit => 4,
        .i64, .u64, .double, .double_unit, .fixed_point, .complex_float => 8,
        .timestamp, .extended_float, .extended_float_unit, .complex_double => 16,
        .string, .raw_data => DataTypeError.UnsupportedDataType,
    };
}

test {
    _ = @import("MetaData.zig");
    _ = @import("LeadIn.zig");
}
