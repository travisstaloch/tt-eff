//! adapted from https://github.com/SebLague/Text-Rendering/blob/main/Assets/Scripts/SebText/Renderer/TextData.cs

uniquePrintableCharacters: []GlyphData,
printableCharacters: []PrintableCharacter,

const spaceSizeEm = 0.333;
const lineHeightEm = 1.3;

pub fn init(alloc: std.mem.Allocator, text: []const u8, fontData: FontData) !TextData {
    var uniqueCharsList = std.ArrayList(GlyphData).init(alloc);
    var characterLayoutList = std.ArrayList(PrintableCharacter).init(alloc);
    const Context = struct {
        pub fn eql(_: @This(), a: GlyphData, b: GlyphData, b_index: usize) bool {
            _ = b_index;
            return a.unicodeValue == b.unicodeValue;
        }
        pub fn hash(_: @This(), a: GlyphData) u32 {
            return a.unicodeValue;
        }
    };
    var charToIndexTable = std.ArrayHashMap(GlyphData, u32, Context, false).init(alloc);
    defer charToIndexTable.deinit();

    const scale: f32 = 1.0 / @as(f32, @floatFromInt(fontData.unitsPerEm));
    var letterAdvance: f32 = 0;
    var wordAdvance: f32 = 0;
    var lineAdvance: f32 = 0;

    for (0..text.len) |i| {
        if (text[i] == ' ') {
            wordAdvance += spaceSizeEm;
        } else if (text[i] == '\t') {
            wordAdvance += spaceSizeEm * 4; // TODO: proper tab implementation
        } else if (text[i] == '\n') {
            lineAdvance += lineHeightEm;
            wordAdvance = 0;
            letterAdvance = 0;
        } else if (!std.ascii.isControl(text[i])) {
            const character = fontData.getGlyph(text[i]);
            const gop = try charToIndexTable.getOrPut(character);
            if (!gop.found_existing) {
                gop.value_ptr.* = @intCast(uniqueCharsList.items.len);
                try uniqueCharsList.append(character);
            }
            const uniqueIndex = gop.value_ptr.*;

            const offsetX = @as(f32, @floatFromInt(character.min.x + @divTrunc(character.width(), 2))) * scale;
            const offsetY = @as(f32, @floatFromInt(character.min.x + @divTrunc(character.height(), 2))) * scale;

            const printable = PrintableCharacter.init(uniqueIndex, letterAdvance, wordAdvance, lineAdvance, offsetX, offsetY);
            try characterLayoutList.append(printable);
            letterAdvance += @as(f32, @floatFromInt(character.advanceWidth)) * scale;
        }
    }

    return .{
        .uniquePrintableCharacters = try uniqueCharsList.toOwnedSlice(),
        .printableCharacters = try characterLayoutList.toOwnedSlice(),
    };
}

pub fn deinit(td: *TextData, alloc: std.mem.Allocator) void {
    alloc.free(td.printableCharacters);
    alloc.free(td.uniquePrintableCharacters);
}

pub const PrintableCharacter = struct {
    uniqueGlyphIndex: u32,
    letterAdvance: f32,
    wordAdvance: f32,
    lineAdvance: f32,
    offsetX: f32,
    offsetY: f32,

    pub fn init(
        uniqueGlyphIndex: u32,
        letterAdvance: f32,
        wordAdvance: f32,
        lineAdvance: f32,
        offsetX: f32,
        offsetY: f32,
    ) PrintableCharacter {
        return .{
            .uniqueGlyphIndex = uniqueGlyphIndex,
            .letterAdvance = letterAdvance,
            .wordAdvance = wordAdvance,
            .lineAdvance = lineAdvance,
            .offsetX = offsetX,
            .offsetY = offsetY,
        };
    }

    pub fn getAdvanceX(
        pc: PrintableCharacter,
        fontSize: f32,
        letterSpacing: f32,
        wordSpacing: f32,
    ) f32 {
        return (pc.letterAdvance * letterSpacing +
            pc.wordAdvance * wordSpacing +
            pc.offsetX) * fontSize;
    }

    pub fn getAdvanceY(pc: PrintableCharacter, fontSize: f32, lineSpacing: f32) f32 {
        return (-pc.lineAdvance * lineSpacing + pc.offsetY) * fontSize;
    }
};

const std = @import("std");
const ttf = @import("root.zig");
const GlyphData = ttf.GlyphData;
const FontData = ttf.Font.Data;
const TextData = @This();
