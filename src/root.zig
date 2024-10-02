//! resources:
//!   https://learn.microsoft.com/en-us/typography/opentype/spec
//!   https://developer.apple.com/fonts/TrueType-Reference-Manual/
//!   https://tophix.com/font-tools/font-viewer
//!   https://github.com/nothings/stb/blob/master/stb_truetype.h
//!   https://github.com/SebLague/Text-Rendering
//!
//!

pub const TextData = @import("TextData.zig");
pub const TextRender = @import("TextRender.zig");
pub const GlyphHelper = @import("GlyphHelper.zig");
pub const f32x2 = Vector2(f32);
pub const i32x2 = Vector2(i32);

const TableDirectory = extern struct {
    /// 0x00010000 or 0x4F54544F ('OTTO') — see below.
    sfntVersion: u32,
    /// Number of tables.
    numTables: u16,
    /// Maximum power of 2 less than or equal to numTables, times 16 ((2**floor(log2(numTables))) * #16, where “**” is an exponentiation operator).
    searchRange: u16,
    /// Log2 of the maximum power of 2 less than or equal to numTables (log2(searchRange/16), which #is equal to floor(log2(numTables))).
    entrySelector: u16,
    /// numTables times 16, minus searchRange ((numTables * 16) - searchRange).
    rangeShift: u16,

    pub fn format(td: TableDirectory, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print(
            "0x{x}, numTables={}, searchRange={}, entrySelector={}, rangeShift={}",
            .{ td.sfntVersion, td.numTables, td.searchRange, td.entrySelector, td.rangeShift },
        );
    }
};

const Table = extern struct {
    /// Table identifier.
    tag: Tag,
    /// Checksum for this table.
    checksum: u32,
    /// Offset from beginning of font file.
    offset: u32,
    /// Length of this table.
    length: u32,

    pub const zero = mem.zeroes(Table);

    const Tag = enum(u32) {
        avar = mem.readInt(u32, "avar", .big),
        BASE = mem.readInt(u32, "BASE", .big),
        CBDT = mem.readInt(u32, "CBDT", .big),
        CBLC = mem.readInt(u32, "CBLC", .big),
        CFF = mem.readInt(u32, "CFF ", .big),
        CFF2 = mem.readInt(u32, "CFF2", .big),
        cmap = mem.readInt(u32, "cmap", .big),
        COLR = mem.readInt(u32, "COLR", .big),
        CPAL = mem.readInt(u32, "CPAL", .big),
        cvar = mem.readInt(u32, "cvar", .big),
        cvt = mem.readInt(u32, "cvt ", .big),
        DSIG = mem.readInt(u32, "DSIG", .big),
        EBDT = mem.readInt(u32, "EBDT", .big),
        EBLC = mem.readInt(u32, "EBLC", .big),
        EBSC = mem.readInt(u32, "EBSC", .big),
        fpgm = mem.readInt(u32, "fpgm", .big),
        fvar = mem.readInt(u32, "fvar", .big),
        gasp = mem.readInt(u32, "gasp", .big),
        GDEF = mem.readInt(u32, "GDEF", .big),
        glyf = mem.readInt(u32, "glyf", .big),
        GPOS = mem.readInt(u32, "GPOS", .big),
        GSUB = mem.readInt(u32, "GSUB", .big),
        gvar = mem.readInt(u32, "gvar", .big),
        hdmx = mem.readInt(u32, "hdmx", .big),
        head = mem.readInt(u32, "head", .big),
        hhea = mem.readInt(u32, "hhea", .big),
        hmtx = mem.readInt(u32, "hmtx", .big),
        HVAR = mem.readInt(u32, "HVAR", .big),
        JSTF = mem.readInt(u32, "JSTF", .big),
        kern = mem.readInt(u32, "kern", .big),
        loca = mem.readInt(u32, "loca", .big),
        LTSH = mem.readInt(u32, "LTSH", .big),
        MATH = mem.readInt(u32, "MATH", .big),
        maxp = mem.readInt(u32, "maxp", .big),
        MERG = mem.readInt(u32, "MERG", .big),
        meta = mem.readInt(u32, "meta", .big),
        MVAR = mem.readInt(u32, "MVAR", .big),
        FFTM = mem.readInt(u32, "FFTM", .big),
        @"OS/2" = mem.readInt(u32, "OS/2", .big),
        name = mem.readInt(u32, "name", .big),
        post = mem.readInt(u32, "post", .big),
        prep = mem.readInt(u32, "prep", .big),
        VDMX = mem.readInt(u32, "VDMX", .big),
        feat = mem.readInt(u32, "feat", .big),
        morx = mem.readInt(u32, "morx", .big),
        prop = mem.readInt(u32, "prop", .big),
        vhea = mem.readInt(u32, "vhea", .big),
        vmtx = mem.readInt(u32, "vmtx", .big),
        BDF = mem.readInt(u32, "BDF ", .big),
        MTfn = mem.readInt(u32, "MTfn", .big),
        bdat = mem.readInt(u32, "bdat", .big),
        bloc = mem.readInt(u32, "bloc", .big),
        PCLT = mem.readInt(u32, "PCLT", .big),

        pub fn index(tag: Tag) u8 {
            @setEvalBranchQuota(4000);
            return switch (tag) {
                inline else => |t| std.meta.fieldIndex(Table.Tag, @tagName(t)).?,
            };
        }
    };

    const numTags = @typeInfo(Tag).@"enum".fields.len;
    const sentinel = std.math.maxInt(u16);

    pub fn format(t: Table, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print(
            "{s}, checksum=0x{x}, offset=0x{x}, length={}",
            .{ @tagName(t.tag), t.checksum, t.offset, t.length },
        );
    }
};

const GDEF = extern struct {
    /// Major version of the GDEF table, = 1.
    majorVersion: u16,
    /// Minor version of the GDEF table, = 0.
    minorVersion: u16,
    ///  Offset to class definition table for glyph type, from beginning of GDEF header (may be NULL).
    glyphClassDefOffset: u16,
    /// Offset to attachment point list table, from beginning of GDEF header (may be NULL).
    attachListOffset: i16,
    /// Offset to ligature caret list table, from beginning of GDEF header (may be NULL).
    ligCaretListOffset: i16,
    /// Offset to class definition table for mark attachment type, from beginning of GDEF
    markAttachClassDefOffset: i16,
};

const GDEF2 = extern struct {
    gdef: GDEF,
    /// Offset to the table of mark glyph set definitions, from beginning of GDEF header (may be NULL).
    markGlyphSetsDefOffset: i16,
};

const GDEF3 = extern struct {
    gdef: GDEF,
    /// Offset to the table of mark glyph set definitions, from beginning of GDEF header (may be NULL).
    markGlyphSetsDefOffset: i16,
    /// Offset to the item variation store table, from beginning of GDEF header (may be NULL).
    itemVarStoreOffset: i32,
};

const GlyphHeader = extern struct {
    /// If the number of contours is greater than or equal to zero, this is a
    /// simple glyph. If negative, this is a composite glyph — the value -1
    /// should be used for composite glyphs.
    numberOfContours: i16,
    /// Minimum x for coordinate data.
    xMin: i16,
    /// Minimum y for coordinate data.
    yMin: i16,
    /// Maximum x for coordinate data.
    xMax: i16,
    /// Maximum y for coordinate data.
    yMax: i16,
};

fn byteSwapAll(comptime T: type, ptr: *T) void {
    if (builtin.cpu.arch.endian() == .big) return;
    mem.byteSwapAllFields(T, ptr);
}

fn byteSwap(x: anytype) @TypeOf(x) {
    if (builtin.cpu.arch.endian() == .big) return x;
    return @byteSwap(x);
}

/// followed by encodingRecords: [numTables]Encoding,
const CmapHeader = extern struct {
    /// Table version number (0).
    version: u16,
    /// Number of encoding tables that follow.
    numTables: u16,
};

const PlatformId = enum(u16) {
    /// Various
    unicode,
    /// Script manager code
    macintosh,
    /// deprecated]    ISO encoding [deprecated]
    iso,
    /// Windows encoding
    windows,
    /// Custom
    custom,
};

const Encoding = extern struct {
    /// Platform ID.
    platformID: PlatformId,
    /// Platform-specific encoding ID.
    encodingID: u16,
    /// Byte offset from beginning of table to the subtable for this encoding.
    subtableOffset: u32,
};

/// encodingID for platformId unicode
const UnicodeEncoding = enum(u16) {
    unicode_1_0 = 0,
    unicode_1_1 = 1,
    iso_10646 = 2,
    unicode_2_0_bmp = 3,
    unicode_2_0_full = 4,
};

/// encodingID for platformId microsoft
const MicrosoftEncoding = enum(u16) {
    symbol = 0,
    unicode_bmp = 1,
    shiftjis = 2,
    unicode_full = 10,
};

/// encodingID for platformId mac; same as Script Manager codes
const MacEncoding = enum(u16) {
    roman = 0,
    arabic = 4,
    japanese = 1,
    hebrew = 5,
    chinese_trad = 2,
    greek = 6,
    korean = 3,
    russian = 7,
};

