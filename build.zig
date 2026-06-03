const std = @import("std");

pub fn build(b: *std.Build) !void {
    var arena = std.heap.ArenaAllocator.init(b.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // SDK path: UFBT_HOME if set, otherwise ~/.ufbt (see flipperzero-ufbt README)
    const home = std.posix.getenv("HOME") orelse ".";
    const ufbt_home = std.posix.getenv("UFBT_HOME") orelse b.fmt("{s}/.ufbt", .{home});
    const sdk_base = b.fmt("{s}/current/sdk_headers/f7_sdk", .{ufbt_home});

    // UFBT and shell commands
    const ufbt_cmd = [_][]const u8{ "python3", "-m", "ufbt" };
    const shell_cmd = [_][]const u8{"bash"};

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m4 },
        .os_tag = .freestanding,
        .abi = .eabihf,
    });

    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSmall,
    });

    const obj = b.addObject(.{
        .name = "app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    obj.root_module.unwind_tables = .none;


    // Add ARM toolchain libc headers for @cImport (path matches uFBT host toolchain)
    const toolchain_triple = ufbtToolchainTriple(b);
    const arm_libc_include = b.fmt("{s}/toolchain/{s}/arm-none-eabi/include", .{ ufbt_home, toolchain_triple });
    obj.addSystemIncludePath(.{ .cwd_relative = arm_libc_include });

    // Add Flipper SDK includes and defines
    addFlipperIncludes(obj, sdk_base);
    addFlipperDefines(obj);

    // Install the .o file
    const obj_install = b.addInstallBinFile(obj.getEmittedBin(), b.fmt("{s}.o", .{obj.name}));
    b.getInstallStep().dependOn(&obj_install.step);

    const fap_step = b.step("fap", "Package the app into a .fap file");

    const run_ufbt = b.addSystemCommand(try cmdBuilder(allocator, &ufbt_cmd, &[_][]const u8{}));
    run_ufbt.step.dependOn(&obj_install.step);
    fap_step.dependOn(&run_ufbt.step);

    // Create an "init" step that runs the setup script
    const init_step = b.step("init", "Initialize project with custom settings");
    const run_setup = b.addSystemCommand(try cmdBuilder(allocator, &shell_cmd, &[_][]const u8{"setup.sh"}));
    init_step.dependOn(&run_setup.step);

    const launch_step = b.step("launch", "Launch the app on Flipper via UFBT");
    const run_launch = b.addSystemCommand(try cmdBuilder(allocator, &shell_cmd, &[_][]const u8{"launch"}));
    run_launch.step.dependOn(&obj_install.step);
    launch_step.dependOn(&run_launch.step);
}

fn ufbtToolchainTriple(b: *std.Build) []const u8 {
    _ = b;
    const builtin = @import("builtin");
    if (std.posix.getenv("UFBT_TOOLCHAIN_TRIPLE")) |triple| return triple;
    return switch (builtin.os.tag) {
        .linux => switch (builtin.cpu.arch) {
            .x86_64 => "x86_64-linux",
            .aarch64 => "aarch64-linux",
            else => @compileError("unsupported Linux CPU for uFBT toolchain"),
        },
        .macos => switch (builtin.cpu.arch) {
            .aarch64 => "arm64-darwin",
            .x86_64 => "x86_64-darwin",
            else => @compileError("unsupported macOS CPU for uFBT toolchain"),
        },
        .windows => switch (builtin.cpu.arch) {
            .x86_64 => "x86_64-windows",
            else => @compileError("unsupported Windows CPU for uFBT toolchain"),
        },
        else => @compileError("unsupported host OS for uFBT toolchain"),
    };
}

fn cmdBuilder(alloc: std.mem.Allocator, cmd: []const []const u8, parts: []const []const u8) ![]const []const u8 {
    var result = std.ArrayList([]const u8){};

    for (cmd) |part| {
        try result.append(alloc, part);
    }
    for (parts) |part| {
        try result.append(alloc, part);
    }

    return result.toOwnedSlice(alloc);
}

fn addFlipperIncludes(obj: *std.Build.Step.Compile, sdk_base: []const u8) void {
    const b = obj.step.owner;

    // Core SDK paths
    obj.addIncludePath(.{ .cwd_relative = sdk_base });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/furi", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/applications/services", .{sdk_base}) });

    // HAL paths
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/targets/furi_hal_include", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/targets/f7/ble_glue", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/targets/f7/furi_hal", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/targets/f7/inc", .{sdk_base}) });

    // Core library paths
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/mlib", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/cmsis_core", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/stm32wb_cmsis/Include", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/stm32wb_hal/Inc", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/stm32wb_copro/wpan", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/drivers", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/mbedtls/include", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/toolbox", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/libusb_stm32/inc", .{sdk_base}) });

    // Flipper-specific libraries
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/flipper_format", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/one_wire", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/ibutton", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/infrared/encoder_decoder", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/infrared/worker", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/subghz", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/nfc", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/digital_signal", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/pulse_reader", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/signal_reader", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/lfrfid", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/flipper_application", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/music_worker", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/mjs", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/nanopb", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/ble_profile", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/bit_lib", .{sdk_base}) });
    obj.addIncludePath(.{ .cwd_relative = b.fmt("{s}/lib/datetime", .{sdk_base}) });
}

fn addFlipperDefines(obj: *std.Build.Step.Compile) void {
    obj.root_module.addCMacro("_GNU_SOURCE", "");
    obj.root_module.addCMacro("FW_CFG_default", "");
    obj.root_module.addCMacro("M_MEMORY_FULL(x)", "abort()");
    obj.root_module.addCMacro("STM32WB", "");
    obj.root_module.addCMacro("STM32WB55xx", "");
    obj.root_module.addCMacro("USE_FULL_ASSERT", "");
    obj.root_module.addCMacro("USE_FULL_LL_DRIVER", "");
    obj.root_module.addCMacro("MBEDTLS_CONFIG_FILE", "\\\"mbedtls_cfg.h\\\"");
    obj.root_module.addCMacro("PB_ENABLE_MALLOC", "");
    obj.root_module.addCMacro("FW_ORIGIN_Official", "");
    obj.root_module.addCMacro("FURI_NDEBUG", "");
    obj.root_module.addCMacro("NDEBUG", "");
    obj.root_module.addCMacro("FAP_VERSION", "\\\"1.0\\\"");
}
