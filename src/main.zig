//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");
const fs = std.fs;
const io = std.io;

const tdms = @import("tdms.zig");
const LeadIn = tdms.LeadIn;
const MetaData = tdms.MetaData;

const get_data = @import("data.zig").read_data;

var dba = std.heap.DebugAllocator(.{ .safety = true }).init;
const allocator = dba.allocator();

pub fn main() !void {
    const file = try fs.cwd().openFile("DataLog_2024-0501-0031-41_CMS_Data_Wiring_5.tdms", .{});
    // const file = try fs.cwd().openFile("large.tdms", .{});
    defer file.close();

    var buf = try file.readToEndAlloc(allocator, 10000000000);

    const l = try LeadIn.init(buf[0..28]);
    const md = try MetaData.init(dba.allocator(), buf[@sizeOf(LeadIn) + 4 ..]);

    const data = try get_data(buf, "tc-fu-04", &(md.object_list), &(l));
    std.debug.print("{d}\n", .{data.len});
}

test {
    _ = @import("tdms.zig");
}
