const std = @import("std");
const fs = std.fs;
const io = std.io;

const tdms = @import("tdms");
const LeadIn = tdms.LeadIn;
const metadata = tdms.metadata;

var dba = std.heap.DebugAllocator(.{ .safety = true }).init;
const allocator = dba.allocator();

pub fn main() !void {
    const file = try fs.cwd().openFile("test/large.tdms", .{});
    defer file.close();

    const buf = try file.readToEndAlloc(allocator, 10000000000);

    var groups = try tdms.read_groups(buf, allocator);
    defer groups.deinit(allocator);

    for (0..groups.len) |i| {
        const g = groups.get(i);

        for (0..g.objects.len) |j| {
            const o = g.objects.get(j);
            std.debug.print("{s}\n", .{o});
        }
    }
}
