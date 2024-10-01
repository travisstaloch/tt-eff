//!
//! this file contains opentype (truetype 2) specific code.
//!
//! adapted from https://github.com/nothings/stb/blob/master/stb_truetype.h
//!

pub const Buf = extern struct {
    data: [*]const u8,
    cursor: u32,
    size: u32,

    pub const zero: Buf = .init(undefined, 0);

    pub fn init(data: [*]const u8, size: u32) Buf {
        return .{ .data = data, .size = size, .cursor = 0 };
    }

    pub fn skip(b: *Buf, o: u32) void {
        b.seek(b.cursor + o);
    }
    pub fn seek(b: *Buf, o: u32) void {
        assert(!(o > b.size or o < 0));
        b.cursor = if (o > b.size or o < 0) b.size else o;
    }
    pub fn peek8(b: *Buf) u8 {
        if (b.cursor >= b.size)
            return 0;
        return b.data[b.cursor];
    }

    pub fn get8(b: *Buf) u8 {
        if (b.cursor >= b.size) return 0;
        defer b.cursor += 1;
        return b.data[b.cursor];
    }
    pub fn get16(b: *Buf) u16 {
        return @truncate(b.get(2));
    }
    pub fn get32(b: *Buf) u32 {
        return b.get(4);
    }

    pub fn get(b: *Buf, n: u32) u32 {
        var v: u32 = 0;
        assert(n >= 1 and n <= 4);
        for (0..n) |_|
            v = (v << 8) | b.get8();
        return v;
    }

    pub fn cffGetIndex(b: *Buf) Buf {
        const start = b.cursor;
        const count = b.get16();
        if (count != 0) {
            const offsize = b.get8();
            assert(offsize >= 1 and offsize <= 4);
            b.skip(offsize * count);

            b.skip(b.get(offsize) - 1);
        }
        return b.range(start, b.cursor - start);
    }

    pub fn cffIndexGet(_b: Buf, i: u32) Buf {
        var b = _b;
        b.seek(0);
        const count = b.get16();
        const offsize = b.get8();
        assert(i >= 0 and i < count);
        assert(offsize >= 1 and offsize <= 4);
        b.skip(i * offsize);

        const start = b.get(offsize);
        const end = b.get(offsize);
        return b.range(2 + (count + 1) * offsize + start, end - start);
    }
    pub fn cffIndexCount(b: *Buf) u16 {
        b.seek(0);
        return b.get16();
    }

    pub fn range(b: *Buf, o: u32, s: u32) Buf {
        var r = Buf.zero;
        if (o < 0 or s < 0 or o > b.size or s > b.size - o) return r;
        r.data = b.data + o;
        r.size = s;
        return r;
    }

    pub fn cffInt(b: *Buf) u32 {
        const b0: i32 = b.get8();
        const r: u32 = if (b0 >= 32 and b0 <= 246)
            @bitCast(b0 - 139)
        else if (b0 >= 247 and b0 <= 250)
            @bitCast((b0 - 247) * 256 + b.get8() + 108)
        else if (b0 >= 251 and b0 <= 254)
            @bitCast(-(b0 - 251) * 256 - b.get8() - 108)
        else if (b0 == 28)
            b.get16()
        else if (b0 == 29)
            b.get32()
        else
            unreachable;
        debugCharstring("cffInt() b0 {} r {}\n", .{ b0, r });
        return r;
    }

    pub fn dictGetInts(b: *Buf, key: u32, outcount: u32, out: [*]u32) void {
        var operands = b.dictGet(key);
        for (0..outcount) |i| {
            if (operands.cursor >= operands.size) break;
            out[i] = operands.cffInt();
        }
    }

    pub fn dictGet(b: *Buf, key: u32) Buf {
        b.seek(0);
        while (b.cursor < b.size) {
            const start = b.cursor;
            while (b.peek8() >= 28) b.cffSkipOperand();
            const end = b.cursor;
            var op: i32 = b.get8();
            if (op == 12) op = @as(i32, b.get8()) | 0x100;
            if (op == key) return b.range(start, end - start);
        }
        return b.range(0, 0);
    }

    fn cffSkipOperand(b: *Buf) void {
        const b0 = b.peek8();
        assert(b0 >= 28);
        if (b0 == 30) {
            b.skip(1);
            while (b.cursor < b.size) {
                const v = b.get8();
                if ((v & 0xF) == 0xF or (v >> 4) == 0xF)
                    break;
            }
        } else {
            _ = b.cffInt();
        }
    }

    pub fn getSubrs(_cff: Buf, _fontdict: Buf) Buf {
        var privateLoc: [2]u32 = .{ 0, 0 };
        var fontdict = _fontdict;
        fontdict.dictGetInts(18, 2, &privateLoc);
        if (privateLoc[1] == 0 or privateLoc[0] == 0) return .zero;
        var cff = _cff;
        var pdict = cff.range(privateLoc[1], privateLoc[0]);
        var subrsoff: u32 = 0;
        pdict.dictGetInts(19, 1, @ptrCast(&subrsoff));
        if (subrsoff == 0) return .zero;
        cff.seek(privateLoc[1] + subrsoff);
        return cff.cffGetIndex();
    }

    fn getSubr(_idx: Buf, _n: u32) Buf {
        var idx = _idx;
        var n = _n;
        const count = idx.cffIndexCount();
        n +%= if (count >= 33900)
            32768
        else if (count >= 1240)
            1131
        else
            107;
        if (n < 0 or n >= count) return .zero;
        return idx.cffIndexGet(n);
    }
};