/// followed by glyphIdArray: [256]u8, An array that maps character codes to glyph index values:
const EncodingTable = extern struct {
    /// Format number is set to 0.
    format: u16,
    /// This is the length in bytes of the subtable.
    length: u16,
    /// For requirements on use of the language field, see “Use of the language
    /// field in 'cmap' subtables” in this document.
    language: u16,
};

/// followed by
///   endCode: [segCount]u16,  End characterCode for each segment, last=0xFFFF.
///   reservedPad: u16,
///   startCode: [segCount]u16, Start character code for each segment.
///   idDelta: [segCount]i16, Delta for all character codes in segment.
///   idRangeOffset: [segCount]u16, Offsets into glyphIdArray or 0
///   glyphIdArray: []u16, Glyph index array (arbitrary length)
const SegmentToDelta = extern struct {
    /// Format number is set to 4.
    format: u16,
    /// This is the length in bytes of the subtable.
    length: u16,
    /// For requirements on use of the language field, see “Use of the language field in 'cmap' subtables” in this document.
    language: u16,
    /// 2 × segCount.
    segCountX2: u16,
    /// Maximum power of 2 less than or equal to segCount, times 2 ((2**floor(log2(segCount))) * 2, where “**” is an exponentiation operator)
    searchRange: u16,
    /// Log2 of the maximum power of 2 less than or equal to segCount (log2(searchRange/2), which is equal to floor(log2(segCount)))
    entrySelector: u16,
    /// segCount times 2, minus searchRange((segCount * 2) - searchRange)
    rangeShift: u16,
};

/// 32-bit signed fixed-point number (16.16)
const Fixed = i32;
/// Date and time represented in number of seconds since 12:00 midnight, January 1, 1904, UTC. The value is represented as a signed 64-bit integer.
const LONGDATETIME = i64;

const Head = packed struct {
    ///    Major version number of the font header table — set to 1.
    majorVersion: u16,
    ///    Minor version number of the font header table — set to 0.
    minorVersion: u16,
    ///    Set by font manufacturer.
    fontRevision: Fixed,
    ///  To compute: set it to 0, sum the entire font as u32, then store 0xB1B0AFBA - sum. If the font is used as a component in a font collection file, the value of this field will be invalidated by changes to the file structure and font table directory, and must be ignored.
    checksumAdjustment: u32,
    ///     Set to 0x5F0F3CF5.
    magicNumber: u32,
    /// Bit 0: Baseline for font at y=0.
    /// Bit 1: Left sidebearing point at x=0 (relevant only for TrueType rasterizers) — see additional information below regarding variable fonts.
    /// Bit 2: Instructions may depend on point size.
    /// Bit 3: Force ppem to integer values for all internal scaler math; may use fractional ppem sizes if this bit is clear. It is strongly recommended that this be set in hinted fonts.
    /// Bit 4: Instructions may alter advance width (the advance widths might not scale linearly).
    /// Bit 5: This bit is not used in OpenType, and should not be set in order to ensure compatible behavior on all platforms. If set, it may result in different behavior for vertical layout in some platforms. (See Apple’s specification for details regarding behavior in Apple platforms.)
    /// Bits 6 – 10: These bits are not used in OpenType and should always be cleared. (See Apple’s specification for details regarding legacy use in Apple platforms.)
    /// Bit 11: Font data is “lossless” as a result of having been subjected to optimizing transformation and/or compression (such as compression mechanisms defined by ISO/IEC 14496-18, MicroType® Express, WOFF 2.0, or similar) where the original font functionality and features are retained but the binary compatibility between input and output font files is not guaranteed. As a result of the applied transform, the DSIG table may also be invalidated.
    /// Bit 12: Font converted (produce compatible metrics).
    /// Bit 13: Font optimized for ClearType®. Note, fonts that rely on embedded bitmaps (EBDT) for rendering should not be considered optimized for ClearType, and therefore should keep this bit cleared.
    /// Bit 14: Last Resort font. If set, indicates that the glyphs encoded in the 'cmap' subtables are simply generic symbolic representations of code point ranges and do not truly represent support for those code points. If unset, indicates that the glyphs encoded in the 'cmap' subtables represent proper support for those code points.
    /// Bit 15: Reserved, set to 0.
    flags: u16,
    /// Set to a value from 16 to 16384. Any value in this range is valid. In fonts that have TrueType outlines, a power of 2 is recommended as this allows performance optimization in some rasterizers.
    unitsPerEm: u16,
    /// Number of seconds since 12:00 midnight that started January 1st, 1904, in GMT/UTC time zone.
    created: LONGDATETIME,
    /// Number of seconds since 12:00 midnight that started January 1st, 1904, in GMT/UTC time zone.
    modified: LONGDATETIME,
    /// Minimum x coordinate across all glyph bounding boxes.
    xMin: i16,
    /// Minimum y coordinate across all glyph bounding boxes.
    yMin: i16,
    /// Maximum x coordinate across all glyph bounding boxes.
    xMax: i16,
    /// Maximum y coordinate across all glyph bounding boxes.
    yMax: i16,
    /// Bit 0: Bold (if set to 1);
    /// Bit 1: Italic (if set to 1)
    /// Bit 2: Underline (if set to 1)
    /// Bit 3: Outline (if set to 1)
    /// Bit 4: Shadow (if set to 1)
    /// Bit 5: Condensed (if set to 1)
    /// Bit 6: Extended (if set to 1)
    /// Bits 7 – 15: Reserved (set to 0).
    macStyle: u16,
    /// Smallest readable size in pixels.
    lowestRecPPEM: u16,
    /// Deprecated (Set to 2).
    /// 0: Fully mixed directional glyphs;
    /// 1: Only strongly left to right;
    /// 2: Like 1 but also contains neutrals;
    /// -1: Only strongly right to left;
    /// -2: Like -1 but also contains neutrals.
    fontDirectionHint: i16,
    /// 0 for short offsets (Offset16), 1 for long (Offset32).
    indexToLocFormat: i16,
    /// 0 for current format.
    glyphDataFormat: i16,
};

/// Packed 32-bit value with major and minor version numbers. (See Table Version Numbers.)
const Version16Dot16 = u32;

/// Version 0.5
const MaxP_V05 = extern struct {
    /// 0x00005000 for version 0.5
    version: Version16Dot16,
    /// The number of glyphs in the font.
    numGlyphs: u16,
};

/// Version 1.0
const MaxP_V10 = extern struct {
    /// 0x00010000 for version 1.0.
    version: Version16Dot16,
    /// The number of glyphs in the font.
    numGlyphs: u16,
    /// Maximum points in a non-composite glyph.
    maxPoints: u16,
    /// Maximum contours in a non-composite glyph.
    maxContours: u16,
    /// Maximum points in a composite glyph.
    maxCompositePoints: u16,
    /// Maximum contours in a composite glyph.
    maxCompositeContours: u16,
    /// 1 if instructions do not use the twilight zone (Z0), or 2 if instructions do use Z0; should be set to 2 in most cases.
    maxZones: u16,
    /// Maximum points used in Z0.
    maxTwilightPoints: u16,
    /// Number of Storage Area locations.
    maxStorage: u16,
    /// Number of FDEFs, equal to the highest function number + 1.
    maxFunctionDefs: u16,
    /// Number of IDEFs.
    maxInstructionDefs: u16,
    /// Maximum stack depth across Font Program ('fpgm' table), CVT Program ('prep' table) and all glyph instructions (in the 'glyf' table).
    maxStackElements: u16,
    /// Maximum byte count for glyph instructions.
    maxSizeOfInstructions: u16,
    /// Maximum number of components referenced at “top level” for any composite glyph.
    maxComponentElements: u16,
    /// Maximum levels of recursion; 1 for simple components.
    maxComponentDepth: u16,
};

const FWORD = i16;
const UFWORD = u16;
const Hhea = packed struct {
    /// Major version number of the horizontal header table — set to 1.
    majorVersion: u16,
    /// Minor version number of the horizontal header table — set to 0.
    minorVersion: u16,
    /// Typographic ascent—see remarks below.
    ascender: FWORD,
    /// Typographic descent—see remarks below.
    descender: FWORD,
    /// Typographic line gap.
    /// Negative lineGap values are treated as zero in some legacy platform implementations.
    lineGap: FWORD,
    /// Maximum advance width value in 'hmtx' table.
    advanceWidthMax: UFWORD,
    /// Minimum left sidebearing value in 'hmtx' table for glyphs with contours (empty glyphs should be ignored).
    minLeftSideBearing: FWORD,
    /// Minimum right sidebearing value; calculated as min(aw - (lsb + xMax - xMin)) for glyphs with contours (empty glyphs should be ignored).
    minRightSideBearing: FWORD,
    /// Max(lsb + (xMax - xMin)).
    xMaxExtent: FWORD,
    /// Used to calculate the slope of the cursor (rise/run); 1 for vertical.
    caretSlopeRise: i16,
    /// 0 for vertical.
    caretSlopeRun: i16,
    /// The amount by which a slanted highlight on a glyph needs to be shifted to produce the best appearance. Set to 0 for non-slanted fonts
    caretOffset: i16,
    /// set to 0
    _reserved: i64,
    /// 0 for current format.
    metricDataFormat: i16,
    /// Number of hMetric entries in 'hmtx' table
    numberOfHMetrics: u16,
};

