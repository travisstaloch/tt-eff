//! adapted from https://github.com/SebLague/Text-Rendering/blob/main/Assets/Scripts/SebText/Renderer/TextRenderer.cs

const ttf = @import("tt-eff");
const f32x2 = ttf.f32x2;

pub const LayoutSettings = struct {
    fontSizePx: f32,
    lineSpacing: f32,
    letterSpacing: f32,
    wordSpacing: f32,
    wh: f32x2,

    pub fn init(
        fontSizePx: f32,
        lineSpacing: f32,
        letterSpacing: f32,
        wordSpacing: f32,
        /// width and height
        wh: f32x2,
    ) LayoutSettings {
        return .{
            .fontSizePx = fontSizePx,
            .lineSpacing = lineSpacing,
            .letterSpacing = letterSpacing,
            .wordSpacing = wordSpacing,
            .wh = wh,
        };
    }

    pub fn equals(self: LayoutSettings, other: LayoutSettings) bool {
        return self.fontSizePx == other.fontSizePx and
            self.lineSpacing == other.LineSpacing and
            self.letterSpacing == other.letterSpacing and
            self.wordSpacing == other.wordSpacing;
    }

    /// given 'normalizedMetric' return pixel size.  result is scaled by
    /// 'wh.x'.  'normalizedMetric' is usually in range (0, 1).
    pub fn scaleNormalized(self: LayoutSettings, normalizedMetric: f32x2) f32x2 {
        return self.wh.mul(normalizedMetric).mulS(self.fontSizePx);
    }
};
