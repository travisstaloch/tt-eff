const std = @import("std");
const ttf = @import("tt-eff");
const Font = ttf.Font;
const Vector2 = ttf.Vector2;
const GlyphHelper = ttf.GlyphHelper;
const rl = @cImport(@cInclude("raylib.h"));
const f32x2 = ttf.f32x2;
const i32x2 = ttf.i32x2;
const clarp = @import("clarp");
const wh = f32x2.init(1920, 1080);

pub const std_options = std.Options{ .log_level = .info };

const ArgParser = clarp.Parser(struct {
    file: []const u8,
    codepoint: ?u21,
    pub const clarp_options = clarp.Options(@This()){
        .derive_short_names = true,
        .fields = .{
            .file = .{ .positional = true },
            .codepoint = .{ .positional = true, .utf8 = true },
        },
    };
}, .{});

pub fn debug(comptime fmt: []const u8, args: anytype) void {
    _ = fmt; // autofix
    _ = args; // autofix
    // std.debug.print(fmt, args);
}

pub fn main() !void {
    rl.InitWindow(wh.x, wh.y, "truetype font demo");
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

    var font = try Font.init(alloc, contents);
    defer font.deinit(alloc);
    var fontData = try font.parse(alloc);
    defer fontData.deinit(alloc);

    const text: []const u8 = if (parsed.result.codepoint) |cp|
        try std.mem.concat(alloc, u8, &.{
            std.mem.asBytes(&cp),
        })
    else if (true) try std.mem.concat(alloc, u8, &.{
        font.getName(.familyName) orelse "Missing family name",
        "-",
        font.getName(.subfamilyName) orelse "Missing sub family name",
        "\nabcdefghi",
        "\njklmnopqr",
        "\nstuvwxyz",
        "\nABCDEFGHI",
        "\nJKLMNOPQR",
        "\nSTUVWXYZ",
    }) else blk: {
        const glyphs = fontData.glyphs[0..100];
        const text = try alloc.alloc(u8, glyphs.len);
        @memset(text, '\n');
        {
            var i: usize = 0;
            for (fontData.glyphMap.keys()[0..glyphs.len]) |c| {
                // if (c < 256) text[i] = @intCast(c) else text[i] = ' ';
                // i += 1;
                // if (i % colwidth == 0) {
                //     // text[i] = '\n';
                //     i += 1;
                // }
                text[i] = @intCast(c);
                i += 1;
            }
        }
        break :blk text;
    };
    defer alloc.free(text);
    const options = GlyphHelper.RenderOptions{ .direction = .downwardY };
    var textData = try ttf.TextData.init(alloc, text, fontData);
    for (textData.uniquePrintableCharacters) |pc| debug("pc {}\n", .{pc});
    defer textData.deinit(alloc);
    var renderDataMap = try GlyphHelper.createRenderDataMap(
        alloc,
        textData.uniquePrintableCharacters,
        fontData,
        options,
    );
    defer GlyphHelper.destroyRenderDataMap(&renderDataMap, alloc);
    debug("renderDataMap {any}\n", .{renderDataMap.keys()});
    const settings = ttf.TextRender.LayoutSettings.init(0.5, 1, 2.1, 1, wh);

    // debug("B pc min {}/{} max {},{} advanceWidth/lsb {},{}", .{ pc.min.x, pc.min.y, pc.max.x, pc.max.y, pc.advanceWidth, pc.leftSideBearing });
    // debug("B pc contourEndIndices {any}", .{pc.contourEndIndices});
    // for (pc.points) |pt| {
    //     debug("{},{},{}", .{ pt.x, pt.y, pt.onCurve });
    // }
    var cam: rl.Camera2D = .{};
    cam.zoom = 1;

    while (!rl.WindowShouldClose()) {
        const key = rl.GetKeyPressed();
        if (key == rl.KEY_Q) break;
        // translate on click drag
        if (rl.IsMouseButtonDown(rl.MOUSE_BUTTON_LEFT)) {
            var delta: f32x2 = @bitCast(rl.GetMouseDelta());
            delta = delta.mulS(-1.0 / cam.zoom);
            cam.target = @bitCast(@as(f32x2, @bitCast(cam.target)).add(delta));
        }
        // zoom on wheel
        const wheel = rl.GetMouseWheelMove();
        if (wheel != 0) {
            // get the world point that is under the mouse
            const mouseWorldPos = rl.GetScreenToWorld2D(rl.GetMousePosition(), cam);
            cam.offset = rl.GetMousePosition();
            // set the target to match, so that the camera maps the world space point under the cursor to the screen space point under the cursor at any zoom
            cam.target = mouseWorldPos;
            // zoom
            const mul: f32 = if (rl.IsKeyDown(rl.KEY_LEFT_CONTROL)) 0.5 else 0.125;
            cam.zoom += wheel * mul;
            if (cam.zoom < mul) cam.zoom = mul;
        }
        rl.BeginDrawing();
        rl.ClearBackground(rl.BLACK);
        rl.BeginMode2D(cam);
        // try drawText0(alloc, text, &font, 20);
        try drawTextData(textData, renderDataMap, 20, settings);
        // try drawText2(text, renderDataMap, fontData, 20, 2);
        // try renderTextData(td, cp2rd, 20, 0.8, settings);
        rl.EndDrawing();
        // std.time.sleep(std.time.ns_per_s * 1);
    }
    rl.CloseWindow();
}