pub const VMove = enum(u8) {
    vmove = 1,
    vline,
    /// a quadratic bezier curve (one control point)
    vcurve,
    /// a cubic bezier curve (two control points)
    vcubic,

    pub fn int(v: VMove) u8 {
        return @intFromEnum(v);
    }
};

pub const CharstringCtx = struct {
    started: bool,
    first: f32x2,
    xy: f32x2,
    min: i32x2,
    max: i32x2,
    numPoints: u32,
    options: Options,
    points: std.ArrayListUnmanaged(Point) = .{},
    contourEndIndices: std.ArrayListUnmanaged(u32) = .{},

    const Options = union(enum) {
        /// calculate glyph bounds and count numPoints. don't allocate any points
        boundsOnly,
        /// allocate points and count numPoints. don't calculate glyph bounds.
        allocatePoints: mem.Allocator,
    };

    /// options.boundsOnly:     calculate glyph bounds and count numPoints
    /// options.allocatePoints: allocate points and count numPoints
    pub fn init(options: Options) CharstringCtx {
        return .{
            .started = false,
            .first = .zero,
            .xy = .zero,
            .min = .zero,
            .max = .zero,
            .numPoints = 0,
            .options = options,
        };
    }
    pub fn deinit(ctx: *CharstringCtx, alloc: mem.Allocator) void {
        ctx.contourEndIndices.deinit(alloc);
        ctx.points.deinit(alloc);
    }

    fn trackVertex(ctx: *CharstringCtx, x: i32, y: i32) void {
        if (x > ctx.max.x or !ctx.started) ctx.max.x = x;
        if (y > ctx.max.y or !ctx.started) ctx.max.y = y;
        if (x < ctx.min.x or !ctx.started) ctx.min.x = x;
        if (y < ctx.min.y or !ctx.started) ctx.min.y = y;
        ctx.started = true;
    }

    fn closeShape(ctx: *CharstringCtx) !void {
        if (ctx.first.x != ctx.xy.x or ctx.first.y != ctx.xy.y)
            try ctx.v(.vline, @intFromFloat(ctx.first.x), @intFromFloat(ctx.first.y), 0, 0, 0, 0);
        if (ctx.options == .allocatePoints) {
            if (ctx.points.items.len != 0)
                try ctx.contourEndIndices.append(ctx.options.allocatePoints, @intCast(ctx.points.items.len));
        }
    }

    fn rmoveTo(ctx: *CharstringCtx, dx: f32, dy: f32) !void {
        try ctx.closeShape();
        ctx.first.x = ctx.xy.x + dx;
        ctx.xy.x = ctx.xy.x + dx;
        ctx.first.y = ctx.xy.y + dy;
        ctx.xy.y = ctx.xy.y + dy;
        try ctx.v(.vmove, @intFromFloat(ctx.xy.x), @intFromFloat(ctx.xy.y), 0, 0, 0, 0);
    }
    fn rlineTo(ctx: *CharstringCtx, dx: f32, dy: f32) !void {
        ctx.xy.x += dx;
        ctx.xy.y += dy;
        try ctx.v(.vline, @intFromFloat(ctx.xy.x), @intFromFloat(ctx.xy.y), 0, 0, 0, 0);
    }
    fn rccurveTo(ctx: *CharstringCtx, dx1: f32, dy1: f32, dx2: f32, dy2: f32, dx3: f32, dy3: f32) !void {
        const cx1 = ctx.xy.x + dx1;
        const cy1 = ctx.xy.y + dy1;
        const cx2 = cx1 + dx2;
        const cy2 = cy1 + dy2;
        ctx.xy.x = cx2 + dx3;
        ctx.xy.y = cy2 + dy3;
        try ctx.v(
            .vcubic,
            @intFromFloat(ctx.xy.x),
            @intFromFloat(ctx.xy.y),
            @intFromFloat(cx1),
            @intFromFloat(cy1),
            @intFromFloat(cx2),
            @intFromFloat(cy2),
        );
    }
    fn v(ctx: *CharstringCtx, ty: VMove, x: i32, y: i32, cx: i32, cy: i32, cx1: i32, cy1: i32) !void {
        if (ctx.options == .boundsOnly) {
            trackVertex(ctx, x, y);
            if (ty == .vcubic) {
                trackVertex(ctx, cx, cy);
                trackVertex(ctx, cx1, cy1);
            }
        } else {
            // FIXME not sure this is 100% correct
            if (ty == .vcurve or ty == .vcubic) {
                try ctx.points.append(ctx.options.allocatePoints, .{ .xy = .init(cx, cy), .onCurve = false });
            }
            if (ty == .vcubic) {
                try ctx.points.append(ctx.options.allocatePoints, .{ .xy = .init(cx1, cy1), .onCurve = false });
            }
            try ctx.points.append(ctx.options.allocatePoints, .{ .xy = .init(x, y), .onCurve = true });
        }
        ctx.numPoints += 1;
    }
};

