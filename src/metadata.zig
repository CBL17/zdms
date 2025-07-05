//! `MetaData` contains a three-level hierachy of objects including a file,
//! groups, and channels. Each one of these object types can include any
//! number of properties.
const std = @import("std");

const tdms = @import("tdms.zig");
const DataType = tdms.DataType;

pub const ObjectList = std.MultiArrayList(Object);

const Self = @This();

pub const Object = struct {
    // path len is the first 4 bytes but can be encapsulated in the slice
    path: []const u8,
    data_index_tag: DataIndexTag,
    data_index: DataIndex,
    num_properties: u32,
    properies: Properties,

    const Properties = std.MultiArrayList(Property);

    const DataIndexTag = enum(u32) {
        no_data = 0xFFFFFFFF,
        same_as_previous = 0x0,
        format_changing = 0x69120000,
        digital_line = 0x69130000,
        new_index,
    };

    const DataIndex = struct {
        index_size: u32,
        dt: DataType,
        /// In TDMS file format version 2.0, 1 is the only valid value
        dim: u32,
        /// Number of items in a chunk
        length: u64,
        /// Only stored for variable-length data types (i.e. strings)
        size: u64 = 0,

        pub const empty = DataIndex{
            .index_size = 0,
            .dt = .void,
            .dim = 0,
            .length = 0,
            .size = 0,
        };
    };

    const Property = struct {
        name: []const u8,
        dt: DataType,
        value: []u8,

        pub fn parse(buf: []u8, index: *usize) Property {
            var i = index.*;
            defer index.* = i;

            const name_length = std.mem.bytesToValue(u32, buf[i..][0..@sizeOf(u32)]);
            i += @sizeOf(u32);

            const name = buf[i..][0..name_length];
            i += name_length;

            const data_type: DataType = @enumFromInt(std.mem.bytesToValue(u32, buf[i..][0..@sizeOf(u32)]));
            i += @sizeOf(u32);

            const property_length = switch (data_type) {
                .string => blk: {
                    defer i += @sizeOf(u32);
                    break :blk std.mem.bytesToValue(u32, buf[i..][0..@sizeOf(u32)]);
                },
                .double => 8,
                else => 4,
            };

            const property = buf[i..][0..property_length];
            i += property_length;

            return Property{
                .name = name,
                .dt = data_type,
                .value = property,
            };
        }

        pub fn format(
            self: @This(),
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = options;
            _ = fmt;

            try writer.print("{s}: ", .{self.name});
            switch (self.dt) {
                .bool => try writer.print("{b}", .{self.value}),
                .i8,
                .i16,
                .i32,
                .i64,
                .u8,
                .u16,
                .u32,
                .u64,
                => try writer.print("{d}", .{std.mem.bytesToValue(u64, self.value)}),
                .float,
                .float_unit,
                .double,
                .double_unit,
                .fixed_point,
                => try writer.print("{d}", .{std.mem.bytesToValue(f64, self.value)}),

                .string => try writer.print("{s}", .{self.value}),
                .complex_float, .timestamp, .extended_float, .extended_float_unit, .complex_double, .void, .raw_data => unreachable,
            }
        }
    };

    pub const empty = Object{
        .properies = Properties.empty,
        .data_index_tag = .no_data,
        .path = "",
        .data_index = DataIndex.empty,
        .num_properties = 0,
    };

    pub fn parse(allocator: std.mem.Allocator, buf: []u8, index: *usize) anyerror!Object {
        var i: usize = index.*;
        defer index.* = i;

        const size = std.mem.bytesToValue(u32, buf[i..][0..@sizeOf(u32)]);
        i += @sizeOf(u32);

        const path = buf[i..][0..size];
        i += size;

        const len_data_index_value = std.mem.bytesToValue(u32, buf[i..][0..@sizeOf(DataIndexTag)]);
        i += @sizeOf(DataIndexTag);

        const data_index_tag = std.enums.fromInt(DataIndexTag, len_data_index_value);

        if (data_index_tag) |tag| {
            return switch (tag) {
                .no_data => {
                    const num_properties = std.mem.bytesToValue(u32, buf[i..][0..@sizeOf(u32)]);
                    i += @sizeOf(u32);

                    var properties: Properties = .empty;
                    var property_index: usize = 0;
                    for (0..num_properties) |_| {
                        try properties.append(allocator, Property.parse(buf[i..], &property_index));
                    }

                    i += property_index;

                    return Object{
                        .properies = Properties.empty,
                        .num_properties = 0,
                        .path = path,
                        .data_index_tag = .no_data,
                        .data_index = DataIndex{
                            .index_size = len_data_index_value,
                            .dt = .void,
                            .dim = 0,
                            .length = 0,
                        },
                    };
                },
                .same_as_previous,
                .format_changing,
                .digital_line,
                => @panic("unsported shit detectorino"),
                .new_index => unreachable,
            };
        } else {
            const dt: DataType = @enumFromInt(std.mem.bytesToValue(u32, buf[i..][0..@sizeOf(DataType)]));
            i += @sizeOf(DataType);

            const dim = std.mem.bytesToValue(u32, buf[i..][0..@sizeOf(u32)]);
            i += @sizeOf(u32);

            const length = std.mem.bytesToValue(u64, buf[i..][0..@sizeOf(u64)]);
            i += @sizeOf(u64);

            // Variable length data types (strings) have their total size stored here

            const num_properties = std.mem.bytesToValue(u32, buf[i..][0..@sizeOf(u32)]);
            i += @sizeOf(u32);

            var properties: Properties = .empty;

            var property_index: usize = 0;
            for (0..num_properties) |_| {
                try properties.append(allocator, Property.parse(buf[i..], &property_index));
            }
            i += property_index;

            switch (dt) {
                .string => std.log.err("No support for strings atm\n", .{}),
                .raw_data => std.log.err("No support for daqmx raw data atm\n", .{}),
                else => {},
            }

            return Object{
                .properies = properties,
                .num_properties = num_properties,
                .path = path,
                .data_index_tag = .new_index,
                .data_index = DataIndex{
                    .index_size = len_data_index_value,
                    .dt = dt,
                    .dim = dim,
                    .length = length,
                },
            };
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

        try writer.print("Path: {s}\n", .{self.path});
        for (0..self.num_properties) |i| {
            try writer.print("{s}\n", .{self.properies.get(i)});
        }
    }
};

pub fn parse(allocator: std.mem.Allocator, buf: []u8) anyerror!ObjectList {
    const num_objs = std.mem.bytesToValue(u32, buf[0..4]);
    var obj_list = ObjectList{};

    var index: usize = 0;
    for (0..num_objs) |_| {
        try obj_list.append(allocator, try Object.parse(allocator, buf[4..], &index));
    }

    return obj_list;
}

pub fn format(
    self: @This(),
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;
    _ = fmt;

    for (0..self.num_objects) |i| {
        try writer.print("{s}\n", .{self.object_list.get(i)});
    }
}
