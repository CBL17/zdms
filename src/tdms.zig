//! Unfortunately this johnson needs broken into more files most likely
//! I am a big 'test where your code is' kinda bro so these files are
//! gonna get much longer thus the need for more
//!
//! It will work pretty simply with how this one is spread out rn

const std = @import("std");
const MetaData = @import("MetaData.zig");
const LeadIn = @import("LeadIn.zig");

const MultiArrayList = std.MultiArrayList;

/// TDMS supported datatypes
pub const DataType = enum(u32) {
    void,
    i8,
    i16,
    i32,
    i64,
    u8,
    u16,
    u32,
    u64,
    float,
    double,
    extended_float,
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

pub fn size_of(comptime dt: DataType) DataTypeError!u32 {
    return switch (dt) {
        .i8, .u8, .bool => 1,
        .i16, .u16 => 2,
        .i32, .u32, .float, .float_unit => 4,
        .i64, .u64, .double, .double_unit, .fixed_point, .complex_float => 8,
        .timestamp, .extended_float, .extended_float_unit, .complex_double => 16,
        .void, .string, .raw_data => DataTypeError,
    };
}

pub fn dt_to_type(comptime dt: DataType) DataTypeError!type {
    switch (dt) {
        .void => void,
        .bool => bool,
        .i8 => i8,
        .i16 => i16,
        .i32 => i32,
        .i64 => i64,
        .u8 => u8,
        .u16 => u16,
        .u32 => u32,
        .u64 => u64,
        .float => f32,
        .double => f64,
        .extended_float => f128,
        .float_unit,
        .double_unit,
        .extended_float_unit,
        .string,
        .timestamp,
        .fixed_point,
        .complex_float,
        .complex_double,
        .raw_data,
        => DataTypeError.UnsupportedDataType,
    }
}

// im thinking that the goal of RawData is to encapsulate
// everything in the Raw Data section. This doesn't mean
// it has to store it, it can just have methods and tools
// for parsing
const RawData = struct {
    const Self = @This();

    dt: DataType,
    dimension: u64,
    length: u64,
    size: u64,

    pub fn init(dt: DataType, dim: u64, length: u64) !void {
        const d = Self{
            .dt = dt,
            .dimension = dim,
            .length = length,
            .size = size_of(dt) * dim * length,
        };

        // if (header.toc_mask.interleaved) {
        //     std.log.warn("Interleaved data parsing not implemented!\n", .{});
        // } else {}

        return d;
    }
};

pub fn init(buf: []const u8) anyerror!void {
    buf;
}

test {
    _ = @import("MetaData.zig");
    _ = @import("LeadIn.zig");
}