pub const LongHorMetric = extern struct {
    /// Advance width, in font design units.
    advanceWidth: UFWORD,
    /// Glyph left side bearing, in font design units.
    leftSideBearing: FWORD,
};

/// followed by groups: [numGroups]SequentialMapGroup, Array of SequentialMapGroup records.
const FmtSegmentedTable = extern struct {
    /// Subtable format; set to 12.
    format: u16,
    /// Reserved; set to 0
    reserved: u16,
    /// Byte length of this subtable (including the header)
    length: u32,
    /// For requirements on use of the language field, see “Use of the language field in 'cmap' subtables” in this document.
    language: u32,
    /// Number of groupings which follow
    numGroups: u32,
};

const SequentialMapGroup = extern struct {
    /// First character code in this group
    startCharCode: u32,
    /// Last character code in this group
    endCharCode: u32,
    /// Glyph index corresponding to the starting character code
    startGlyphID: u32,
};

/// 'name' table format
const Name = extern struct {
    platformID: u16,
    /// Platform-specific encoding ID.
    encodingID: u16,
    languageID: u16,
    // can be converted to a NameId enum
    nameID: u16,
    /// String length (in bytes).
    length: u16,
    /// String offset from start of storage area (in bytes).
    stringOffset: u16,
};

/// Name.nameId types
pub const NameId = enum(u16) {
    copyright,
    familyName,
    subfamilyName,
    uniqueId,
    fullName,
    version,
    postscriptName,
    trademark,
    manufacturer,
    designer,
    description,
    vendorUrl,
    designerUrl,
    licenseDesc,
    licenseInfoUrl,
    reserved,
    typographicFamilyName,
    typographicSubfamilyName,
    compatibleFull,
    sampleText,
    postScriptCidFindfontName,
    wwsFamilyName,
    wwsSubfamilyName,
    lightBackgroundPalette,
    darkBackgroundPalette,
    variationsPostScriptNamePrefix,
    invalid = std.math.maxInt(u16),
};

pub const Point = struct {
    xy: i32x2,
    onCurve: bool,

    pub fn init(x: i32, y: i32, onCurve: bool) Point {
        return .{ .xy = .init(x, y), .onCurve = onCurve };
    }
    pub fn init2(x: i32, y: i32) Point {
        return .{ .xy = .init(x, y), .onCurve = false };
    }
    pub fn vec2(p: Point) f32x2 {
        return p.xy.to(f32);
    }
};

pub const GlyphData = struct {
    codepoint: u21,
    glyphIndex: u32,
    points: []Point,
    /// these are +1 from what is read from the glyf/loca tables in order to
    /// simplify slicing, i.e. removing the +1 from `points[startIndex..endIndex+1]`
    contourEndIndices: []u32,
    advanceWidth: i32,
    leftSideBearing: i32,

    min: i32x2,
    max: i32x2,

    pub const zero: GlyphData = .{
        .points = &.{},
        .contourEndIndices = &.{},
        .codepoint = 0,
        .glyphIndex = 0,
        .advanceWidth = 0,
        .leftSideBearing = 0,
        .min = .zero,
        .max = .zero,
    };

    pub fn width(gd: GlyphData) i32 {
        return gd.max.x - gd.min.x;
    }
    pub fn height(gd: GlyphData) i32 {
        return gd.max.y - gd.min.y;
    }

    pub fn deinit(gd: *GlyphData, alloc: mem.Allocator) void {
        alloc.free(gd.points);
        alloc.free(gd.contourEndIndices);
    }
};

pub const PointList = std.ArrayListUnmanaged(Point);
pub const Contours = struct {
    points: PointList = .{},
    endIndices: std.ArrayListUnmanaged(u32) = .{},

    pub fn deinit(cs: *Contours, alloc: mem.Allocator) void {
        cs.points.deinit(alloc);
        cs.endIndices.deinit(alloc);
    }
};

/// map from codepoint to GlyphData
const GlyphMap = std.AutoArrayHashMapUnmanaged(u32, GlyphData);

// TODO use i32v2
pub const Box = extern struct {
    x0: i32,
    y0: i32,
    x1: i32,
    y1: i32,

    pub const zero = std.mem.zeroes(Box);
};

/// aka missing glyph codepoint
pub const maxNumGlyphs = 0xffff; // 65535

const VMetrics = extern struct { ascent: i16, descent: i16, lineGap: i16 };

