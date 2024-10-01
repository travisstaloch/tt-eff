//! adapated from https://github.com/SebLague/Text-Rendering/blob/main/Assets/Scripts/SebText/Renderer/Helpers/GlyphHelper.cs

pub const GlyphBounds = struct { centre: f32x2, size: f32x2 };
pub const Contours = struct { points: []ttf.f32x2, endIndices: []u32 };
pub const BoundsAndContours = struct { glyphBounds: GlyphBounds, contours: Contours };

/// map from codepoint to BoundsAndContours
pub const RenderDataMap = std.AutoArrayHashMapUnmanaged(u32, BoundsAndContours);

pub const RenderOptions = struct {
    direction: Direction = .downwardY,
    pub const Direction = enum { downwardY, upwardY };
};

pub fn createRenderDataMap(
    alloc: std.mem.Allocator,
    uniqueCharacters: []const GlyphData,
    fontData: ttf.Font.Data,
    options: RenderOptions,
) !RenderDataMap {
    var renderData: RenderDataMap = .{};
    const scale = 1.0 / @as(f32, @floatFromInt(fontData.unitsPerEm));
    for (uniqueCharacters) |glyphData| {
        const contours = try createContoursWithImpliedPoints(alloc, glyphData, scale, options);
        const glyphBounds = getBounds(glyphData, fontData);
        try renderData.putNoClobber(
            alloc,
            glyphData.codepoint,
            .{ .glyphBounds = glyphBounds, .contours = contours },
        );
    }
    return renderData;
}

pub fn destroyRenderDataMap(renderDataMap: *RenderDataMap, alloc: Allocator) void {
    for (renderDataMap.values()) |*it| {
        alloc.free(it.contours.points);
        alloc.free(it.contours.endIndices);
    }
    renderDataMap.deinit(alloc);
}

pub fn createContoursWithImpliedPoints(
    alloc: Allocator,
    glyph: GlyphData,
    scale: f32,
    /// FIXME unused. TODO support inverted y coords
    options: RenderOptions,
) !Contours {
    _ = options; // autofix
    const convertStraightLinesToBezier = true;
    var startPointIndex: u32 = 0;
    var points = std.ArrayListUnmanaged(f32x2){};
    var endIndices = std.ArrayListUnmanaged(u32){};

    ttf.debug("createContoursWithImpliedPoints() '{u}':{}\n", .{ glyph.codepoint, glyph.codepoint });

    // temporary lists
    var contour = std.ArrayListUnmanaged(f32x2){};
    var contourMon = std.ArrayListUnmanaged(f32x2){};
    // without these ensureTotalCapacity() calls, there is often a segfault below.
    try contour.ensureTotalCapacity(alloc, 32);
    try contourMon.ensureTotalCapacity(alloc, 32);
    defer {
        contour.deinit(alloc);
        contourMon.deinit(alloc);
    }
    for (glyph.contourEndIndices) |contourEndIndex| {
        contour.clearRetainingCapacity();
        contourMon.clearRetainingCapacity();
        const contourLen = contourEndIndex - startPointIndex;
        ttf.debug(
            "  {}..{}:{}/{}\n",
            .{ startPointIndex, contourEndIndex, contourLen, glyph.points.len },
        );
        const contourPoints = glyph.points[startPointIndex..contourEndIndex];

        var firstOnCurvePointIndex: usize = 0;
        for (0..contourPoints.len) |i| {
            if (contourPoints[i].onCurve) {
                firstOnCurvePointIndex = i;
                break;
            }
        }

        for (0..contourPoints.len) |i| {
            const curr = contourPoints[(i + firstOnCurvePointIndex + 0) % contourPoints.len];
            const next = contourPoints[(i + firstOnCurvePointIndex + 1) % contourPoints.len];
            const currv, const nextv = .{ curr.vec2(), next.vec2() };
            // if (options.direction == .downwardY) {
            //     currv = xyMax.sub(currv);
            //     nextv = xyMax.sub(nextv);
            // }
            try contour.append(alloc, currv.mulS(scale));
            const bothOffCurve = !curr.onCurve and !next.onCurve;
            const isStraightLine = curr.onCurve and next.onCurve;
            if ((bothOffCurve or (isStraightLine and convertStraightLinesToBezier))) {
                const midpoint = currv.add(nextv).mulS(scale / 2.0);
                try contour.append(alloc, midpoint);
            }
        }

        // ttf.debug("contour {*}/{}\n", .{ contour.items.ptr, contour.items.len });
        const first = contour.items[0];
        try contour.append(alloc, first); // <- segfault happens here
        try makeMonotonic(alloc, contour.items, &contourMon);
        const end = points.items.len + contourMon.items.len;
        // ttf.debug("  points {} contourMon len {} end {}\n", .{ points.items.len, contourMon.items.len, end });
        try endIndices.append(alloc, @intCast(end));
        try points.appendSlice(alloc, contourMon.items);
        startPointIndex = contourEndIndex;
    }
    const last = if (endIndices.items.len > 0) endIndices.getLast() else 0;
    ttf.debug("  points {}\n", .{points.items.len});
    assert(last == points.items.len);
    return .{
        .points = try points.toOwnedSlice(alloc),
        .endIndices = try endIndices.toOwnedSlice(alloc),
    };
}

