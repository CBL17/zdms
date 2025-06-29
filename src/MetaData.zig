//! `MetaData` contains a three-level hierachy of objects including a file,
//! groups, and channels. Each one of these object types can include any
//! number of properties.
const std = @import("std");

const tdms = @import("tdms.zig");
const DataType = tdms.DataType;

const ObjectList = std.MultiArrayList(Object);

const Self = @This();
num_objects: u32,
object_list: []ObjectList,

/// Occurs when `num_objects == 0`
const MIN_SIZE = 4;

const Object = extern struct {
    // path len is the first 4 bytes but can be encapsulated in the slice
    path: []const u8,
    data_index_tag: DataIndexTag,
    data_index: DataIndex,
    num_properties: u32,

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
        length: u64,
        /// Only stored for variable-length data types (i.e. strings)
        size: u64 = 0,
    };

    const Property = struct {
        name: []const u8,
        dt: DataType,
        value: []u8,
    };

    pub fn init(buf: []u8) Object {
        var index = 0;
        const size = @as(u32, buf[index .. index + @sizeOf(u32)]);
        index += @sizeOf(u32);

        const path = buf[index .. index + size];
        index += size;

        const data_index_tag = DataIndexTag(@as(u32, buf[index .. index + @sizeOf(DataIndexTag)]));
        index += @sizeOf(DataIndexTag);

        return switch (data_index_tag) {
            .no_data => void,
            .same_as_previous,
            .format_changing,
            .digital_line,
            => std.log.err("Unsupported data index detected: {}", .{data_index_tag}),
            // new_index
            else => blk: {
                // this is the only case in which those 4 bytes mean anything besides a tag
                const len_data_index = @intFromEnum(data_index_tag);

                const dt = DataType(@as(u32, buf[index .. index + @sizeOf(DataType)]));
                index += @sizeOf(DataType);

                const dim = @as(u32, buf[index .. index + @sizeOf(u32)]);
                index += @sizeOf(u32);

                const length = @as(u64, buf[index .. index + @sizeOf(u64)]);

                switch (dt) {
                    .string => std.log.err("No support for strings atm\n", .{}),
                    else => {},
                }
                break :blk Object{
                    .path = path,
                    .data_index_tag = data_index_tag,
                    .data_index = DataIndex{
                        .index_size = len_data_index,
                        .dt = dt,
                        .dim = dim,
                        .length = length,
                    },
                };
            },
        };
    }
};
