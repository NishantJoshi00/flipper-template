# Flipper Zero Zig Template

A modern, production-ready template for developing [Flipper Zero](https://flipper.net/) applications using the Zig programming language. This project provides a streamlined build system that integrates Zig with the Flipper Zero SDK, enabling developers to write type-safe, memory-safe applications for the Flipper Zero platform.

## Overview

This template bridges Zig's powerful build system and language features with the Flipper Zero firmware development kit. It handles the complex integration between Zig's ARM Cortex-M4 cross-compilation and the Flipper SDK, providing a clean starting point for custom applications.

### Key Features

- **Native Zig Support**: Write Flipper applications entirely in Zig, leveraging its compile-time safety guarantees and C interoperability
- **Automated Build Pipeline**: Seamless integration with `ufbt` (unofficial build tool) for packaging FAP files
- **Cross-Platform Development**: Works on macOS, Linux, and other platforms supported by Zig
- **SDK Integration**: Pre-configured include paths and compiler flags for the complete Flipper SDK (F7 target)
- **Interactive Setup**: Guided initialization script to customize app metadata
- **Quick Launch**: Built-in commands to build, package, and deploy to Flipper devices

## Architecture

The template uses a two-stage build process:

1. **Zig Build Stage**: Compiles Zig source to ARM Cortex-M4 object files (`app.o`)
   - Target: `thumb` architecture with `cortex-m4` CPU model
   - ABI: `eabihf` (Embedded Application Binary Interface, Hard Float)
   - Optimization: `ReleaseSmall` for minimal binary size

2. **UFBT Package Stage**: Links object files with SDK and packages into `.fap` format
   - Handled by the official Flipper build toolchain
   - Produces deployable application packages

## Prerequisites

### Required Tools

- **Zig**: Version 0.15.1 or later ([download](https://ziglang.org/download/))
- **UFBT**: Unofficial Flipper Build Tool ([installation guide](https://github.com/flipperdevices/flipperzero-ufbt#installation))
- **Python 3**: Required for running `ufbt` commands
- **Flipper Zero SDK**: Automatically managed by `ufbt` (installed to `~/.ufbt` or `UFBT_HOME`)

### Development Container

A [Development Container](https://containers.dev/) is provided under `.devcontainer/` with Zig 0.15.1 and the [uFBT](https://github.com/flipperdevices/flipperzero-ufbt) SDK preinstalled. Open the repo in VS Code or Cursor and choose **Reopen in Container**, or validate locally:

```bash
devcontainer build --workspace-folder .
devcontainer up --workspace-folder .
```

The SDK and ARM toolchain are stored in a Docker volume at `.ufbt/` inside the workspace (`UFBT_HOME`). The first container start downloads firmware SDK and toolchain artifacts (several hundred MB).

### Platform-Specific Setup

`build.zig` selects the uFBT toolchain directory from the host OS and CPU (`x86_64-linux`, `aarch64-linux`, `arm64-darwin`, etc.). Override with `UFBT_TOOLCHAIN_TRIPLE` if needed.

## Installation

1. **Install UFBT**:
   ```bash
   python3 -m pip install --upgrade ufbt
   ufbt update
   ```

2. **Clone or Download This Template**:
   ```bash
   git clone https://github.com/yourusername/flipper-template.git
   cd flipper-template
   ```

3. **Initialize Your Project**:
   ```bash
   zig build init
   ```

   This interactive script will prompt you for:
   - App ID (e.g., `my_custom_app`)
   - Display name (shown in Flipper menu)
   - Description
   - Author name
   - GitHub repository URL

## Usage

### Building the Application

Compile the Zig source to an object file:
```bash
zig build
```

This creates `zig-out/bin/app.o` with all the compiled application code.

### Creating a FAP Package

Build and package the complete application:
```bash
zig build fap
```

This runs the full pipeline:
1. Compiles Zig source to object file
2. Invokes `ufbt` to link with SDK
3. Generates `.fap` file in `dist/` directory

### Deploying to Flipper

Launch the application directly on a connected Flipper Zero:
```bash
zig build launch
```

This builds, packages, and transfers the app via USB, then starts it automatically.

## Project Structure

```
flipper-template/
├── application.fam       # Flipper app manifest (metadata, entry points)
├── build.zig            # Zig build system configuration
├── build.zig.zon        # Zig package manifest
├── icon.png             # App icon (10x10px recommended)
├── setup.sh             # Interactive project initialization script
├── src/
│   └── root.zig         # Main application source code
└── zig-out/             # Build artifacts (generated)
    └── bin/
        └── app.o        # Compiled object file
```

### Key Files

- **`src/root.zig`**: Entry point containing the `start()` function and application logic
- **`application.fam`**: Flipper-specific configuration (app ID, category, dependencies, stack size)
- **`build.zig`**: Defines compilation targets, SDK paths, and build commands

## Development Guide

### Minimal Application Structure

The template includes a "Hello World" example demonstrating core Flipper APIs:

```zig
// Import Flipper SDK functions
const flipper = @cImport({
    @cInclude("furi.h");
    @cInclude("gui/gui.h");
    @cInclude("gui/canvas.h");
    @cInclude("gui/view_port.h");
});

// Application entry point (must be named "start")
export fn start(_: ?*anyopaque) callconv(.{ .arm_aapcs = .{} }) i32 {
    // Initialize GUI viewport
    const gui = flipper.furi_record_open("gui");
    const view_port = flipper.view_port_alloc();

    // Set up callbacks and UI
    // ... (see src/root.zig for complete implementation)

    // Event loop
    _ = flipper.furi_thread_flags_wait(1, flipper.FuriFlagWaitAny, flipper.FuriWaitForever);

    return 0;
}
```

### SDK Integration

The build system automatically configures include paths for:

- **Core SDK**: FURI (Flipper Universal Runtime Interface)
- **HAL**: Hardware abstraction layer for STM32WB55
- **Standard Libraries**: mbedTLS, nanopb, mlib
- **Protocol Libraries**: Sub-GHz, NFC, RFID, Infrared
- **Peripheral APIs**: GPIO, SPI, I2C, UART

All headers are available via `@cImport()` in your Zig code.

### Calling Convention Notes

Flipper SDK uses ARM AAPCS calling conventions:
- **AAPCS**: Standard ARM procedure call (e.g., `start()` entry point)
- **AAPCS-VFP**: With floating-point/vector support (e.g., callbacks)

Ensure exported functions match the expected calling convention:
```zig
export fn start(_: ?*anyopaque) callconv(.{ .arm_aapcs = .{} }) i32
export fn draw_callback(canvas: ?*Canvas, ctx: ?*anyopaque) callconv(.{ .arm_aapcs_vfp = .{} }) void
```

### Handling SDK Imports

Some SDK headers contain constructs that Zig's C translator cannot process (e.g., unions with opaque types in `input/input.h`). For these cases, manually declare external functions:

```zig
extern fn view_port_input_callback_set(
    view_port: ?*flipper.ViewPort,
    callback: ?*const fn (?*anyopaque, ?*anyopaque) callconv(.{ .arm_aapcs_vfp = .{} }) void,
    context: ?*anyopaque
) callconv(.{ .arm_aapcs = .{} }) void;
```

## Troubleshooting

### Build Errors

**Issue**: `unable to find header 'furi.h'`
- **Cause**: UFBT SDK not installed or `~/.ufbt` path incorrect
- **Fix**: Run `ufbt update` to install SDK headers

**Issue**: `undefined reference to 'view_port_alloc'`
- **Cause**: Object file not properly linked with SDK
- **Fix**: Use `zig build fap` instead of `zig build` to complete linking

### Deployment Issues

**Issue**: `No Flipper device found`
- **Cause**: Device not connected or in DFU mode
- **Fix**: Connect via USB and ensure device is unlocked at main menu

**Issue**: App crashes on launch
- **Cause**: Stack overflow or incorrect calling convention
- **Fix**: Increase `stack_size` in `application.fam` or verify function signatures

## Advanced Configuration

### Compiler Flags

Modify `addFlipperDefines()` in `build.zig` to adjust preprocessor macros:
```zig
obj.root_module.addCMacro("FAP_VERSION", "\\\"1.0\\\"");
obj.root_module.addCMacro("CUSTOM_DEFINE", "value");
```

### Optimization Settings

Change optimization level in `build.zig:11`:
```zig
const optimize = b.standardOptimizeOption(.{
    .preferred_optimize_mode = .ReleaseFast,  // or .ReleaseSmall, .Debug
});
```

### Target Architecture

The template targets Flipper Zero's STM32WB55 (ARM Cortex-M4F). To port to other ARM devices, adjust `build.zig:4-9`:
```zig
const target = b.resolveTargetQuery(.{
    .cpu_arch = .thumb,
    .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m4 },
    .os_tag = .freestanding,
    .abi = .eabihf,
});
```

## Contributing

Contributions are welcome! This template aims to simplify Zig development for Flipper Zero. If you encounter SDK compatibility issues or have suggestions for improving the build process, please open an issue or pull request.

### Areas for Improvement

- Support for Windows toolchain paths
- Automated SDK version detection
- Integration with Flipper application catalog
- Additional SDK wrapper abstractions

## Resources

- [Flipper Zero Developer Documentation](https://developer.flipper.net/)
- [UFBT Repository](https://github.com/flipperdevices/flipperzero-ufbt)
- [Zig Language Reference](https://ziglang.org/documentation/master/)
- [Flipper SDK API Reference](https://github.com/flipperdevices/flipperzero-firmware/tree/dev/documentation)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Flipper Devices team for the UFBT toolchain
- Zig community for ARM cross-compilation support
- Contributors to the Flipper Zero SDK

---

**Note**: This is an unofficial template and is not affiliated with Flipper Devices Inc. Always test applications thoroughly before deploying to production devices.