pub fn getBounds(glyphData: GlyphData, fontData: FontData) GlyphBounds {
    const antiAliasPadding = 0.005;
    const scale = 1.0 / @as(f32, @floatFromInt(fontData.unitsPerEm));

    const left = @as(f32, @floatFromInt(glyphData.min.x)) * scale;
    const right = @as(f32, @floatFromInt(glyphData.max.x)) * scale;
    const top = @as(f32, @floatFromInt(glyphData.max.y)) * scale;
    const bottom = @as(f32, @floatFromInt(glyphData.min.y)) * scale;

    const centre = f32x2.init(left + right, top + bottom).divS(2);
    const size = f32x2.init(right - left, top - bottom).addS(antiAliasPadding);
    return .{ .centre = centre, .size = size };
}

fn makeMonotonic(alloc: Allocator, original: []const f32x2, monotonic: *std.ArrayListUnmanaged(f32x2)) !void {
    var count: u32 = 1;
    {
        var i: u32 = 0;
        while (i < original.len - 2) : (i += 2) {
            const p0 = original[i + 0];
            const p1 = original[i + 1];
            const p2 = original[i + 2];
            count += if ((p1.y < @min(p0.y, p2.y) or p1.y > @max(p0.y, p2.y)))
                4
            else
                2;
        }
    }
    assert(original.len != 0);
    assert(monotonic.items.len == 0);
    try monotonic.ensureTotalCapacity(alloc, count);
    monotonic.appendAssumeCapacity(original[0]);
    var i: u32 = 0;
    while (i < original.len - 2) : (i += 2) {
        const p0 = original[i + 0];
        const p1 = original[i + 1];
        const p2 = original[i + 2];

        if ((p1.y < @min(p0.y, p2.y) or p1.y > @max(p0.y, p2.y))) {
            const split = splitAtTurningPointY(p0, p1, p2);
            monotonic.appendAssumeCapacity(split.a1);
            monotonic.appendAssumeCapacity(split.a2);
            monotonic.appendAssumeCapacity(split.b1);
            monotonic.appendAssumeCapacity(split.b2);
        } else {
            monotonic.appendAssumeCapacity(p1);
            monotonic.appendAssumeCapacity(p2);
        }
    }
    assert(monotonic.items.len == count);
}

fn splitAtTurningPointY(p0: f32x2, p1: f32x2, p2: f32x2) struct { a1: f32x2, a2: f32x2, b1: f32x2, b2: f32x2 } {
    const a = p0.sub(.initS(2)).mul(p1).add(p2);
    const b = f32x2.initS(2).mul(p1.sub(p0));
    const c = p0;

    // Calculate turning point by setting gradient.y to 0: 2at + b = 0; therefore t = -b / 2a
    const turningPointT = -b.y / (2 * a.y);
    const turningPoint = a.mulS(turningPointT).mulS(turningPointT).add(b.mulS(turningPointT)).add(c);

    // Calculate the new p1 point for curveA with points: p0, p1A, turningPoint
    // This is done by saying that p0 + gradient(t=0) * ? = p1A = (p1A.x, turningPoint.y)
    // Solve for lambda using the known turningPoint.y, and then solve for p1A.x
    const lambdaA = (turningPoint.y - p0.y) / b.y;
    const p1A_x = p0.x + b.x * lambdaA;

    // Calculate the new p1 point for curveB with points: turningPoint, p1B, p2
    // This is done by saying that p2 + gradient(t=1) * ? = p1B = (p1B.x, turningPoint.y)
    // Solve for lambda using the known turningPoint.y, and then solve for p1B.x
    const lambdaB = (turningPoint.y - p2.y) / (2 * a.y + b.y);
    const p1B_x = p2.x + (2 * a.x + b.x) * lambdaB;

    return .{
        .a1 = .init(p1A_x, turningPoint.y),
        .a2 = turningPoint,
        .b1 = .init(p1B_x, turningPoint.y),
        .b2 = p2,
    };
}

const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ttf = @import("tt-eff");
const GlyphData = ttf.GlyphData;
const FontData = ttf.Font.Data;
const f32x2 = ttf.f32x2;
const TextData = @This();
