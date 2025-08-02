const std = @import("std");

pub const metadata = @import("metadata.zig");
pub const LeadIn = @import("LeadIn.zig");
pub const Timestamp = @import("Timestamp.zig");

pub const TDMSFile = struct {
    name: []const u8,
    groups: std.MultiArrayList(Group),
    backing_data: []align(std.heap.page_size_min) u8,

    fn contains_group(self: *TDMSFile, group_name: []const u8) bool {
        for (0..self.groups.len) |i| {
            const existing_group = self.groups.get(i);
            if (std.mem.eql(u8, existing_group.name, group_name)) return true;
        }
        return false;
    }

    pub fn deinit(self: *TDMSFile, gpa: std.mem.Allocator) void {
        for (0..self.groups.len) |i| {
            var group = self.groups.get(i);
            group.deinit(gpa);
        }
        self.groups.deinit(gpa);
        std.posix.munmap(self.backing_data);
    }
};

pub const Group = struct {
    name: []const u8,
    properties: metadata.Object.PropertyList,
    channels: std.MultiArrayList(Channel),

    pub fn deinit(self: *Group, gpa: std.mem.Allocator) void {
        for (0..self.channels.len) |i| {
            var channel = self.channels.get(i);
            channel.deinit(gpa);
        }
        self.channels.deinit(gpa);
        self.properties.deinit(gpa);
    }
};

pub const Channel = struct {
    name: []const u8,
    properties: metadata.Object.PropertyList,

    pub fn deinit(self: *Channel, gpa: std.mem.Allocator) void {
        self.properties.deinit(gpa);
    }
};

const Section = struct {
    header: LeadIn,
    objects: metadata.ObjectList,

    pub fn deinit(self: *Section, gpa: std.mem.Allocator) void {
        for (0..self.objects.len) |i| {
            var object = self.objects.get(i);

            object.deinit(gpa);
        }
        self.objects.deinit(gpa);
    }
};
const SectionList = std.MultiArrayList(Section);

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

pub fn read_sections(
    buf: []u8,
    gpa: std.mem.Allocator,
) !SectionList {
    var groups: SectionList = .empty;

    var i: usize = 0;
    while (i < buf.len) {
        const group: Section = .{
            .header = try LeadIn.parse(buf[i..][0..28]),
            .objects = try metadata.parse(gpa, buf[i + 28 ..]),
        };
        try groups.append(gpa, group);
        i += 28;
        i += group.header.next_segment;
    }
    return groups;
}

pub fn read_file(gpa: std.mem.Allocator, path: []const u8) !TDMSFile {
    const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();

    const file_metadata = try file.metadata();

    const ptr = try std.posix.mmap(
        null,
        file_metadata.size(),
        std.posix.PROT.READ,
        .{ .TYPE = .SHARED },
        file.handle,
        0,
    );

    var sections = try read_sections(ptr, gpa);
    defer {
        for (0..sections.len) |i| {
            var section = sections.get(i);

            section.deinit(gpa);
        }
        sections.deinit(gpa);
    }

    var tdms_output: TDMSFile = .{
        .name = "",
        .groups = .empty,
        .backing_data = ptr,
    };
    for (0..sections.len) |i| {
        const s = sections.get(i);
        _ = s.header.data_offset;

        for (0..s.objects.len) |j| {
            const obj: metadata.Object = s.objects.get(j);

            const no_data = obj.data_index_tag == metadata.Object.DataIndexTag.no_data;
            const path_is_not_slash = !std.mem.eql(u8, obj.path, "/");

            if (no_data and path_is_not_slash) {
                // group

                var end: usize = 0;
                // assuming there is a '
                while (obj.path[2..][end] != '\'') : (end += 1) {}
                const name = obj.path[2..][0..end];

                if (!tdms_output.contains_group(name)) {
                    const group: Group = .{
                        .name = name,
                        .channels = .empty,
                        .properties = obj.properties,
                    };

                    try tdms_output.groups.append(gpa, group);
                }
                // channel
            } else if (path_is_not_slash) {
                var end: usize = 0;
                // assuming there is a '
                while (obj.path[2..][end] != '\'') : (end += 1) {}
                const group_name = obj.path[2..][0..end];
                // group could not exist?

                var group_index: usize = 0;
                var channel_group_name = tdms_output.groups.get(group_index).name;
                while (!std.mem.eql(u8, channel_group_name, group_name)) {
                    group_index += 1;
                    channel_group_name = tdms_output.groups.get(group_index).name;
                }

                var ch_end: usize = 0;
                while (obj.path[end + 5 ..][ch_end] != '\'') : (ch_end += 1) {}
                const channel_name = obj.path[end + 5 ..][0..ch_end];

                const channel: Channel = .{
                    .name = channel_name,
                    .properties = .empty,
                };
                try tdms_output.groups.items(.channels)[group_index].append(gpa, channel);
            }
        }
    }
    return tdms_output;
}

test {
    _ = @import("metadata.zig");
    _ = @import("LeadIn.zig");
    _ = @import("Timestamp.zig");
}
