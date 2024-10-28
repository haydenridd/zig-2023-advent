const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_options = b.addOptions();
    exe_options.addOption(bool, "perf_compare", b.option(bool, "perf-compare", "Switch to compare different methods for performance improvements") orelse false);
    const helpers_mod = b.addModule("helpers", .{ .root_source_file = b.path("helpers/helpers.zig") });

    const helpers_test = b.addTest(.{
        .root_source_file = b.path("helpers/helpers.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_helpers_test = b.addRunArtifact(helpers_test);
    const overall_test_step = b.step("test", "Run unit tests");
    overall_test_step.dependOn(&run_helpers_test.step);

    const overall_run_step = b.step("run", "Run all days!");

    const max_day = 12;
    inline for (1..max_day + 1) |day| {
        const day_name = std.fmt.comptimePrint("day{}", .{day});
        const day_path = b.path("src/" ++ day_name ++ ".zig");
        const exe = b.addExecutable(.{
            .name = day_name,
            .root_source_file = day_path,
            .target = target,
            .optimize = optimize,
        });
        exe.root_module.addImport("helpers", helpers_mod);

        // This declares intent for the executable to be installed into the
        // standard location when the user invokes the "install" step (the default
        // step when running `zig build`).
        b.installArtifact(exe);

        // This *creates* a Run step in the build graph, to be executed when another
        // step is evaluated that depends on it. The next line below will establish
        // such a dependency.
        const run_cmd = b.addRunArtifact(exe);

        // By making the run step depend on the install step, it will be run from the
        // installation directory rather than directly from within the cache directory.
        // This is not necessary, however, if the application depends on other installed
        // files, this ensures they will be present and in the expected location.
        run_cmd.step.dependOn(b.getInstallStep());

        // This allows the user to pass arguments to the application in the build
        // command itself, like this: `zig build run -- arg1 arg2 etc`
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        // This creates a build step. It will be visible in the `zig build --help` menu,
        // and can be selected like this: `zig build run`
        // This will evaluate the `run` step rather than the default, which is "install".
        const run_step = b.step("run_" ++ day_name, "Run " ++ day_name);
        run_step.dependOn(&run_cmd.step);
        overall_run_step.dependOn(run_step);
        const exe_unit_tests = b.addTest(.{
            .root_source_file = day_path,
            .target = target,
            .optimize = optimize,
        });
        exe_unit_tests.root_module.addImport("helpers", helpers_mod);
        exe_unit_tests.root_module.addOptions("build_options", exe_options);
        const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

        // Similar to creating the run step earlier, this exposes a `test` step to
        // the `zig build --help` menu, providing a way for the user to request
        // running the unit tests.
        const test_step = b.step("test_" ++ day_name, "Run unit tests for - " ++ day_name);
        test_step.dependOn(&run_exe_unit_tests.step);
        overall_test_step.dependOn(test_step);
    }
}
