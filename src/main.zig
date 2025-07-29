const std = @import("std");
const fs = std.fs;
const io = std.io;

const tdms = @import("tdms");
const LeadIn = tdms.LeadIn;
const metadata = tdms.metadata;

const allocator = std.heap.smp_allocator;

const DEFAULT_FILE = "test/medium.tdms";

pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const file_path = if (args.len <= 1) DEFAULT_FILE else args[1];
    const file = try tdms.read_file(allocator, file_path);
    for (0..file.groups.len) |i| {
        const group = file.groups.get(i);
        std.debug.print("{s}\n", .{group.name});

        for (0..group.channels.len) |j| {
            const channel = group.channels.get(j);
            std.debug.print("    {s}\n", .{channel.name});
        }
    }
}
