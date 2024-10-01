const std = @import("std");
const ttf = @import("tt-eff");
const clarp = @import("clarp");

pub const std_options = std.Options{ .log_level = .warn };

const ArgParser = clarp.Parser(struct {
    file: []const u8,
    codepoint: ?u21,
    pub const clarp_options = clarp.Options(@This()){
        .derive_short_names = true,
        .fields = .{
            .file = .{ .positional = true },
            .codepoint = .{ .positional = true, .utf8 = true },
        },
        .overrides = struct {
            pub fn codepoint(
                ctx: clarp.Ctx,
                self: *ArgParser.Result,
                fields_seen: ?*std.StaticBitSet(2),
            ) anyerror!void {
                self.codepoint = try std.unicode.utf8Decode(ctx.args.*[0]);
                ctx.args.* = ctx.args.*[1..];
                fields_seen.?.set(1);
            }
        },
    };
}, .{});

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 20 }){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();
    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    const parsed = try ArgParser.parse(args, .{ .err_writer = std.io.getStdErr().writer().any() });

    std.debug.print("{s}\n", .{parsed.result.file});
    const f = try std.fs.cwd().openFile(parsed.result.file, .{});
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
    std.debug.print("{?s}\n", .{font.getName(.uniqueId)});
    std.debug.print("numGlyphs {} unitsPerEm {}\n", .{ font.numGlyphs, data.unitsPerEm });
    // for (data.glyphMap.values()) |v| {
    //     std.debug.print("char {} points {}\n", .{ v.unicodeValue, v.points.len });
    // }

    if (parsed.result.codepoint) |cp| {
        const glyphIndex = try font.findGlyphIndex(cp);
        std.debug.print("codepoint {u} glyphIndex {}\n", .{ cp, glyphIndex });
        var glyph = try font.readGlyph(alloc, glyphIndex);
        std.debug.print("min {} max {}\n", .{ glyph.min, glyph.max });
        // const layout = try font.getLayoutInfo(glyphIndex);
        defer glyph.deinit(alloc);
        std.debug.print("advanceWidth {} leftSideBearing {}\n", .{ glyph.advanceWidth, glyph.leftSideBearing });
        var end: u32 = 0;
        for (glyph.contourEndIndices, 0..) |ei, i| {
            std.debug.print("-- contour {}: {} points --\n", .{ i, ei - end });
            for (glyph.points[end..ei]) |pt| {
                std.debug.print("{s} {d:.0}\n", .{ if (pt.onCurve) "+" else "-", pt.vec2() });
            }
            end = ei;
        }
        const scale = font.scaleForPixelHeight(40);
        const x_shift = 0;
        const box = try font.codepointBitmapBoxSubpixel(cp, .{ scale, scale }, .{ x_shift, 0 });
        std.debug.print("box {}\n", .{box});
    }
}
