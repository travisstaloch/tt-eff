const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const mod = b.addModule("tt-eff", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    try mod.import_table.putNoClobber(b.allocator, "tt-eff", mod);

    {
        const exe = b.addExecutable(.{
            .name = "tt-eff",
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });
        exe.root_module.addImport("tt-eff", mod);
        exe.root_module.addImport("clarp", b.dependency("clarp", .{}).module("clarp"));

        b.installArtifact(exe);
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }

    // TODO add tests
    // const tests = b.addTest(.{
    //     .root_source_file = b.path("src/root.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // const run_tests = b.addRunArtifact(tests);
    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_tests.step);

    // {
    //     const exe = b.addExecutable(.{
    //         .name = "stb-run",
    //         .root_source_file = b.path("deps/stb-run.zig"),
    //         .target = target,
    //         .optimize = optimize,
    //     });
    //     exe.addCSourceFile(.{ .file = b.path("deps/stb_truetype.c") });
    //     exe.addIncludePath(b.path("deps"));
    //     exe.linkLibC();
    //     b.installArtifact(exe);
    //     const run_cmd = b.addRunArtifact(exe);
    //     run_cmd.step.dependOn(b.getInstallStep());
    //     if (b.args) |args| {
    //         run_cmd.addArgs(args);
    //     }
    //     const run_step = b.step("stb", "Run the stb app");
    //     run_step.dependOn(&run_cmd.step);
    // }

    {
        // raylib demo
        const exe = b.addExecutable(.{
            .name = "demo",
            .root_source_file = b.path("src/demo.zig"),
            .target = target,
            .optimize = optimize,
        });
        exe.root_module.addImport("tt-eff", mod);
        exe.root_module.addImport("clarp", b.dependency("clarp", .{}).module("clarp"));
        const raylib_dep = b.dependency("raylib", .{});
        exe.addIncludePath(raylib_dep.path("include"));
        exe.addLibraryPath(raylib_dep.path("lib"));
        exe.linkSystemLibrary("raylib");
        exe.linkLibC();
        b.installArtifact(exe);
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| run_cmd.addArgs(args);
        const run_step = b.step("demo", "Run demo the app");
        run_step.dependOn(&run_cmd.step);
    }
}
