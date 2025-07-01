//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");
const fs = std.fs;
const io = std.io;

const tdms = @import("tdms.zig");
const LeadIn = tdms.LeadIn;
const MetaData = tdms.MetaData;

var dba = std.heap.DebugAllocator(.{ .safety = true }).init;
const allocator = dba.allocator();

pub fn main() !void {
    const file = try fs.cwd().openFile("DataLog_2024-0501-0031-41_CMS_Data_Wiring_5.tdms", .{});
    defer file.close();

    const buf = try file.readToEndAlloc(dba.allocator(), 1000000000);

    // const metadata = try file.metadata();
    // const size = metadata.size();

    _ = try LeadIn.init(buf[0..28]);

    const md = try MetaData.init(dba.allocator(), buf[@sizeOf(LeadIn) + 4 ..]);

    for (0..md.num_objects) |i| {
        const obj = md.object_list.get(i);
        std.debug.print("{s}\n", .{obj.path});
        for (0..obj.num_properties) |j| {
            const prop = obj.properies.get(j);
            std.debug.print("   {s}\n", .{prop});
        }
    }
    std.debug.print("{d}\n", .{md.object_list.len});
}

fn u1ToBoolString(value: u1) []const u8 {
    return if (value == 1) "true" else "false";
}

test {
    _ = @import("tdms.zig");
}