pub const CffData = struct {
    /// cff font data
    cff: Buf,
    /// the charstring index
    charstrings: Buf,
    /// global charstring subroutines index
    gsubrs: Buf,
    /// private charstring subroutines index
    subrs: Buf,
    /// array of font dicts
    fontdicts: Buf,
    /// map from glyph to fontdict
    fdselect: Buf,
};

fn charstringErr(s: []const u8) error{Charstring} {
    std.log.err("{s}", .{s});
    return error.Charstring;
}

const Instruction = enum(u8) {
    hintmask = 0x13,
    cntrmask = 0x14,
    hstem = 0x01,
    vstem = 0x03,
    hstemhm = 0x12,
    vstemhm = 0x17,
    rmoveto = 0x15,
    vmoveto = 0x04,
    hmoveto = 0x16,
    rlineto = 0x05,
    vlineto = 0x07,
    hlineto = 0x06,
    hvcurveto = 0x1F,
    vhcurveto = 0x1E,
    rrcurveto = 0x08,
    rcurveline = 0x18,
    rlinecurve = 0x19,
    vvcurveto = 0x1A,
    hhcurveto = 0x1B,
    callsubr = 0x0A,
    callgsubr = 0x1D,
    /// return
    ret = 0x0B,
    endchar = 0x0E,
    twoByteEscape = 0x0C,
    hflex = 0x22,
    flex = 0x23,
    hflex1 = 0x24,
    flex1 = 0x25,

    pub fn int(i: Instruction) u16 {
        return @intFromEnum(i);
    }
};