pub const Font = struct {
    data: []const u8,
    tableLocations: [Table.numTags]u16 = [1]u16{Table.sentinel} ** Table.numTags,
    numGlyphs: u16,
    indexToLocFormat: i16,
    indexMap: u32,
    cffData: ?*CffData,

    pub const Data = struct {
        unitsPerEm: i32,
        glyphMap: GlyphMap = .{},

        pub fn deinit(d: *Data, alloc: mem.Allocator) void {
            deinitGlyphMap(&d.glyphMap, alloc);
        }
        pub fn deinitGlyphMap(m: *GlyphMap, alloc: mem.Allocator) void {
            for (m.values()) |*gd| gd.deinit(alloc);
            m.deinit(alloc);
        }

        pub fn getGlyph(d: Data, codepoint: u32) GlyphData {
            return d.glyphMap.get(codepoint) orelse d.glyphMap.get(maxNumGlyphs).?;
        }
    };

    pub fn init(alloc: mem.Allocator, fontData: []u8) !Font {
        const tableDirectoryPtr: *TableDirectory = @ptrCast(@alignCast(fontData[0..@sizeOf(TableDirectory)]));
        var tableDirectory = tableDirectoryPtr.*;
        byteSwapAll(TableDirectory, &tableDirectory);
        var font: Font = .{
            .data = fontData,
            .numGlyphs = maxNumGlyphs,
            .indexToLocFormat = 0,
            .indexMap = 0,
            .cffData = null,
        };
        {
            var i: u16 = 0;
            const tables: [*]const Table = @ptrCast(@alignCast(font.data.ptr + @sizeOf(TableDirectory)));
            while (i < tableDirectory.numTables) : (i += 1) {
                const tagBytes: [4]u8 = @bitCast(@intFromEnum(tables[i].tag));
                std.log.info("tag {s}", .{tagBytes});
                const tag = std.meta.intToEnum(Table.Tag, byteSwap(@intFromEnum(tables[i].tag))) catch |e| {
                    std.log.err("{s}. Unsupported tag '{s}'", .{ @errorName(e), tagBytes });
                    continue;
                };
                const tagIdx = tag.index();
                assert(font.tableLocations[tagIdx] == Table.sentinel);
                font.tableLocations[tagIdx] = i;
            }
        }

        if (!font.hasTable(.cmap)) return error.NoCmapTable;
        if (!font.hasTable(.head)) return error.NoHeadTable;
        if (!font.hasTable(.hhea)) return error.NoHheaTable;
        if (!font.hasTable(.hmtx)) return error.NoHmtxTable;
        if (font.hasTable(.glyf)) {
            if (!font.hasTable(.loca)) return error.NoLocaTable;
        } else {
            const cff = font.findTable(.CFF) orelse return error.NoCffTable;
            const cffData = try alloc.create(CffData);
            errdefer alloc.destroy(cffData);
            cffData.* = .{
                .fontdicts = .zero,
                .fdselect = .zero,
                .charstrings = .zero,
                .gsubrs = .zero,
                .subrs = .zero,
                // TODO this should use size from table (not 512MB)
                .cff = Buf.init(fontData.ptr + cff.offset, 512 * 1024 * 1024),
            };

            var b = cffData.cff;
            // read the header
            b.skip(2);
            b.seek(b.get8());
            // TODO the name INDEX could list multiple fonts, but we just use the first one.
            _ = b.cffGetIndex(); // name INDEX
            var topdictidx = b.cffGetIndex();
            var topdict = topdictidx.cffIndexGet(0);
            _ = b.cffGetIndex(); // string INDEX
            cffData.gsubrs = b.cffGetIndex();

            var cstype: u32 = 2;
            var charstrings: u32 = 0;
            var fdarrayoff: u32 = 0;
            var fdselectoff: u32 = 0;

            topdict.dictGetInts(17, 1, @ptrCast(&charstrings));
            topdict.dictGetInts(0x100 | 6, 1, @ptrCast(&cstype));
            topdict.dictGetInts(0x100 | 36, 1, @ptrCast(&fdarrayoff));
            topdict.dictGetInts(0x100 | 37, 1, @ptrCast(&fdselectoff));
            cffData.subrs = b.getSubrs(topdict);

            // we only support Type 2 charstrings
            if (cstype != 2) return error.CsType;
            if (charstrings == 0) return error.CharStrings;

            if (fdarrayoff != 0) {
                // looks like a CID font
                if (fdselectoff == 0) return error.FdSelectOff;
                b.seek(fdarrayoff);
                cffData.fontdicts = b.cffGetIndex();
                cffData.fdselect = b.range(fdselectoff, b.size - fdselectoff);
            }

            b.seek(charstrings);
            cffData.charstrings = b.cffGetIndex();
            font.cffData = cffData;
        }

        if (font.getTypedTable(.maxp)) |maxp| font.numGlyphs = maxp.numGlyphs;
        const head = font.getTypedTable(.head).?;
        font.indexToLocFormat = head.indexToLocFormat;

        const cmapTable = font.findTable(.cmap).?;
        const cmap = font.getTypedTable(.cmap).?;
        std.log.info("cmap {}", .{cmap});
        const encodings = font.getPtrAt(cmapTable.offset + @sizeOf(CmapHeader), [*]const Encoding);

        // --- Read through metadata for each character map to find the one we want to use ---
        for (0..cmap.numTables) |i| {
            var encoding = encodings[i];
            byteSwapAll(Encoding, &encoding);
            switch (encoding.platformID) {
                .windows => {
                    const eid = std.meta.intToEnum(MicrosoftEncoding, encoding.encodingID) catch
                        return error.InvalidMicrosoftEncoding;
                    switch (eid) {
                        .unicode_bmp, .unicode_full => {
                            font.indexMap = cmapTable.offset + encoding.subtableOffset;
                        },
                        else => {},
                    }
                },
                .unicode => {
                    font.indexMap = cmapTable.offset + encoding.subtableOffset;
                },
                else => {},
            }
        }

        if (font.indexMap == 0) {
            std.log.err("Font does not contain supported character map type (TODO)", .{});
            return error.CmapType;
        }

        return font;
    }

    pub fn deinit(font: *Font, alloc: mem.Allocator) void {
        if (font.cffData) |cff| alloc.destroy(cff);
    }

    /// return Data including a map from codepoint to GlyphData for each glyph
    /// in the font file.
    pub fn parse(font: *Font, alloc: mem.Allocator) !Data {
        const head = font.getTypedTable(.head).?;
        std.log.info("head {}", .{head});
        const unitsPerEm = head.unitsPerEm;
        std.log.info("unitsPerEm {} numGlyphs {}", .{ unitsPerEm, font.numGlyphs });

        var glyphMap = try font.createGlyphMap(alloc);
        errdefer Data.deinitGlyphMap(&glyphMap, alloc);
        std.log.info("glyph count {}", .{glyphMap.count()});

        try font.readAllGlyphs(alloc, &glyphMap);
        try font.applyLayoutInfo(&glyphMap);
        assert(glyphMap.contains(maxNumGlyphs));

        return .{
            .unitsPerEm = unitsPerEm,
            .glyphMap = glyphMap,
        };
    }

    fn getTables(font: Font) [*]const Table {
        return @ptrCast(@alignCast(font.data.ptr + @sizeOf(TableDirectory)));
    }

    fn findTable(font: Font, tag: Table.Tag) ?Table {
        const tableIndex = font.tableLocations[tag.index()];
        if (tableIndex == Table.sentinel) return null;
        var t = font.getTables()[tableIndex];
        byteSwapAll(Table, &t);
        return t;
    }

    fn hasTable(font: Font, tag: Table.Tag) bool {
        return font.tableLocations[tag.index()] != Table.sentinel;
    }

    fn TagTable(comptime tag: Table.Tag) type {
        return switch (tag) {
            .glyf => GlyphHeader,
            .cmap => CmapHeader,
            .head => Head,
            .maxp => MaxP_V05,
            .hhea => Hhea,
            else => unreachable,
        };
    }

    fn getTypedTable(font: Font, comptime tag: Table.Tag) ?TagTable(tag) {
        const T = TagTable(tag);
        const theader = font.findTable(tag) orelse return null;
        var t: T = @bitCast(font.data[theader.offset..][0 .. @bitSizeOf(T) / 8].*);
        byteSwapAll(T, &t);
        return t;
    }

    fn getPtr(font: Font, tag: Table.Tag, comptime Ptr: type) ?Ptr {
        const table = font.findTable(tag) orelse return null;
        return @ptrCast(@alignCast(font.data.ptr + table.offset));
    }
    fn getPtrAt(font: Font, offset: u32, comptime Ptr: type) Ptr {
        return @ptrCast(@alignCast(font.data.ptr + offset));
    }

    fn readInt(font: Font, comptime T: type, offset: u32) T {
        return mem.readInt(T, font.data[offset..][0..@sizeOf(T)], .big);
    }

    fn getGlyphLocation(font: Font, glyphIndex: u32) !u32 {
        if (glyphIndex >= font.numGlyphs) return error.NoGlyph;
        if (font.indexToLocFormat >= 2) return error.NoGlyph;
        const glyf = font.findTable(.glyf).?;
        const loca = font.findTable(.loca).?;

        const bytesPerLoc: u8 = if (font.indexToLocFormat == 0) 2 else 4;
        const isTwoByteEntry = bytesPerLoc == 2;

        const offset = loca.offset + glyphIndex * bytesPerLoc;
        const g1: u32, const g2: u32 = if (isTwoByteEntry) .{
            @as(u32, font.readInt(u16, offset)) * 2,
            @as(u32, font.readInt(u16, offset + 2)) * 2,
        } else .{
            font.readInt(u32, offset),
            font.readInt(u32, offset + 4),
        };
        return if (g1 == g2) error.NoGlyph else glyf.offset + g1;
    }

    /// Create a lookup from unicode to font's internal glyph index
    fn createGlyphMap(font: Font, alloc: mem.Allocator) !GlyphMap {
        const format = font.readInt(u16, font.indexMap);

        if (!(format == 12 or format == 13 or format == 4)) {
            std.log.err("Font cmap format not supported (TODO): {}", .{format});
            return error.CmapFormat;
        }
        std.log.info("format {}", .{format});

        var map = GlyphMap{};

        if (format == 4) {
            const tblp = font.getPtrAt(font.indexMap, *const SegmentToDelta);
            var tbl = tblp.*;
            byteSwapAll(SegmentToDelta, &tbl);
            std.log.debug("tbl {}", .{tbl});
            assert(tbl.format == format);

            const segCount = tbl.segCountX2 / 2;
            comptime assert(@sizeOf(SegmentToDelta) == 14);
            comptime assert(@sizeOf(SegmentToDelta) == @bitSizeOf(SegmentToDelta) / 8);
            const ptr = font.data.ptr + font.indexMap + @sizeOf(SegmentToDelta);
            const endCodes: [*]const u16 = @ptrCast(@alignCast(ptr));
            assert(endCodes[segCount - 1] == maxNumGlyphs);
            assert(endCodes[segCount] == 0); // reservedPad should == 0
            const startCodes: [*]const u16 = endCodes + segCount + 1; // +1 to skip reservedPad
            assert(startCodes[segCount - 1] == maxNumGlyphs);
            const idDeltas: [*]const i16 = @ptrCast(startCodes + segCount);
            const idRangeOffsets: [*]const u16 = @ptrCast(idDeltas + segCount);

            for (0..segCount) |i| {
                const endCode = byteSwap(endCodes[i]);
                const startCode = byteSwap(startCodes[i]);
                var charCode = startCode;

                if (charCode == maxNumGlyphs) break; // not sure about this (hack to avoid out of bounds on a specific font)

                while (charCode <= endCode) {
                    var glyphIndex: u32 = 0;
                    // If idRangeOffset is 0, the glyph index can be calculated directly
                    const idRangeOffset = byteSwap(idRangeOffsets[i]);

                    if (idRangeOffset == 0) {
                        const idDelta = byteSwap(idDeltas[i]);
                        const glyphId = @as(i32, charCode) + idDelta;
                        // debug("glyphId {}\n", .{glyphId});
                        glyphIndex = @as(u32, @bitCast(if (glyphId < 0)
                            glyphId + maxNumGlyphs
                        else
                            glyphId)) & maxNumGlyphs;
                    }
                    // Otherwise, glyph index needs to be looked up from an array
                    else {
                        // glyphId = *(idRangeOffset[i]/2 + (c - startCode[i]) + &idRangeOffset[i])
                        const gptr: [*]const u16 = @ptrCast(&idRangeOffsets[i]);
                        glyphIndex = byteSwap((gptr + idRangeOffset / 2 + (charCode - startCode))[0]);
                    }

                    var glyph: GlyphData = .zero;
                    glyph.glyphIndex = glyphIndex;
                    try map.putNoClobber(alloc, charCode, glyph);
                    if (glyphIndex == 0) {
                        const gop = try map.getOrPut(alloc, maxNumGlyphs);
                        if (!gop.found_existing) gop.value_ptr.* = glyph;
                    }
                    charCode += 1;
                }
            }
        } else if (format == 12 or format == 13) {
            const tblp = font.getPtrAt(font.indexMap, *align(1) const FmtSegmentedTable);
            var tbl = tblp.*;
            byteSwapAll(FmtSegmentedTable, &tbl);
            std.log.debug("tbl {}", .{tbl});
            assert(tbl.format == format);
            const ptr = font.data.ptr + font.indexMap + @sizeOf(FmtSegmentedTable);
            const mapGroups: [*]align(1) const SequentialMapGroup = @ptrCast(@alignCast(ptr));
            for (0..tbl.numGroups) |i| {
                const mapGroup = mapGroups[i];
                const startCharCode = byteSwap(mapGroup.startCharCode);
                const endCharCode = byteSwap(mapGroup.endCharCode);
                const startGlyphID = byteSwap(mapGroup.startGlyphID);
                const numChars = endCharCode - startCharCode + 1;
                var charCodeOffset: u32 = 0;
                while (charCodeOffset < numChars) : (charCodeOffset += 1) {
                    const glyphIndex = if (format == 12)
                        startGlyphID + charCodeOffset
                    else if (format == 13)
                        startGlyphID
                    else
                        unreachable;

                    const charCode = startCharCode + charCodeOffset;
                    var glyph: GlyphData = .zero;
                    glyph.glyphIndex = glyphIndex;
                    try map.putNoClobber(alloc, charCode, glyph);
                    if (glyphIndex == 0) {
                        const gop = try map.getOrPut(alloc, maxNumGlyphs);
                        if (!gop.found_existing) gop.value_ptr.* = glyph;
                    }
                }
            }
        } else {
            std.log.err("unsupported format {}", .{format});
            return error.UnsupportedFormat;
        }

        // ensure the map has an entry at maxNumGlyphs
        if (!map.contains(maxNumGlyphs)) {
            var glyph: GlyphData = .zero;
            glyph.glyphIndex = 0;
            try map.putNoClobber(alloc, maxNumGlyphs, glyph);
        }
        assert(map.contains(maxNumGlyphs));

        return map;
    }

    pub fn findGlyphIndex(font: Font, codepoint: u21) !u32 {
        const format = font.readInt(u16, font.indexMap);
        std.log.debug("findGlyphIndex format {} codepoint {}/'{u}'", .{ format, codepoint, codepoint });
        switch (format) {
            4 => {
                if (codepoint > maxNumGlyphs) return 0;
                const tblp = font.getPtrAt(font.indexMap, *const SegmentToDelta);
                var tbl = tblp.*;
                byteSwapAll(SegmentToDelta, &tbl);
                std.log.debug("tbl {}", .{tbl});
                assert(tbl.format == 4);

                const segCount = tbl.segCountX2 >> 1;
                var searchRange = tbl.searchRange >> 1;
                var entrySelector = tbl.entrySelector;
                const rangeShift = tbl.rangeShift >> 1;
                const endCount = font.indexMap + 14;
                var search = endCount;

                // they lie from endCount .. endCount + segCount
                // but searchRange is the nearest power of two, so...
                if (codepoint >= font.readInt(u16, search + rangeShift * 2))
                    search += rangeShift * 2;
                // now decrement to bias correctly to find smallest
                search -= 2;
                std.log.debug("entrySelector {}", .{entrySelector});
                while (entrySelector != 0) {
                    searchRange >>= 1;
                    const end = font.readInt(u16, search + searchRange * 2);
                    if (codepoint > end) search += searchRange * 2;
                    entrySelector -= 1;
                }
                search += 2;
                const i: u16 = @truncate((search - endCount) >> 1);
                std.log.debug("search {} endCount {} i {}", .{ search, endCount, i });
                const ptr = font.data.ptr + font.indexMap + @sizeOf(SegmentToDelta);
                const endCodes: [*]const u16 = @ptrCast(@alignCast(ptr));
                assert(endCodes[segCount - 1] == maxNumGlyphs);
                assert(endCodes[segCount] == 0); // reservedPad should == 0
                const startCodes: [*]const u16 = endCodes + segCount + 1; // +1 to skip reservedPad
                assert(startCodes[segCount - 1] == maxNumGlyphs);
                const idDeltas: [*]const i16 = @ptrCast(startCodes + segCount);
                const idRangeOffsets: [*]const u16 = @ptrCast(idDeltas + segCount);

                const startCode = byteSwap(startCodes[i]);
                const endCode = byteSwap(endCodes[i]);
                const idRangeOffset = byteSwap(idRangeOffsets[i]);
                std.log.debug("startCode {} codepoint {} endCode {} idDelta {} idRangeOffset {}", .{ startCode, codepoint, endCode, byteSwap(idDeltas[i]), idRangeOffset });
                if (codepoint < startCode or codepoint > endCode)
                    return 0;
                if (idRangeOffset == 0) {
                    const idDelta = byteSwap(idDeltas[i]);
                    const cp32: i32 = @bitCast(@as(u32, codepoint));
                    const glyphId = cp32 + idDelta;
                    return @as(u32, @bitCast(if (glyphId < 0)
                        glyphId + maxNumGlyphs
                    else
                        glyphId)) & maxNumGlyphs;
                } else {
                    // Otherwise, glyph index needs to be looked up from an array
                    // glyphId = *(idRangeOffset[i]/2 + (c - startCode[i]) + &idRangeOffset[i])
                    const gptr: [*]const u16 = @ptrCast(&idRangeOffsets[i]);
                    return byteSwap((gptr + idRangeOffset / 2 + (codepoint - startCode))[0]);
                }
            },
            12, 13 => {
                const numGroups = font.readInt(u32, font.indexMap + @offsetOf(FmtSegmentedTable, "numGroups"));
                std.log.info("numGroups {}", .{numGroups});
                const groups = font.getPtrAt(font.indexMap + @sizeOf(FmtSegmentedTable), [*]align(1) const SequentialMapGroup);
                // Binary search the right group.
                var low: u32 = 0;
                var high = numGroups;
                while (low < high) {
                    const mid = low + ((high - low) >> 1); // rounds down, so low <= mid < high
                    const startCode = byteSwap(groups[mid].startCharCode);
                    const endCode = byteSwap(groups[mid].endCharCode);

                    if (codepoint < startCode)
                        high = mid
                    else if (codepoint > endCode)
                        low = mid + 1
                    else {
                        const startGlyph = byteSwap(groups[mid].startGlyphID);
                        return if (format == 12)
                            startGlyph + codepoint - startCode
                        else // format == 13
                            startGlyph;
                    }
                }
                return 0;
            },
            else => return error.Format,
        }
    }

    fn readAllGlyphs(font: *Font, alloc: mem.Allocator, glyphMap: *GlyphMap) !void {
        std.log.info("readAllGlyphs() glyphMap.len {}", .{glyphMap.count()});

        for (glyphMap.keys(), glyphMap.values()) |k, *v| {
            var contours: Contours = .{};
            defer contours.deinit(alloc);
            if (font.readGlyph(alloc, v.glyphIndex, &contours)) |glyphData| {
                v.* = glyphData;
            } else |e| switch (e) {
                error.NoGlyph => v.* = GlyphData.zero,
                else => return e,
            }
            v.codepoint = @intCast(k);
            std.log.debug("readGlyph done {u}:{} with {} points", .{ v.codepoint, v.codepoint, v.points.len });
        }
    }

    const ReadGlyphError = mem.Allocator.Error || error{
        EndOfStream,
        ExpectedCompoundGlyph,
        ExpectedSimpleGlyph,
        NoGlyph,
        Charstring,
        NoParentPoints,
        NoChildPoints,
        Recursion,
        NoHhea,
        NoHmtx,
        Todo,
    } || std.meta.IntToEnumError;

    pub fn readGlyph(
        font: *const Font,
        alloc: mem.Allocator,
        glyphIndex: u32,
        contours: *Contours,
    ) ReadGlyphError!GlyphData {
        var glyph = try if (font.cffData == null)
            font.readGlyphTT(alloc, glyphIndex, contours)
            // else if (use_c)
            //     font.readGlyphT2Old(alloc, glyphIndex)
        else
            t2.readGlyph(font, alloc, glyphIndex, contours);
        const layout = try font.getLayoutInfo(glyphIndex);
        glyph.leftSideBearing = layout.leftSideBearing;
        glyph.advanceWidth = layout.advanceWidth;
        return glyph;
    }

    fn readGlyphTT(
        font: *const Font,
        alloc: mem.Allocator,
        glyphIndex: u32,
        contours: *Contours,
    ) ReadGlyphError!GlyphData {
        const glyphLocation = try font.getGlyphLocation(glyphIndex);
        const contourCount = font.readInt(i16, glyphLocation);

        // Glyph is either simple or compound
        // * Simple: outline data is stored here directly
        // * Compound: two or more simple glyphs need to be looked up, transformed, and combined
        const isSimpleGlyph = contourCount >= 0;
        return if (isSimpleGlyph)
            font.readSimpleGlyph(alloc, glyphLocation, glyphIndex, contours)
        else
            font.readCompoundGlyph(alloc, glyphLocation, glyphIndex, contours);
    }

    const Flags = packed struct(u8) {
        onCurve: bool,
        isSingleByteX: bool,
        isSingleByteY: bool,
        repeat: bool,
        instructionX: bool,
        instructionY: bool,
        _padding: u2,
    };

    /// Read a simple glyph from the 'glyf' table
    fn readSimpleGlyph(
        font: Font,
        alloc: mem.Allocator,
        glyphLocation: u32,
        glyphIndex: u32,
        contours: *Contours,
    ) !GlyphData {
        var fbs = std.io.fixedBufferStream(font.data[glyphLocation..]);
        const reader = fbs.reader();

        const contourCountI = try reader.readInt(i16, .big);
        if (contourCountI < 0) return error.ExpectedSimpleGlyph;
        const min = i32x2.init(
            try reader.readInt(i16, .big),
            try reader.readInt(i16, .big),
        );
        const max = i32x2.init(
            try reader.readInt(i16, .big),
            try reader.readInt(i16, .big),
        );
        const contourCount: u16 = @bitCast(contourCountI);
        try contours.endIndices.ensureUnusedCapacity(alloc, contourCount);
        var numPoints: u32 = 0;
        for (0..contourCount) |_| {
            const endIndex: u32 = try reader.readInt(u16, .big) + 1;
            numPoints = @max(numPoints, endIndex);
            contours.endIndices.appendAssumeCapacity(endIndex);
        }
        const instructionsLength = try reader.readInt(u16, .big);
        try reader.skipBytes(@intCast(instructionsLength), .{}); // skip instructions (hinting stuff)

        const allFlags = try alloc.alloc(Flags, numPoints);
        defer alloc.free(allFlags);
        var i: u32 = 0;
        while (i < numPoints) : (i += 1) {
            const flag: Flags = @bitCast(try reader.readByte());
            allFlags[i] = flag;
            if (flag.repeat) {
                const repeatCount = try reader.readByte();
                for (0..repeatCount) |_| {
                    i += 1;
                    allFlags[i] = flag;
                }
            }
        }

        try contours.points.ensureUnusedCapacity(alloc, numPoints);
        contours.points.items.len += numPoints;

        try readCoords(reader, true, allFlags, &contours.points);
        try readCoords(reader, false, allFlags, &contours.points);

        return .{
            .glyphIndex = glyphIndex,
            .points = try contours.points.toOwnedSlice(alloc),
            .contourEndIndices = try contours.endIndices.toOwnedSlice(alloc),
            .min = min,
            .max = max,
            .codepoint = undefined,
            .advanceWidth = undefined,
            .leftSideBearing = undefined,
        };
    }

    fn readCoords(
        reader: anytype,
        readingX: bool,
        allFlags: []const Flags,
        points: *PointList,
    ) !void {
        var min: i32 = std.math.maxInt(i32);
        var max: i32 = std.math.minInt(i32);

        var coordVal: i32 = 0;

        for (0..allFlags.len) |i| {
            const currFlag = allFlags[i];

            if (readingX) {
                if (currFlag.isSingleByteX) {
                    // Offset value is represented with 1 byte (unsigned)
                    // Here the instruction flag tells us whether to add or subtract the offset
                    const coordOffset: i16 = try reader.readByte();
                    const positiveOffset = currFlag.instructionX;
                    coordVal += if (positiveOffset) coordOffset else -coordOffset;
                } else if (!currFlag.instructionX) {
                    // Offset value is represented with 2 bytes (signed)
                    // Here the instruction flag tells us whether an offset value exists or not
                    coordVal += try reader.readInt(i16, .big);
                }
            } else {
                if (currFlag.isSingleByteY) {
                    const coordOffset: i16 = try reader.readByte();
                    const positiveOffset = currFlag.instructionY;
                    coordVal += if (positiveOffset) coordOffset else -coordOffset;
                } else if (!currFlag.instructionY) {
                    coordVal += try reader.readInt(i16, .big);
                }
            }

            if (readingX)
                points.items[i].xy.x = coordVal
            else
                points.items[i].xy.y = coordVal;
            points.items[i].onCurve = currFlag.onCurve;

            min = @min(min, coordVal);
            max = @max(max, coordVal);
        }
    }

    fn readCompoundGlyph(
        font: *const Font,
        alloc: mem.Allocator,
        glyphLocation: u32,
        glyphIndex: u32,
        contours: *Contours,
    ) !GlyphData {
        var fbs = std.io.fixedBufferStream(font.data[glyphLocation..]);
        const reader = fbs.reader();

        const contourCount = try reader.readInt(i16, .big);
        if (contourCount >= 0) return error.ExpectedCompoundGlyph;
        const min = i32x2.init(
            try reader.readInt(i16, .big),
            try reader.readInt(i16, .big),
        );
        const max = i32x2.init(
            try reader.readInt(i16, .big),
            try reader.readInt(i16, .big),
        );
        std.log.debug("readCompoundGlyph() min {} max {}", .{ min, max });

        while (true) {
            const flags: CompoundFlags = @bitCast(try reader.readInt(u16, .big));
            const childGlyphIndex = try reader.readInt(u16, .big);
            std.log.debug(
                "childGlyphIndex {} flags xy:{} words:{}",
                .{ childGlyphIndex, flags.args_are_xy_values, flags.arg_1_and_2_are_words },
            );
            // If compound glyph refers to itself, stop.  this might be a bug.
            if (try font.getGlyphLocation(childGlyphIndex) == glyphLocation) return error.Recursion;

            var mtx = [_]f32{ 1, 0, 0, 1, 0, 0 };
            // Read args (these are either x/y offsets, or point number)
            const pcIds: ?[2]u16 = if (flags.args_are_xy_values) blk: {
                if (flags.arg_1_and_2_are_words) {
                    mtx[4] = @floatFromInt(try reader.readInt(i16, .big));
                    mtx[5] = @floatFromInt(try reader.readInt(i16, .big));
                } else {
                    mtx[4] = @floatFromInt(try reader.readByte());
                    mtx[5] = @floatFromInt(try reader.readByte());
                }
                break :blk null;
            } else blk: {
                // from https://learn.microsoft.com/en-us/typography/opentype/spec/glyf#composite-glyph-description
                // The argument1 and argument2 fields of the component glyph
                // record are used to determine the placement of the child
                // component glyph within the parent composite glyph. They are
                // interpreted either as an offset vector or as points from the
                // parent and the child, according to whether the
                // ARGS_ARE_XY_VALUES flag is set. This flag must always be set
                // for the first component of a composite glyph.

                // If ARGS_ARE_XY_VALUES is not set, then argument1 is a point
                // number in the parent glyph (from contours incoporated and
                // re-numbered from previous component glyphs); and argument2 is a
                // point number (prior to re-numbering) from the child component
                // glyph. Phantom points from the parent or the child may be
                // referenced. The child component glyph is positioned within the
                // parent glyph by aligning the two points. If a scale or transform
                // matrix is provided, the transformation is applied to the child’s
                // point before the points are aligned.

                // more info
                //  https://learn.microsoft.com/en-us/typography/opentype/spec/gvar#inferred-deltas-for-un-referenced-point-numbers
                //  https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6glyf.html

                // from https://stackoverflow.com/questions/52031846/truetype-font-args-are-xy-values-meaning
                //   In other words, let m be the first short and n be the
                //   second, then the coordinates of point n of the new
                //   component should have the same coordinates as point m of
                //   the so far constructed compound glyph.

                // none of these have libs implemented this feature: stb_truetype, go truetype, https://github.com/RazrFalcon/ttf-parser.
                // freetype and python fonttools are the only codebases i found that implemented it.
                // i can't understand whats happening in freetype yet
                // python fonttools
                // https://github.com/fonttools/fonttools/blob/682d72ab6a12bbdd04b2c37fbacef83501327054/Lib/fontTools/ttLib/tables/_g_l_y_f.py#L1213

                //two point numbers.
                //the first point number indicates the point that is to be matched to the new glyph.
                //The second number indicates the new glyph's “matched” point.
                //Once a glyph is added,its point numbers begin directly after the last glyphs (endpoint of first glyph + 1)

                const parentIndex, const childIndex = if (flags.arg_1_and_2_are_words) .{
                    try reader.readInt(u16, .big),
                    try reader.readInt(u16, .big),
                } else .{
                    try reader.readByte(),
                    try reader.readByte(),
                };

                // for (glyphMap.values(), 0..) |v, i|
                //     std.log.debug("map[{}] glyphIndex {} codepoint {u}:{}", .{ i, v.glyphIndex, v.codepoint, v.codepoint });

                break :blk .{ parentIndex, childIndex };

                // match l-th (child) point of the newly loaded component to the k-th (parent) point
                // of the previously loaded components.

                // if (true) {
                //     std.log.err("TODO: Args1&2 are point indices to be matched, rather than offsets", .{});
                //     return error.Todo;
                // }
            };

            if (flags.we_have_a_scale) {
                mtx[0] = @floatCast(try readFixedPoint2Dot14(reader));
                mtx[1] = 0;
                mtx[2] = 0;
                mtx[3] = mtx[0];
            } else if (flags.we_have_an_x_and_y_scale) {
                mtx[0] = @floatCast(try readFixedPoint2Dot14(reader));
                mtx[1] = 0;
                mtx[2] = 0;
                mtx[3] = @floatCast(try readFixedPoint2Dot14(reader));
            } else if (flags.we_have_a_two_by_two) {
                mtx[0] = @floatCast(try readFixedPoint2Dot14(reader));
                mtx[1] = @floatCast(try readFixedPoint2Dot14(reader));
                mtx[2] = @floatCast(try readFixedPoint2Dot14(reader));
                mtx[3] = @floatCast(try readFixedPoint2Dot14(reader));
            }

            const m = @sqrt(mtx[0] * mtx[0] + mtx[1] * mtx[1]);
            const n = @sqrt(mtx[2] * mtx[2] + mtx[3] * mtx[3]);

            const pos = fbs.pos;
            // TODO: maybe append directly to contours if possible to decrease memory pressure?
            var childContours: Contours = .{};
            var childGlyph = font.readGlyph(alloc, childGlyphIndex, &childContours) catch |e| switch (e) {
                error.NoGlyph => break,
                else => return e,
            };
            defer childGlyph.deinit(alloc);
            fbs.pos = pos;

            for (0..childGlyph.points.len) |i| {
                const point = childGlyph.points[i].vec2();
                childGlyph.points[i].xy = .from(
                    m * (mtx[0] * point.x + mtx[2] * point.y + mtx[4]),
                    n * (mtx[1] * point.x + mtx[3] * point.y + mtx[5]),
                );
            }
            try contours.endIndices.ensureUnusedCapacity(alloc, childGlyph.contourEndIndices.len);
            // Add all contour end indices from the simple glyph component to the compound glyph's data
            // Note: indices must be offset to account for previously-added component glyphs
            for (childGlyph.contourEndIndices) |endIndex| {
                contours.endIndices.appendAssumeCapacity(endIndex + @as(u32, @intCast(contours.points.items.len)));
            }
            try contours.points.appendSlice(alloc, childGlyph.points);
            if (pcIds) |ids| {
                std.log.warn("pcIds {any} parent points {} child points {}", .{ ids, contours.points.items.len, childGlyph.points.len });
                return error.Todo;
            }

            if (!flags.more_components) break;
        }
        // std.log.info("readCompoundGlyph() points {any}", .{points.items});

        return .{
            .glyphIndex = glyphIndex,
            .points = try contours.points.toOwnedSlice(alloc),
            .contourEndIndices = try contours.endIndices.toOwnedSlice(alloc),
            .min = min,
            .max = max,
            .codepoint = undefined,
            .advanceWidth = undefined,
            .leftSideBearing = undefined,
        };
    }

    const CompoundFlags = packed struct(u16) {
        /// Bit 0: If this is set, the arguments are 16-bit (uint16 or int16); otherwise, they are bytes (uint8 or int8).
        arg_1_and_2_are_words: bool,
        /// Bit 1: If this is set, the arguments are signed xy values; otherwise, they are unsigned point numbers.
        args_are_xy_values: bool,
        /// Bit 2: If set and ARGS_ARE_XY_VALUES is also set, the xy values are rounded to the nearest grid line. Ignored if ARGS_ARE_XY_VALUES is not set.
        round_xy_to_grid: bool,
        /// Bit 4: reserved
        _reserved1: bool,
        /// Bit 3: This indicates that there is a simple scale for the component. Otherwise, scale = 1.0.
        we_have_a_scale: bool,
        /// Bit 5: Indicates at least one more glyph after this one.
        more_components: bool,
        /// Bit 6: The x direction will use a different scale from the y direction.
        we_have_an_x_and_y_scale: bool,
        /// Bit 7: There is a 2 by 2 transformation that will be used to scale the component.
        we_have_a_two_by_two: bool,
        /// Bit 8: Following the last component are instructions for the composite glyph.
        we_have_instructions: bool,
        /// Bit 9: If set, this forces the aw and lsb (and rsb) for the composite to be equal to those from this component glyph. This works for hinted and unhinted glyphs.
        use_my_metrics: bool,
        /// Bit 10: If set, the components of the compound glyph overlap. Use of this flag is not required — that is, component glyphs may overlap without having this flag set. When used, it must be set on the flag word for the first component. Some rasterizer implementations may require fonts to use this flag to obtain correct behavior — see additional remarks, above, for the similar OVERLAP_SIMPLE flag used in simple-glyph descriptions.
        overlap_compound: bool,
        /// Bit 11: The composite is designed to have the component offset scaled. Ignored if ARGS_ARE_XY_VALUES is not set.
        scaled_component_offset: bool,
        /// Bit 12: The composite is designed not to have the component offset scaled. Ignored if ARGS_ARE_XY_VALUES is not set.
        unscaled_component_offset: bool,
        /// Bits 4, 13, 14 and 15 are reserved: set to 0.
        _reserved2: u3,
    };

    fn readFixedPoint2Dot14(reader: anytype) !f64 {
        return uInt16ToFixedPoint2Dot14(try reader.readInt(u16, .big));
    }

    fn uInt16ToFixedPoint2Dot14(raw: u16) f64 {
        return @as(f64, @floatFromInt(@as(i32, @intCast(raw)))) / @as(f64, (1 << 14));
    }

    // Get horizontal layout information from the "hhea" and "hmtx" tables
    fn applyLayoutInfo(font: Font, glyphMap: *GlyphMap) !void {
        for (glyphMap.values()) |*g| {
            const layout = try font.getLayoutInfo(g.glyphIndex);
            g.advanceWidth = layout.advanceWidth;
            g.leftSideBearing = layout.leftSideBearing;
        }
    }

    // Get horizontal layout information from the "hhea" and "hmtx" tables for the given glyphIndex
    pub fn getLayoutInfo(font: Font, glyphIndex: u32) !LongHorMetric {
        const hhea = font.getTypedTable(.hhea) orelse return error.NoHhea;
        const numAdvanceWidthMetrics = hhea.numberOfHMetrics;

        // Get the advance width and leftsideBearing metrics from the 'hmtx' table
        const hmetrics = font.getPtr(.hmtx, [*]const LongHorMetric) orelse
            return error.NoHmtx;

        if (glyphIndex < numAdvanceWidthMetrics) {
            const hmetric = hmetrics[glyphIndex];
            return .{
                .advanceWidth = byteSwap(hmetric.advanceWidth),
                .leftSideBearing = byteSwap(hmetric.leftSideBearing),
            };
        }

        // Some fonts have a run of monospace characters at the end
        const numRem = glyphIndex - numAdvanceWidthMetrics;
        const lastHmetric = hmetrics[numAdvanceWidthMetrics - 1];
        const lsbs: [*]const i16 = @ptrCast(@alignCast(hmetrics + numAdvanceWidthMetrics));

        return .{
            .advanceWidth = byteSwap(lastHmetric.advanceWidth),
            .leftSideBearing = byteSwap(lsbs[numRem]),
        };
    }

    pub fn vMetrics(font: Font) VMetrics {
        const hhea = font.findTable(.hhea).?.offset;
        return .{
            .ascent = font.readInt(i16, hhea + 4),
            .descent = font.readInt(i16, hhea + 6),
            .lineGap = font.readInt(i16, hhea + 8),
        };
    }
    pub fn scaleForPixelHeight(font: Font, height: f32) f32 {
        const vmetrics = font.vMetrics();
        const fheight: f32 = @floatFromInt(vmetrics.ascent - vmetrics.descent);
        return height / fheight;
    }

    pub fn codepointBitmapBoxSubpixel(font: *const Font, codepoint: u21, scaleXy: [2]f32, shiftXy: [2]f32) !Box {
        const glyphIndex = try font.findGlyphIndex(codepoint);
        std.log.info("glyphIndex {}", .{glyphIndex});
        return font.glyphBitmapBoxSubpixel(glyphIndex, scaleXy, shiftXy);
    }
    pub fn glyphBitmapBoxSubpixel(font: *const Font, glyphIndex: u32, scaleXy: [2]f32, shiftXy: [2]f32) Box {
        return if (font.glyphBox(glyphIndex, null)) |box| .{
            .x0 = @intFromFloat(std.math.floor(@as(f32, @floatFromInt(box.x0)) * scaleXy[0] + shiftXy[0])),
            .y0 = @intFromFloat(std.math.floor(@as(f32, @floatFromInt(-box.y1)) * scaleXy[1] + shiftXy[1])),
            .x1 = @intFromFloat(std.math.ceil(@as(f32, @floatFromInt(box.x1)) * scaleXy[0] + shiftXy[0])),
            .y1 = @intFromFloat(std.math.ceil(@as(f32, @floatFromInt(-box.y0)) * scaleXy[1] + shiftXy[1])),
        }
        // e.g. space character
        else Box.zero;
    }

    pub fn glyphBox(font: *const Font, glyphIndex: u32, outNumVertices: ?*u32) ?Box {
        if (font.cffData != null) {
            return t2.glyphInfo(font, glyphIndex, outNumVertices);
        } else {
            const g = font.getGlyphLocation(glyphIndex) catch |e| {
                std.log.err("{s}", .{@errorName(e)});
                if (outNumVertices) |n| n.* = 0;
                return null;
            };
            std.log.info("glyphBox() g {}", .{g});

            if (outNumVertices) |n| n.* = 1;

            return .{
                .x0 = font.readInt(i16, g + 2),
                .y0 = font.readInt(i16, g + 4),
                .x1 = font.readInt(i16, g + 6),
                .y1 = font.readInt(i16, g + 8),
            };
        }
    }

    pub fn debugNameTable(font: *Font) !void {
        const tbl = font.findTable(.name) orelse return error.NoNameTable;
        const version = font.readInt(u16, tbl.offset);
        const count = font.readInt(u16, tbl.offset + 2);
        const offset = font.readInt(u16, tbl.offset + 4);

        debug("name version {} count {} offset {}\n", .{ version, count, offset });
        // var offset = tbl.offset;
        // const end = count * @sizeOf(Name);
        const names = font.getPtrAt(tbl.offset + 6, [*]const Name);
        for (0..count) |i| {
            var name = names[i];
            byteSwapAll(Name, &name);
            // debug("name {}\n", .{name});
            const nameId = std.meta.intToEnum(NameId, name.nameID) catch .invalid;
            const s = font.data[tbl.offset + offset + name.stringOffset ..][0..name.length];
            debug("{}:{s}: {s}\n", .{ name.nameID, @tagName(nameId), s });
        }
    }

    pub fn getName(font: *const Font, nameId: NameId) ?[]const u8 {
        const tbl = font.findTable(.name) orelse return null;
        const count = font.readInt(u16, tbl.offset + 2);
        const offset = font.readInt(u16, tbl.offset + 4);
        const names = font.getPtrAt(tbl.offset + 6, [*]const Name);
        for (0..count) |i| {
            var name = names[i];
            byteSwapAll(Name, &name);

            if (nameId == std.meta.intToEnum(NameId, name.nameID) catch .invalid) {
                return font.data[tbl.offset + offset + name.stringOffset ..][0..name.length];
            }
        }
        return null;
    }

    fn maxNameLen(comptime fields: anytype) comptime_int {
        comptime {
            var len: comptime_int = 0;
            for (fields) |field| {
                len = @max(field.name.len, len);
            }
            return len;
        }
    }

    fn dumpTable(font: Font, writer: anytype, comptime tag: Table.Tag) !void {
        try writer.print("{s}\n", .{@tagName(tag)});
        const h = font.getTypedTable(tag).?;
        const fields = @typeInfo(@TypeOf(h)).@"struct".fields;
        const maxLen = maxNameLen(fields);
        inline for (fields) |field| {
            try writer.print("  {s}:", .{field.name});
            try writer.writeByteNTimes(' ', maxLen - field.name.len + 1);
            try writer.print("{}\n", .{@field(h, field.name)});
        }
    }
    fn dumpStruct(writer: anytype, tbl: anytype) !void {
        const fields = @typeInfo(@TypeOf(tbl)).@"struct".fields;
        const maxLen = maxNameLen(fields);
        inline for (fields) |field| {
            try writer.print("  {s}:", .{field.name});
            try writer.writeByteNTimes(' ', maxLen - field.name.len + 1);
            try writer.print("{}\n", .{@field(tbl, field.name)});
        }
    }

    const DumpFmt = struct {
        font: Font,
        codepoint: ?u21,
        alloc: mem.Allocator,

        pub fn format(f: DumpFmt, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            const font = f.font;
            try writer.print("-- dump --\n{?s}\n", .{font.getName(.uniqueId)});
            try writer.print("numGlyphs {}\n", .{font.numGlyphs});

            if (f.codepoint) |cp| blk: {
                const glyphIndex = try font.findGlyphIndex(cp);
                try writer.print("-- codepoint '{u}' --\n  glyphIndex {}\n", .{ cp, glyphIndex });
                var contours: Contours = .{};
                errdefer contours.deinit(f.alloc);
                var glyph = font.readGlyph(f.alloc, glyphIndex, &contours) catch break :blk;
                defer glyph.deinit(f.alloc);
                try writer.print("  min {}\n  max {}\n", .{ glyph.min, glyph.max });
                try writer.print(
                    "  advanceWidth {}\n  leftSideBearing {}\n  points {}\n",
                    .{ glyph.advanceWidth, glyph.leftSideBearing, glyph.points.len },
                );
                var end: u32 = 0;
                for (glyph.contourEndIndices, 0..) |ei, i| {
                    try writer.print("  -- contour {}: {} points --\n", .{ i, ei - end });
                    for (glyph.points[end..ei], 0..) |pt, j| {
                        try writer.print(
                            "  {s}{d:.0}\x1b[0m {}/{}\n",
                            .{ if (pt.onCurve) "\x1b[1;94m" else "\x1b[1;91m", pt.vec2(), j, j + end },
                        );
                    }
                    end = ei;
                }
                {
                    try writer.print("name\n", .{});
                    var maxLen: usize = 0;
                    inline for (@typeInfo(NameId).@"enum".fields) |field| {
                        if (font.getName(@enumFromInt(field.value)) != null)
                            maxLen = @max(maxLen, field.name.len);
                    }
                    inline for (@typeInfo(NameId).@"enum".fields) |field| {
                        if (font.getName(@enumFromInt(field.value))) |s| {
                            try writer.print("  {s}:", .{field.name});
                            try writer.writeByteNTimes(' ', maxLen - field.name.len + 1);
                            try writer.print("{s}\n", .{s});
                        }
                    }
                }
                try font.dumpTable(writer, .head);
                {
                    try writer.print("cmap\n", .{});
                    const h = font.getTypedTable(.cmap).?;
                    const fields = @typeInfo(CmapHeader).@"struct".fields;
                    const maxLen = maxNameLen(fields);
                    inline for (fields) |field| {
                        try writer.print("  {s}:", .{field.name});
                        try writer.writeByteNTimes(' ', maxLen - field.name.len + 1);
                        try writer.print("{}\n", .{@field(h, field.name)});
                    }
                }

                const formati = font.readInt(u16, font.indexMap);
                switch (formati) {
                    4 => {
                        const tblp = font.getPtrAt(font.indexMap, *const SegmentToDelta);
                        var tbl = tblp.*;
                        byteSwapAll(SegmentToDelta, &tbl);
                        try dumpStruct(writer, tbl);
                    },
                    12, 13 => {
                        const tblp = font.getPtrAt(font.indexMap, *align(1) const FmtSegmentedTable);
                        var tbl = tblp.*;
                        byteSwapAll(FmtSegmentedTable, &tbl);
                        try dumpStruct(writer, tbl);
                    },
                    else => {},
                }

                try font.dumpTable(writer, .hhea);

                if (font.getTypedTable(.maxp)) |maxp| {
                    try writer.print("maxp\n", .{});
                    switch (maxp.version) {
                        0x00005000 => {
                            try font.dumpTable(writer, .hhea);
                        },
                        0x00010000 => {
                            const t = font.findTable(.maxp).?;
                            const tblp = font.getPtrAt(t.offset, *align(1) const MaxP_V10);
                            var tbl = tblp.*;
                            byteSwapAll(MaxP_V10, &tbl);
                            try dumpStruct(writer, tbl);
                        },
                        else => {},
                    }
                }
            }
        }
    };
    pub fn dumpFmt(font: Font, codepoint: ?u21, alloc: mem.Allocator) DumpFmt {
        return .{ .font = font, .codepoint = codepoint, .alloc = alloc };
    }
};

pub fn debug(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
}

comptime {
    // check that struct bitsizes match their sizes
    for (.{
        TableDirectory,
        Table,
        GDEF,
        GDEF2,
        GDEF3,
        GlyphHeader,
        CmapHeader,
        Encoding,
        EncodingTable,
        SegmentToDelta,
        MaxP_V05,
        MaxP_V10,
        FmtSegmentedTable,
        SequentialMapGroup,
    }) |T| {
        const size = @sizeOf(T);
        const bitsize = @bitSizeOf(T);
        if (bitsize / 8 != size) @compileError(std.fmt.comptimePrint(
            "bitsize/size mismatch {}/{} for {s}",
            .{ bitsize, size, @typeName(T) },
        ));
    }
}

const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const builtin = @import("builtin");
const Vector2 = @import("vec.zig").Vector2;
const t2 = @import("t2.zig");
const CffData = t2.CffData;
const Buf = t2.Buf;
