const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const lib = b.addSharedLibrary("nes", "src/main.zig", b.version(0, 0, 1));
    lib.setBuildMode(mode);
    lib.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    lib.setOutputDir("../web/static");

    lib.import_memory = true;
    lib.initial_memory = 131072;
    lib.max_memory = 131072;
    lib.global_base = 6560;
    lib.strip = true;
    lib.single_threaded = true;

    lib.install();

    const main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);
    main_tests.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .wasi });

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
