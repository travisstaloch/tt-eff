const std = @import("std");
const ttf = @import("tt-eff");

pub const std_options = std.Options{
    .log_level = .warn,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 20 }){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();
    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len < 2) return error.MissingFileArg;
    const f = try std.fs.cwd().openFile(args[1], .{});
    defer f.close();
    const contents = try f.readToEndAlloc(alloc, std.math.maxInt(u32));
    defer alloc.free(contents);

    std.log.info("{s}", .{args[1]});
    var font = try ttf.Font.init(alloc, contents);
    defer font.deinit(alloc);
    var data = font.parse(alloc) catch ttf.Font.Data{ .unitsPerEm = 0 };
    defer data.deinit(alloc);
    if (data.glyphMap.get(0xffff) == null) {
        std.log.err("no missing glyph\n", .{});
        return error.NoMissingGlyph;
    }
    // try font.readNameTable();
    std.debug.print("{?s}-{?s}\n", .{ font.getName(.uniqueId), font.getName(.subfamilyName) });

    const scale = font.scaleForPixelHeight(40);
    const x_shift = 0;
    const box = try font.codepointBitmapBoxSubpixel('B', .{ scale, scale }, .{ x_shift, 0 });
    std.debug.print("B box {}\n", .{box});
}
