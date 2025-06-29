//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const std = @import("std");
const fs = std.fs;
const io = std.io;

const tdms = @import("tdms.zig");
const LeadIn = tdms.LeadIn;

const dba: std.heap.DebugAllocator = .init;
const allocator = dba.allocator();

pub fn main() !void {
    const file = try fs.cwd().openFile("DataLog_2024-0501-0031-41_CMS_Data_Wiring_5.tdms", .{});
    defer file.close();

    const metadata = try file.metadata();
    const size = metadata.size();

    var buf: [4 + @sizeOf(LeadIn)]u8 = undefined;
    std.debug.assert(try file.read(&buf) == 4 + @sizeOf(LeadIn));
    const bruh = try LeadIn.init(buf);
    std.debug.print("version: {d}\n", .{bruh.version});
    std.debug.print("next_seg: {d}\n", .{bruh.next_segment});
    std.debug.print("offset: {d}\n", .{bruh.data_offset});
    std.debug.print("file size: {d}\n", .{size});
    std.debug.print("raw data: {s}\n", .{u1ToBoolString(bruh.toc_mask.raw_data)});
    std.debug.print("big endian: {s}\n", .{u1ToBoolString(bruh.toc_mask.big_endian)});
    std.debug.print("daqmx data: {s}\n", .{u1ToBoolString(bruh.toc_mask.daqmx_data)});
    std.debug.print("interleaved: {s}\n", .{u1ToBoolString(bruh.toc_mask.interleaved)});
    std.debug.print("new object list: {s}\n", .{u1ToBoolString(bruh.toc_mask.new_obj_list)});
    std.debug.print("contains metadata: {s}\n", .{u1ToBoolString(bruh.toc_mask.contains_meta_data)});
    std.debug.print("leadin: {d}\n", .{@sizeOf(LeadIn)});
}

fn u1ToBoolString(value: u1) []const u8 {
    return if (value == 1) "true" else "false";
}

test {
    _ = @import("tdms.zig");
}