fn runCharstring(font: *const Font, glyphIndex: u32, ctx: *CharstringCtx) !void {
    debugCharstring("runCharstring() glyphIndex {}\n", .{glyphIndex});

    var maskbits: u32 = 0;
    var inHeader = true;
    var hasSubrs = false;
    var clearStack = false;
    var s = [1]f32{0} ** 48; // stack
    var sp: u32 = 0; // stack pointer
    var subr_stack = std.BoundedArray(Buf, 10).init(0) catch unreachable;
    var subrs = font.cffData.?.subrs;
    // this currently ignores the initial width value, which isn't needed if we have hmtx
    var b = font.cffData.?.charstrings.cffIndexGet(glyphIndex);

    while (b.cursor < b.size) {
        var i: u32 = 0;
        clearStack = true;
        const b0: u16 = b.get8();
        debugCharstring("{}/{} b0 {}/0x{x} numPoints {}\n", .{ b.cursor, b.size, b0, b0, ctx.numPoints });

        sw: switch (b0) {
            // @TODO implement hinting
            Instruction.hintmask.int(), // 0x13
            Instruction.cntrmask.int(), // 0x14
            => {
                if (inHeader) maskbits += (sp / 2); // implicit "vstem"
                inHeader = false;
                b.skip((maskbits + 7) / 8);
            },
            Instruction.hstem.int(), // 0x01
            Instruction.vstem.int(), // 0x03
            Instruction.hstemhm.int(), // 0x12
            Instruction.vstemhm.int(), // 0x17
            => {
                maskbits += (sp / 2);
            },
            Instruction.rmoveto.int() => { // 0x15
                inHeader = false;
                if (sp < 2) return charstringErr("rmoveto stack");
                try ctx.rmoveTo(s[sp - 2], s[sp - 1]);
            },
            Instruction.vmoveto.int() => { // 0x04
                inHeader = false;
                if (sp < 1) return charstringErr("vmoveto stack");
                try ctx.rmoveTo(0, s[sp - 1]);
            },
            Instruction.hmoveto.int() => { // 0x16
                inHeader = false;
                if (sp < 1) return charstringErr("hmoveto stack");
                try ctx.rmoveTo(s[sp - 1], 0);
            },
            Instruction.rlineto.int() => { // 0x05
                if (sp < 2) return charstringErr("rlineto stack");
                while (i + 1 < sp) : (i += 2)
                    try ctx.rlineTo(s[i], s[i + 1]);
            },
            // hlineto/vlineto and vhcurveto/hvcurveto alternate horizontal and vertical
            // starting from a different place.
            Instruction.vlineto.int() => { // 0x07
                if (sp < 1) return charstringErr("vlineto stack");
                debugCharstring("vlineto i {} sp {}\n", .{ i, sp });
                while (true) {
                    if (i >= sp) break;
                    try ctx.rlineTo(0, s[i]);
                    i += 1;
                    if (i >= sp) break;
                    try ctx.rlineTo(s[i], 0);
                    i += 1;
                }
            },
            Instruction.hlineto.int() => { // 0x06
                if (sp < 1) return charstringErr("hlineto stack");
                debugCharstring("hlineto i {} sp {}\n", .{ i, sp });
                while (true) {
                    if (i >= sp) break;
                    try ctx.rlineTo(s[i], 0);
                    i += 1;
                    if (i >= sp) break;
                    try ctx.rlineTo(0, s[i]);
                    i += 1;
                }
            },
            Instruction.hvcurveto.int() => { // 0x1F
                if (sp < 4) return charstringErr("hvcurveto stack");
                while (true) {
                    debugCharstring("hvcurveto i {} sp {}\n", .{ i, sp });
                    if (i + 3 >= sp) break;
                    try ctx.rccurveTo(s[i], 0, s[i + 1], s[i + 2], if (sp - i == 5) s[i + 4] else 0.0, s[i + 3]);
                    i += 4;
                    if (i + 3 >= sp) break;
                    try ctx.rccurveTo(0, s[i], s[i + 1], s[i + 2], s[i + 3], if (sp - i == 5) s[i + 4] else 0.0);
                    i += 4;
                }
            },
            Instruction.vhcurveto.int() => { // 0x1E
                if (sp < 4) return charstringErr("vhcurveto stack");
                while (true) {
                    debugCharstring("vhcurveto i {} sp {}\n", .{ i, sp });
                    if (i + 3 >= sp) break;
                    try ctx.rccurveTo(0, s[i], s[i + 1], s[i + 2], s[i + 3], if (sp - i == 5) s[i + 4] else 0.0);
                    i += 4;
                    if (i + 3 >= sp) break;
                    try ctx.rccurveTo(s[i], 0, s[i + 1], s[i + 2], if (sp - i == 5) s[i + 4] else 0.0, s[i + 3]);
                    i += 4;
                }
            },
            Instruction.rrcurveto.int() => { // 0x08
                if (sp < 6) return charstringErr("rcurveline stack");
                while (i + 5 < sp) : (i += 6)
                    try ctx.rccurveTo(s[i], s[i + 1], s[i + 2], s[i + 3], s[i + 4], s[i + 5]);
            },
            Instruction.rcurveline.int() => { // 0x18
                if (sp < 8) return charstringErr("rcurveline stack");
                while (i + 5 < sp - 2) : (i += 6)
                    try ctx.rccurveTo(s[i], s[i + 1], s[i + 2], s[i + 3], s[i + 4], s[i + 5]);
                if (i + 1 >= sp) return charstringErr("rcurveline stack");
                try ctx.rlineTo(s[i], s[i + 1]);
            },
            Instruction.rlinecurve.int() => { // 0x19
                if (sp < 8) return charstringErr("rlinecurve stack");
                while (i + 1 < sp - 6) : (i += 2)
                    try ctx.rlineTo(s[i], s[i + 1]);
                if (i + 5 >= sp) return charstringErr("rlinecurve stack");
                try ctx.rccurveTo(s[i], s[i + 1], s[i + 2], s[i + 3], s[i + 4], s[i + 5]);
            },
            Instruction.vvcurveto.int(), // 0x1A
            Instruction.hhcurveto.int(),
            => { // 0x1B
                if (sp < 4) return charstringErr("(vv|hh)curveto stack");
                var f: f32 = 0.0;
                if (sp & 1 != 0) {
                    f = s[i];
                    i += 1;
                }
                while (i + 3 < sp) : (i += 4) {
                    if (b0 == Instruction.hhcurveto.int()) //  0x1B
                        try ctx.rccurveTo(s[i], f, s[i + 1], s[i + 2], s[i + 3], 0.0)
                    else
                        try ctx.rccurveTo(f, s[i], s[i + 1], s[i + 2], 0.0, s[i + 3]);
                    f = 0.0;
                }
            },
            Instruction.callsubr.int() => { // 0x0A
                if (!hasSubrs) {
                    if (font.cffData.?.fdselect.size != 0)
                        subrs = getGlyphSubrs(font, glyphIndex);
                    hasSubrs = true;
                }
                continue :sw Instruction.callgsubr.int();
                // FALLTHROUGH
            },
            Instruction.callgsubr.int() => { // 0x1D
                if (sp < 1) return charstringErr("call(g|)subr stack");
                sp -= 1;
                const v: i32 = @intFromFloat(@trunc(s[sp]));
                if (subr_stack.len >= 10) return charstringErr("recursion limit");
                subr_stack.append(b) catch unreachable;
                b = (if (b0 == Instruction.callsubr.int()) // 0x0A
                    subrs
                else
                    font.cffData.?.gsubrs).getSubr(@bitCast(v));
                if (b.size == 0) return charstringErr("subr not found");
                b.cursor = 0;
                clearStack = false;
            },
            Instruction.ret.int() => { // 0x0B
                if (subr_stack.len == 0) return charstringErr("return outside subr");
                b = subr_stack.pop();
                clearStack = false;
            },
            Instruction.endchar.int() => { // 0x0E
                try ctx.closeShape();
                return;
            },
            Instruction.twoByteEscape.int() => { // 0x0C
                const b1 = b.get8();
                switch (b1) {
                    // @TODO These "flex" implementations ignore the flex-depth and resolution,
                    // and always draw beziers.
                    Instruction.hflex.int() => { // 0x22
                        if (sp < 7) return charstringErr("hflex stack");
                        const dx1 = s[0];
                        const dx2 = s[1];
                        const dy2 = s[2];
                        const dx3 = s[3];
                        const dx4 = s[4];
                        const dx5 = s[5];
                        const dx6 = s[6];
                        try ctx.rccurveTo(dx1, 0, dx2, dy2, dx3, 0);
                        try ctx.rccurveTo(dx4, 0, dx5, -dy2, dx6, 0);
                    },
                    Instruction.flex.int() => { // 0x23
                        if (sp < 13) return charstringErr("flex stack");
                        const dx1 = s[0];
                        const dy1 = s[1];
                        const dx2 = s[2];
                        const dy2 = s[3];
                        const dx3 = s[4];
                        const dy3 = s[5];
                        const dx4 = s[6];
                        const dy4 = s[7];
                        const dx5 = s[8];
                        const dy5 = s[9];
                        const dx6 = s[10];
                        const dy6 = s[11];
                        //fd is s[12]
                        try ctx.rccurveTo(dx1, dy1, dx2, dy2, dx3, dy3);
                        try ctx.rccurveTo(dx4, dy4, dx5, dy5, dx6, dy6);
                    },
                    Instruction.hflex1.int() => { // 0x24
                        if (sp < 9) return charstringErr("hflex1 stack");
                        const dx1 = s[0];
                        const dy1 = s[1];
                        const dx2 = s[2];
                        const dy2 = s[3];
                        const dx3 = s[4];
                        const dx4 = s[5];
                        const dx5 = s[6];
                        const dy5 = s[7];
                        const dx6 = s[8];
                        try ctx.rccurveTo(dx1, dy1, dx2, dy2, dx3, 0);
                        try ctx.rccurveTo(dx4, 0, dx5, dy5, dx6, -(dy1 + dy2 + dy5));
                    },
                    Instruction.flex1.int() => { // 0x25
                        if (sp < 11) return charstringErr("flex1 stack");
                        const dx1 = s[0];
                        const dy1 = s[1];
                        const dx2 = s[2];
                        const dy2 = s[3];
                        const dx3 = s[4];
                        const dy3 = s[5];
                        const dx4 = s[6];
                        const dy4 = s[7];
                        const dx5 = s[8];
                        const dy5 = s[9];
                        var dx6 = s[10];
                        var dy6 = s[10];
                        const dx = dx1 + dx2 + dx3 + dx4 + dx5;
                        const dy = dy1 + dy2 + dy3 + dy4 + dy5;
                        if (@abs(dx) > @abs(dy))
                            dy6 = -dy
                        else
                            dx6 = -dx;
                        try ctx.rccurveTo(dx1, dy1, dx2, dy2, dx3, dy3);
                        try ctx.rccurveTo(dx4, dy4, dx5, dy5, dx6, dy6);
                    },

                    else => {
                        return charstringErr("unimplemented");
                    },
                }
            },
            else => {
                if (b0 != 255 and b0 != 28 and b0 < 32)
                    return charstringErr("reserved operator");

                // push immediate
                const f: f32 = if (b0 == 255) blk: {
                    // f = (float)(int)buf_get32(&b) / 0x10000;
                    break :blk @floatFromInt(@as(i32, @intCast(b.get32() / 0x10000)));
                } else blk: {
                    b.cursor -= 1;
                    // f = (float)(short)cff_int(&b);
                    break :blk @floatFromInt(@as(i32, @bitCast(@as(u32, @truncate(b.cffInt())))));
                };
                debugCharstring("f {d:.2}\n", .{f});
                if (sp >= 48) return charstringErr("push stack overflow");
                s[sp] = f;
                sp += 1;
                clearStack = false;
            },
        }
        if (clearStack) sp = 0;
    }
    return charstringErr("no endchar");
}