const pointPixelSize = 2;

fn drawTextData(
    textData: ttf.TextData,
    renderDataMap: GlyphHelper.RenderDataMap,
    resolution: u16,
    settings: ttf.TextRender.LayoutSettings,
) !void {
    var lastPos = f32x2.initS(std.math.floatMax(f32));
    for (textData.printableCharacters) |pc| {
        const posn = f32x2.init(
            pc.getAdvanceX(settings.fontSizePx, settings.letterSpacing, settings.wordSpacing),
            pc.getAdvanceY(settings.fontSizePx, settings.lineSpacing),
        );
        const pos = settings.scaleNormalized(posn);
        if (pos.y != lastPos.y) {
            // draw horizontal gray line at newlines
            rl.DrawLineV(
                @bitCast(f32x2.init(0, pos.y)),
                @bitCast(f32x2.init(wh.x * 1000, pos.y)),
                rl.GRAY,
            );
        }
        lastPos = pos;

        const glyphData = textData.uniquePrintableCharacters[pc.uniqueGlyphIndex];
        const bc = renderDataMap.get(glyphData.codepoint).?;

        debug(
            "{u} posn {d:.1} pos {d:.0}  centre {d:.1} size {d:.1} contours {} settings {d:.1}/{d:.1}/{d:.1}/{d:.1}\n",
            .{ glyphData.codepoint, posn, pos, bc.glyphBounds.centre, bc.glyphBounds.size, bc.contours.endIndices.len, settings.fontSizePx, settings.letterSpacing, settings.lineSpacing, settings.wordSpacing },
        );
        drawGlyph(glyphData, bc, pos, resolution, settings);
    }
    // unreachable;
}

