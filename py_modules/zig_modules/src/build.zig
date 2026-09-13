const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const modules = [_]struct {
        name: []const u8,
        source: []const u8,
    }{
        .{ .name = "x_mesh_zig", .source = "x_mesh.zig" },
        .{ .name = "x_rft_zig", .source = "x_rft.zig" },
        .{ .name = "x_rfi_zig", .source = "x_rfi.zig" },
    };
    for (modules) |module| {
        const lib = b.addLibrary(.{
            .name = module.name,
            .linkage = .dynamic,
            .root_module = b.createModule(.{
                .root_source_file = b.path(module.source),
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });

        lib.root_module.addLibraryPath(b.path("libs"));
        lib.root_module.linkSystemLibrary("python313", .{}); // Gotta link to this otherwise it complains about missing "__declspec(dllimport) PyModule_Create2"

        var pyconfig_exists = true; // check if pyconfig.h was already made from a previous build
        std.Io.Dir.cwd().access(b.graph.io, "cpython/pyconfig.h", .{}) catch |e| switch (e) {
            error.FileNotFound => pyconfig_exists = false,
            else => {},
        };
        if (!pyconfig_exists) {
            if (target.result.os.tag == .windows) {
                // cpython maintains a manual configuration of pyconfig.h for windows so we simply copy the file to let the linker find it
                const cwd = std.Io.Dir.cwd();
                cwd.copyFile("cpython/PC/pyconfig.h.in", cwd, "cpython/pyconfig.h", b.graph.io, .{}) catch |e| {
                    lib.step.dependOn(&b.addFail(@errorName(e)).step);
                };
            } else {
                // any other os will need to auto-generate the pyconfig.h file, so run cpython's configure script to create it
                const pyconfig = b.addSystemCommand(&.{
                    "./configure",
                    "--enable-optimizations",
                    "--without-ensurepip",
                });
                pyconfig.setCwd(b.path("cpython"));
                lib.step.dependOn(&pyconfig.step);
            }
        }
        
        const py_tc = b.addTranslateC(.{
            .root_source_file = b.addWriteFiles().add("py_tc.h",
                \\#define PY_SSIZE_T_CLEAN
                \\#include "Python.h"
                \\
            ),
            .target = target,
            .optimize = .ReleaseFast,
        });
        py_tc.addIncludePath(b.path("cpython")); // look for pyconfig.h in here
        py_tc.addIncludePath(b.path("cpython/include"));
        const py_mod = py_tc.createModule();
        
        lib.root_module.addImport("python", py_mod);
        
        const dest_sub_path = if (target.result.os.tag == .windows) b.fmt("{s}.pyd", .{module.name}) else b.fmt("{s}.so", .{module.name});

        const target_output = b.addInstallArtifact(lib, .{
            .dest_sub_path = dest_sub_path,
        });
        b.getInstallStep().dependOn(&target_output.step);
    }
}
