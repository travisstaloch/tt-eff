const std = @import("std");

const Meta = struct {
    fn typePair(comptime A: type, comptime B: type) u16 {
        return infoPair(@typeInfo(A), @typeInfo(B));
    }
    const TypeTag = std.meta.Tag(std.builtin.Type);
    fn infoPair(a: TypeTag, b: TypeTag) u16 {
        return @as(u16, @intFromEnum(a)) << 8 | @intFromEnum(b);
    }
};

pub fn Vector2(comptime T: type) type {
    return extern struct {
        x: T,
        y: T,

        pub const one: Self = .initS(1);
        pub const zero: Self = .initS(0);
        const Self = @This();

        pub fn init(x: T, y: T) Self {
            return .{ .x = x, .y = y };
        }
        pub fn initS(scalar: T) Self {
            return .{ .x = scalar, .y = scalar };
        }

        pub fn from(x: anytype, y: anytype) Self {
            const To = @TypeOf(x, y);
            return switch (comptime Meta.typePair(To, T)) {
                Meta.infoPair(.int, .float) => .init(@floatFromInt(x), @floatFromInt(y)),
                Meta.infoPair(.float, .int) => .init(@intFromFloat(x), @intFromFloat(y)),
                else => @compileError(std.fmt.comptimePrint(
                    "TODO convert from {s} to {s}",
                    .{ @tagName(@typeInfo(T)), @tagName(@typeInfo(To)) },
                )),
            };
        }
        pub fn to(x: Self, comptime To: type) Vector2(To) {
            return switch (comptime Meta.typePair(T, To)) {
                Meta.infoPair(.int, .float) => .init(@floatFromInt(x.x), @floatFromInt(x.y)),
                Meta.infoPair(.float, .int) => .init(@intFromFloat(x.x), @intFromFloat(x.y)),
                else => @compileError(std.fmt.comptimePrint(
                    "TODO convert to {s} from {s}",
                    .{ @tagName(@typeInfo(To)), @tagName(@typeInfo(T)) },
                )),
            };
        }

        pub fn with(x: Self, comptime field: std.meta.FieldEnum(Self), value: T) Self {
            var r = x;
            @field(r, @tagName(field)) = value;
            return r;
        }
        pub fn withMul(x: Self, comptime field: std.meta.FieldEnum(Self), value: T) Self {
            return x.with(field, @field(x, @tagName(field)) * value);
        }

        pub fn add(a: Self, b: Self) Self {
            return .init(a.x + b.x, a.y + b.y);
        }
        pub fn sub(a: Self, b: Self) Self {
            return .init(a.x - b.x, a.y - b.y);
        }
        pub fn mul(a: Self, b: Self) Self {
            return .init(a.x * b.x, a.y * b.y);
        }
        pub fn div(a: Self, b: Self) Self {
            return .init(a.x / b.x, a.y / b.y);
        }

        pub fn addS(a: Self, scalar: T) Self {
            return a.add(.initS(scalar));
        }
        pub fn subS(a: Self, scalar: T) Self {
            return a.sub(.initS(scalar));
        }
        pub fn mulS(a: Self, scalar: T) Self {
            return a.mul(.initS(scalar));
        }
        pub fn divS(a: Self, scalar: T) Self {
            return a.div(.initS(scalar));
        }

        pub fn format(v: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            try std.fmt.formatType(v.x, fmt, options, writer, 0);
            try writer.writeByte(',');
            try std.fmt.formatType(v.y, fmt, options, writer, 0);
        }
    };
}
