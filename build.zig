const std = @import("std");

pub fn build(b: *std.Build) void {
    // options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // tdms module
    const tdms_module = b.addModule("tdms", .{
        .root_source_file = b.path("src/tdms.zig"),
        .target = target,
        .optimize = optimize,
    });

    // executable
    const exe = b.addExecutable(.{
        .name = "tdms-example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "tdms", .module = tdms_module },
            },
        }),
    });
    b.installArtifact(exe);

    // autodoc
    const autodoc_exe = b.addObject(.{
        .name = "tdms",
        .root_module = tdms_module,
    });

    const install_docs = b.addInstallDirectory(.{
        .source_dir = autodoc_exe.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs/tdms",
    });

    const docs_step = b.step("docs", "Generate and install documentation");
    docs_step.dependOn(&install_docs.step);

    // run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // tests
    const tdms_tests = b.addTest(.{
        .root_module = tdms_module,
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&tdms_tests.step);
}
