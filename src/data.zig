const std = @import("std");
const tdms = @import("tdms.zig");

const MetaData = tdms.MetaData;
const LeadIn = tdms.LeadIn;

const Object = MetaData.Object;
const ObjectList = MetaData.ObjectList;

const equals = std.mem.eql;

pub fn read_data(buf: []const u8, ch_name: []const u8, objects: *const ObjectList, header: *const LeadIn) anyerror![]const u8 {
    const start_idx = header.data_offset + 28; // offset + leadin size
    const raw_data_size = buf.len - start_idx;

    var chunk_size: usize = 0;

    var target_obj: Object = .empty;
    var obj_index: usize = undefined;
    var initial_offset: usize = undefined;

    for (0..objects.len) |i| {
        const obj = objects.get(i);

        if (obj.data_index_tag == .no_data) continue;

        for (0..obj.properies.len) |j| {
            const prop = obj.properies.get(j);
            if (equals(u8, prop.name, "Channel Name") and equals(u8, prop.value, ch_name)) {
                target_obj = obj;
                obj_index = i;
                initial_offset = chunk_size;
            }
        }
        chunk_size += obj.data_index.dim * obj.data_index.length * try tdms.size_of(obj.data_index.dt);
    }
    // std.debug.print("size john: {d}\n", .{target_obj.data_index.length * 8});
    // std.debug.print("index: {d}\n", .{obj_index});
    // std.debug.print("offset: {d}\n", .{initial_offset});
    // std.debug.print("ch size: {d}\n", .{chunk_size});

    const num_chunks = raw_data_size / chunk_size;
    var f = try std.fs.cwd().createFile("file.file", .{});
    defer f.close();
    var writer = f.writer();

    for (0..num_chunks) |i| {
        // std.debug.print("{d}\n", .{std.mem.bytesAsSlice(f64, buf[start_idx + initial_offset ..][0 .. i * chunk_size])});

        const b = buf[(start_idx + initial_offset + (chunk_size * i))..][0 .. target_obj.data_index.length * try tdms.size_of(target_obj.data_index.dt)];
        try writer.print("{d:.2}\n", .{std.mem.bytesAsSlice(f64, b)});
    }

    const a = &[_]u8{0};
    return a;
}