fn drawGlyph(
    gd: ttf.GlyphData,
    bc: GlyphHelper.BoundsAndContours,
    pos: f32x2,
    resolution: u16,
    settings: ttf.TextRender.LayoutSettings,
) void {
    const colors = [_]rl.Color{ rl.RED, rl.GREEN, rl.BLUE, rl.YELLOW };
    var i: u32 = 0;
    debug("contours.endIndices {any} pos {d:.1}\n", .{ bc.contours.endIndices, pos });
    for (bc.contours.endIndices, 0..) |end, ci| {
        defer i = end;
        // if (ci == 0) continue;
        const expected = if (ci == 0) 0 else bc.contours.endIndices[ci - 1];
        debug("i {} end {} expected {}\n", .{ i, end, expected });
        std.debug.assert(i == expected);
        // draw accented contour start point
        rl.DrawCircleV(
            @bitCast(adjust(bc.contours.points[i], pos, bc.glyphBounds, settings)),
            pointPixelSize * 3,
            rl.ORANGE,
        );

        while (i + 2 < end) : (i += 2) {
            const p0 = bc.contours.points[i + 0];
            const p1 = bc.contours.points[i + 1];
            const p2 = bc.contours.points[i + 2];

            debug("ps[{}..{}] {d:.1}, {d:.1}, {d:.1}\n", .{ i, i + 2, p0, p1, p2 });
            const vs: [3]f32x2 = .{
                adjust(p0, pos, bc.glyphBounds, settings),
                adjust(p1, pos, bc.glyphBounds, settings),
                adjust(p2, pos, bc.glyphBounds, settings),
            };
            // debug("vs {d:.1}\n", .{vs});
            drawBezier(vs, resolution, colors[ci % colors.len]);

            for (0..2) |j| {
                rl.DrawCircleV(@bitCast(vs[j]), pointPixelSize, rl.GRAY);
                var buf: [20]u8 = undefined;
                var fbs = std.io.fixedBufferStream(&buf);
                fbs.writer().print("{}\x00", .{i + j}) catch unreachable;
                // const xy = p.xy.add(.from(pos.x, pos.y)).add(.init(5, 0));
                const vi = vs[j].to(i32);
                rl.DrawText(&buf, vi.x, vi.y, 5, rl.WHITE);
            }
        }
        debug("i {} end {}\n", .{ i, end });
        std.debug.assert(i + 1 == end);
    }

    for (gd.points[0..0], 0..) |p, index| {
        // const v: rl.f32x2 = @bitCast(p.vec2());
        const adj = adjust(p.vec2(), pos, bc.glyphBounds);
        const v: rl.Vector2 = @bitCast(adj);
        rl.DrawCircleV(v, pointPixelSize, if (p.onCurve) rl.WHITE else rl.GRAY);
        var buf: [20]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buf);
        fbs.writer().print("{}\x00", .{index}) catch unreachable;
        // const xy = p.xy.add(.from(pos.x, pos.y)).add(.init(5, 0));
        const vi = adj.to(i32);
        rl.DrawText(&buf, vi.x, vi.y, 5, rl.WHITE);
    }
    // unreachable;
}

fn drawText0(
    alloc: std.mem.Allocator,
    text: []const u8,
    font: *Font,
    resolution: u16,
) !void {
    var offset = f32x2.zero.with(.y, 100);
    for (text) |c| {
        // const glyphData = fontData.getGlyph(c);
        const glyphIndex = try font.findGlyphIndex(c);
        var glyphData = try font.readGlyph(alloc, glyphIndex);
        defer glyphData.deinit(alloc);
        // debug("{any}\n", .{glyphData.contourEndIndices});

        const scale = 1;
        // var contours = try GlyphHelper.createContoursWithImpliedPoints(alloc, glyphData, scale, .{});
        // defer {
        //     for (contours.items) |*ct| ct.deinit(alloc);
        //     contours.deinit(alloc);
        // }
        // const bc = renderDataMap.get(c).?;
        // const glyph = fontData.glyphMap.get(c).?;

        // drawGlyphStraightLines(glyphData, offset, resolution, scale);
        drawGlyphBezier(glyphData, offset, resolution, scale);
        offset = offset.add(.init(1500 * scale, 0));
    }
}

fn drawGlyphBezier(gd: ttf.GlyphData, offset: f32x2, resolution: u16, scale: f32) void {
    var i: u32 = 0;
    // const gdwh = gd.max.sub(gd.min);
    // const min = gd.min.to(f32).add(offset).to(i32);
    // rl.DrawRectangleLines(min.x, min.y, gdwh.x, gdwh.y, rl.WHITE);
    debug("gd.contourEndIndices {any}\n", .{gd.contourEndIndices});
    // const only = 0;
    for (gd.contourEndIndices, 0..) |end, ci| {
        const start = i;
        defer i = end;
        // if (ci == 1) continue;
        const expected = if (ci == 0) 0 else gd.contourEndIndices[ci - 1];
        debug("i {} end {} expected {}\n", .{ i, end, expected });
        std.debug.assert(i == expected);

        while (i + 1 < end) : (i += 2) {
            const p0 = gd.points[i + 0];
            const p1 = gd.points[i + 1];
            const p2 = gd.points[i + 2];
            drawOnceBezier(p0, p1, p2, offset, scale, start, i, end, ci, resolution);
        }
        debug("i {} end {}\n", .{ i, end });
        // std.debug.assert(i + 1 == end);
        std.debug.assert(gd.points[end].onCurve);
        std.debug.assert(gd.points[start].onCurve);
        drawOnce(gd.points[end], gd.points[start], offset, scale, start, i, end, ci);
    }
}