fn getGlyphSubrs(info: *const Font, glyphIndex: u32) Buf {
    var fdselector: u32 = std.math.maxInt(u32);
    var fdselect = info.cffData.?.fdselect;
    // debugCharstring("getGlyphSubrs fdselect {}\n", .{fdselect});
    fdselect.seek(0);

    const fmt = fdselect.get8();
    if (fmt == 0) {
        // untested
        fdselect.skip(glyphIndex);
        fdselector = fdselect.get8();
    } else if (fmt == 3) {
        const nranges = fdselect.get16();
        var start = fdselect.get16();
        for (0..nranges) |_| {
            const v = fdselect.get8();
            const end = fdselect.get16();
            if (glyphIndex >= start and glyphIndex < end) {
                fdselector = v;
                break;
            }
            start = end;
        }
    }
    // what was this line? it does nothing. why was it in the original c code?
    // if (fdselector == -1) new_buf(NULL, 0);
    return info.cffData.?.cff.getSubrs(
        info.cffData.?.fontdicts.cffIndexGet(fdselector),
    );
}

pub fn readGlyph(font: *const Font, alloc: mem.Allocator, glyphIndex: u32) !ttf.GlyphData {
    var countCtx = CharstringCtx.init(.boundsOnly);
    var outputCtx = CharstringCtx.init(.{ .allocatePoints = alloc });
    defer outputCtx.deinit(alloc);
    // run charstring to get numPoints so that we can allocate them all at once
    try runCharstring(font, glyphIndex, &countCtx);
    try outputCtx.points.ensureTotalCapacity(alloc, outputCtx.numPoints);
    try runCharstring(font, glyphIndex, &outputCtx);
    assert(outputCtx.numPoints == countCtx.numPoints);
    std.log.debug(
        "first {d:.1} xy {d:.1} min {d:.1} max {d:.1}",
        .{ countCtx.first, countCtx.xy, countCtx.min, countCtx.max },
    );

    return .{
        .glyphIndex = glyphIndex,
        .points = try outputCtx.points.toOwnedSlice(alloc),
        .contourEndIndices = try outputCtx.contourEndIndices.toOwnedSlice(alloc),
        .min = countCtx.min,
        .max = countCtx.max,
        .advanceWidth = undefined,
        .leftSideBearing = undefined,
        .codepoint = undefined,
    };
}

pub fn glyphInfo(font: *const Font, glyphIndex: u32, outNumVertices: ?*u32) ?ttf.Box {
    var ctx = CharstringCtx.init(.boundsOnly);
    const ok = if (runCharstring(font, glyphIndex, &ctx)) |_| true else |_| false;

    if (outNumVertices != null and ok) outNumVertices.?.* = ctx.numPoints;
    return .{
        .x0 = if (ok) ctx.min.x else 0,
        .y0 = if (ok) ctx.min.y else 0,
        .x1 = if (ok) ctx.max.x else 0,
        .y1 = if (ok) ctx.max.y else 0,
    };
}

pub fn debugCharstring(comptime fmt: []const u8, args: anytype) void {
    _ = fmt; // autofix
    _ = args; // autofix
    // std.debug.print(fmt, args);
}

const std = @import("std");
const ttf = @import("tt-eff");
const Font = ttf.Font;
const f32x2 = ttf.f32x2;
const i32x2 = ttf.i32x2;
const Point = ttf.Point;
const mem = std.mem;
const assert = std.debug.assert;
