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
```console
# search for .ttf and .otf files in /usr, and report on ok/fail/skip/total counts
python3 find-check.py
```

# Demo Renderer
```console
# run the raylib demo - works on linux
$ zig build demo -- /path/to/file.ttf
```


# Todo
  - [ ] investigate NoGlyph error output when running find-check.py - only from a few .ttf files
  - [ ] add tests of some canonical font files such as those in [IDEAS.md](IDEAS.md#font-testing)
  - [ ] readGlyph() is incomplete with respect to compound glyphs for hints, phantom points, point numbers etc.
  - Rendering
    - Demo
      - [ ] y direction should be up not down
      - [ ] glyphs should line up vertically
    - [ ] render to buffers like stb_truetype
    - [ ] rasterize like SebLague
      - [ ] implement the counting method from the end of the video
      - [ ] make test framework which can find evil artifacts
      - [ ] maybe use fixed point numbers to avoid floating point precision errors
  - [ ] make demo renderer with openGL
  - [ ] maybe convert to xml/json like python fonttools
  - [ ] export a c api and create a header file
  