fn drawOnceBezier(
    p0: ttf.Point,
    p1: ttf.Point,
    p2: ttf.Point,
    offset: f32x2,
    scale: f32,
    start: u32,
    index: u32,
    end: u32,
    endidx: usize,
    resolution: u16,
) void {
    _ = start; // autofix
    _ = end; // autofix
    const colors = [_]rl.Color{ rl.RED, rl.GREEN, rl.BLUE, rl.YELLOW };
    var vs = [_]f32x2{ p0.vec2(), p1.vec2(), p2.vec2() };
    for (&vs) |*v| v.* = adjust(v.*, offset, scale);
    drawBezier(vs, resolution, colors[endidx % colors.len]);
    // rl.DrawLineV(@bitCast(vs[0]), @bitCast(vs[1]), colors[endidx % colors.len]);
    rl.DrawCircleV(
        @bitCast(adjust(.from(p0.xy.x, p0.xy.y), offset, scale)),
        pointPixelSize,
        if (p0.onCurve) rl.BLUE else rl.RED,
    );
    var buf: [20]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    fbs.writer().print("{}\x00", .{index}) catch unreachable;
    const xy = p0.xy.add(.from(offset.x, offset.y)).add(.init(5, 0));
    rl.DrawText(&buf, xy.x, xy.y, 5, rl.WHITE);
}

fn drawOnce(
    p0: ttf.Point,
    p1: ttf.Point,
    offset: f32x2,
    scale: f32,
    start: u32,
    index: u32,
    end: u32,
    endidx: usize,
) void {
    _ = start; // autofix
    _ = end; // autofix
    const colors = [_]rl.Color{ rl.RED, rl.GREEN, rl.BLUE, rl.YELLOW };
    var vs = [_]f32x2{ p0.vec2(), p1.vec2() };
    for (&vs) |*v| v.* = adjust(v.*, offset, scale);
    // drawBezier(vs, resolution, colors[endidx % colors.len]);
    rl.DrawLineV(@bitCast(vs[0]), @bitCast(vs[1]), colors[endidx % colors.len]);
    rl.DrawCircleV(
        @bitCast(adjust(.from(p0.xy.x, p0.xy.y), offset, scale)),
        pointPixelSize,
        if (p0.onCurve) rl.BLUE else rl.RED,
    );
    var buf: [20]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    fbs.writer().print("{}\x00", .{index}) catch unreachable;
    const xy = p0.xy.add(.from(offset.x, offset.y)).add(.init(5, 0));
    rl.DrawText(&buf, xy.x, xy.y, 5, rl.WHITE);
}

fn adjust(
    v: f32x2,
    pos: f32x2,
    bounds: GlyphHelper.GlyphBounds,
    settings: ttf.TextRender.LayoutSettings,
) f32x2 {
    _ = bounds; // autofix
    // return f32x2.init(wh.x, wh.y).sub(v.add(offset).mul(.init(scale, scale)));
    // return v.add(offset).mul(.init(scale, scale));
    // const v1 = v.with(.y, bounds.size.y - v.y);
    const v1 = v;
    const v2 = settings.scaleNormalized(v1);
    return v2.add(pos);
}

fn linearInterpolate(start: f32x2, end: f32x2, t: f32) f32x2 {
    return start.add(end.sub(start).mulS(t));
}
fn bezierInterpolate(abc: [3]f32x2, t: f32) f32x2 {
    const p0, const p1, const p2 = abc;
    const a = linearInterpolate(p0, p1, t);
    const b = linearInterpolate(p1, p2, t);
    return linearInterpolate(a, b, t);
}
fn drawBezier(abc: [3]f32x2, resolution: u16, color: rl.Color) void {
    var prev = abc[0];
    const resolutionf: f32 = @floatFromInt(resolution);
    for (0..resolution) |i| {
        const t = @as(f32, @floatFromInt(i + 1)) / resolutionf;
        const next = bezierInterpolate(abc, t);
        // debug("prev {} next {}\n", .{ prev, next });
        rl.DrawLineV(@bitCast(prev), @bitCast(next), color);
        prev = next;
    }
}
