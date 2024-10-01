# tt-eff
A truetype font parsing and rendering library.

# Status
### :warning: Immature :warning:
* Parsing - common formats mostly work including opentype cff fonts with 'charstring' instructions.  
  * able to successfully parse around 86% of the .ttf and .otf files found in my /usr path.  currently failing to parse 80/587 files.
* Rendering - WIP
  - there is a [raylib demo app](src/demo.zig)

# Resources
* https://github.com/nothings/stb/blob/master/stb_truetype.h
* https://github.com/SebLague/Text-Rendering


# Test
```console
# print some info to the console
$ zig build run -- /path/to/file.ttf
```

# Demo Renderer
```console
# run the raylib demo - works on linux
$ zig build demo -- /path/to/file.ttf
```


# Todo
  - [ ] investigate NoGlyph error output when running find-check.py - only from a few .ttf files
  - [ ] add tests of some canonical font files such as those in [IDEAS.md](IDEAS.md#font-testing)
  - [ ] implement component glyphs as point numbers (when flags ARGS_ARE_XY_VALUES is not set)
  - Rendering
    - Demo
      - [ ] y direction should be up not down
      - [ ] glyphs should line up vertically
  - [ ] render to buffers like stb_truetype
    - [ ] rasterize like SebLague
      - [ ] implement the counting method from the end of the video
      - [ ] make test framework which can find evil artifacts
      - [ ] maybe use fixed point numbers to avoid floating point precision errors
  - [ ] make demo renderer to openGL
  - [ ] maybe convert to xml/json like python fonttools
  - [ ] export a c api and create a header file
  - [x] use u21 for codepoints instead of u32
  - [x] don't allocate in applyLayoutInfo(). instead create and getLayoutInfo(glyphIndex)