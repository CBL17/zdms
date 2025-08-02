const std = @import("std");
const fs = std.fs;
const io = std.io;

const tdms = @import("tdms");
const LeadIn = tdms.LeadIn;
const metadata = tdms.metadata;

const DEFAULT_FILE = "test/medium.tdms";

pub fn main() !void {
    var allocator = std.heap.DebugAllocator(.{
        .safety = true,
    }).init;
    const gpa = allocator.allocator();
    defer _ = allocator.deinit();

    var args_it = try std.process.argsWithAllocator(gpa);
    defer args_it.deinit();

    var file_path: []const u8 = undefined;

    _ = args_it.skip();
    if (args_it.next()) |arg| {
        file_path = arg;
    } else {
        file_path = DEFAULT_FILE;
    }

    var file: tdms.TDMSFile = try tdms.read_file(gpa, file_path);
    defer file.deinit(gpa);

    for (0..file.groups.len) |i| {
        const group = file.groups.get(i);
        std.debug.print("{s}\n", .{group.name});

        for (0..group.channels.len) |j| {
            const channel = group.channels.get(j);
            std.debug.print("    {s}\n", .{channel.name});
        }
    }
}
