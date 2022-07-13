// This file is part of river, a dynamic tiling wayland compositor.
//
// Copyright 2020-2021 The River Developers
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

// This is an implementation of the  default "tiled" layout of dwm and the
// 3 other orientations thereof. This code is written for the main stack
// to the left and then the input/output values are adjusted to apply
// the necessary transformations to derive the other orientations.
//
// With 4 views and one main on the left, the layout looks something like this:
//
// +-----------------------+------------+
// |                       |            |
// |                       |            |
// |                       |            |
// |                       +------------+
// |                       |            |
// |                       |            |
// |                       |            |
// |                       +------------+
// |                       |            |
// |                       |            |
// |                       |            |
// +-----------------------+------------+

const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const math = std.math;
const os = std.os;
const assert = std.debug.assert;

const wayland = @import("wayland");
const wl = wayland.client.wl;
const river = wayland.client.river;

const flags = @import("flags");

const usage =
    \\usage: forestile [options]
    \\
    \\  -h              Print this help message and exit.
    \\  -version        Print the version number and exit.
    \\  -view-padding   Set the padding around views in pixels. (Default 6)
    \\  -outer-padding  Set the padding around the edge of the layout area in
    \\                  pixels. (Default 6)
    \\  -main-location  Set the initial location of the main area in the
    \\                  layout. (Default left)
    \\  -main-count     Set the initial number of views in the main area of the
    \\                  layout. (Default 1)
    \\  -main-ratio     Set the initial ratio of main area to total layout
    \\                  area. (Default: 0.6)
    \\
;

const Command = enum {
    @"main-location",
    @"main-count",
    @"main-ratio",
    @"padding",
};

const Location = enum {
    top,
    right,
    bottom,
    left,
};

const Toggle = enum {
    @"on",
    @"off",
    @"toggle",
};

// Configured through command line options
var view_padding: u31 = 4;
var outer_padding: u31 = 8;
var default_main_location: Location = .left;
var default_main_count: u31 = 1;
var default_main_ratio: f64 = 0.5;

/// We don't free resources on exit, only when output globals are removed.
const gpa = std.heap.c_allocator;

const Context = struct {
    initialized: bool = false,
    layout_manager: ?*river.LayoutManagerV3 = null,
    outputs: std.TailQueue(Output) = .{},

    fn addOutput(context: *Context, registry: *wl.Registry, name: u32) !void {
        const wl_output = try registry.bind(name, wl.Output, 3);
        errdefer wl_output.release();
        const node = try gpa.create(std.TailQueue(Output).Node);
        errdefer gpa.destroy(node);
        try node.data.init(context, wl_output, name);
        context.outputs.append(node);
    }
};

const Output = struct {
    wl_output: *wl.Output,
    name: u32,

    main_location: Location,
    main_count: u31,
    main_ratio: f64,

    padding: bool,

    layout: *river.LayoutV3 = undefined,

    fn init(output: *Output, context: *Context, wl_output: *wl.Output, name: u32) !void {
        output.* = .{
            .wl_output = wl_output,
            .name = name,
            .main_location = default_main_location,
            .main_count = default_main_count,
            .main_ratio = default_main_ratio,
            .padding = true,
        };
        if (context.initialized) try output.getLayout(context);
    }

    fn getLayout(output: *Output, context: *Context) !void {
        assert(context.initialized);
        output.layout = try context.layout_manager.?.getLayout(output.wl_output, "forestile");
        output.layout.setListener(*Output, layoutListener, output);
    }

    fn deinit(output: *Output) void {
        output.wl_output.release();
        output.layout.destroy();
    }

    fn layoutListener(layout: *river.LayoutV3, event: river.LayoutV3.Event, output: *Output) void {
        switch (event) {
            .namespace_in_use => fatal("namespace 'forestile' already in use.", .{}),

            .user_command => |ev| {
                var it = mem.tokenize(u8, mem.span(ev.command), " ");
                const raw_cmd = it.next() orelse {
                    std.log.err("not enough arguments", .{});
                    return;
                };
                const raw_arg = it.next() orelse {
                    std.log.err("not enough arguments", .{});
                    return;
                };
                if (it.next() != null) {
                    std.log.err("too many arguments", .{});
                    return;
                }
                const cmd = std.meta.stringToEnum(Command, raw_cmd) orelse {
                    std.log.err("unknown command: {s}", .{raw_cmd});
                    return;
                };
                switch (cmd) {
                    .@"main-location" => {
                        output.main_location = std.meta.stringToEnum(Location, raw_arg) orelse {
                            std.log.err("unknown location: {s}", .{raw_arg});
                            return;
                        };
                    },
                    .@"main-count" => {
                        const arg = fmt.parseInt(i32, raw_arg, 10) catch |err| {
                            std.log.err("failed to parse argument: {}", .{err});
                            return;
                        };
                        switch (raw_arg[0]) {
                            '+' => output.main_count +|= @intCast(u31, arg),
                            '-' => {
                                const result = output.main_count +| arg;
                                if (result >= 0) output.main_count = @intCast(u31, result);
                            },
                            else => output.main_count = @intCast(u31, arg),
                        }
                    },
                    .@"main-ratio" => {
                        const arg = fmt.parseFloat(f64, raw_arg) catch |err| {
                            std.log.err("failed to parse argument: {}", .{err});
                            return;
                        };
                        switch (raw_arg[0]) {
                            '+', '-' => {
                                output.main_ratio = math.clamp(output.main_ratio + arg, 0.1, 0.9);
                            },
                            else => output.main_ratio = math.clamp(arg, 0.1, 0.9),
                        }
                    },
                    .@"padding" => {
                        const toggle = std.meta.stringToEnum(Toggle, raw_arg) orelse {
                            std.log.err("unknown toggle: {s}", .{raw_arg});
                            return;
                        };
                        switch (toggle) {
                            .@"on" => {
                                output.padding = true;
                                view_padding = 4;
                                outer_padding = 8;
                            },
                            .@"off" => {
                                output.padding = false;
                                view_padding = 0;
                                outer_padding = 0;
                            },
                            .@"toggle" => {
                                if (output.padding) {
                                    output.padding = false;
                                    view_padding = 0;
                                    outer_padding = 0;
                                } else {
                                    output.padding = true;
                                    view_padding = 4;
                                    outer_padding = 8;
                                }
                            }
                        }
                    }
                }
            },

            .layout_demand => |ev| {
                const main_count = math.clamp(output.main_count, 1, @truncate(u31, ev.view_count));
                const secondary_count = @truncate(u31, ev.view_count) -| main_count;

                const usable_width = switch (output.main_location) {
                    .left, .right => @truncate(u31, ev.usable_width) -| (2 *| outer_padding),
                    .top, .bottom => @truncate(u31, ev.usable_height) -| (2 *| outer_padding),
                };
                const usable_height = switch (output.main_location) {
                    .left, .right => @truncate(u31, ev.usable_height) -| (2 *| outer_padding),
                    .top, .bottom => @truncate(u31, ev.usable_width) -| (2 *| outer_padding),
                };

                // to make things pixel-perfect, we make the first main and first secondary
                // view slightly larger if the height is not evenly divisible
                var main_width: u31 = undefined;
                var main_height: u31 = undefined;
                var main_height_rem: u31 = undefined;

                var secondary_width: u31 = undefined;
                var secondary_height: u31 = undefined;
                var secondary_height_rem: u31 = undefined;

                if (main_count > 0 and secondary_count > 0) {
                    main_width = @floatToInt(u31, output.main_ratio * @intToFloat(f64, usable_width));
                    main_height = usable_height / main_count;
                    main_height_rem = usable_height % main_count;

                    secondary_width = usable_width - main_width;
                    secondary_height = usable_height / secondary_count;
                    secondary_height_rem = usable_height % secondary_count;
                } else if (main_count > 0) {
                    main_width = usable_width;
                    main_height = usable_height / main_count;
                    main_height_rem = usable_height % main_count;
                } else if (secondary_width > 0) {
                    main_width = 0;
                    secondary_width = usable_width;
                    secondary_height = usable_height / secondary_count;
                    secondary_height_rem = usable_height % secondary_count;
                }

                var i: u31 = 0;
                while (i < ev.view_count) : (i += 1) {
                    var x: i32 = undefined;
                    var y: i32 = undefined;
                    var width: u31 = undefined;
                    var height: u31 = undefined;

                    if (i < main_count) {
                        x = 0;
                        y = (i * main_height) + if (i > 0) main_height_rem else 0;
                        width = main_width;
                        height = main_height + if (i == 0) main_height_rem else 0;
                    } else {
                        x = main_width;
                        y = (i - main_count) * secondary_height + if (i > main_count) secondary_height_rem else 0;
                        width = secondary_width;
                        height = secondary_height + if (i == main_count) secondary_height_rem else 0;
                    }

                    x +|= view_padding;
                    y +|= view_padding;
                    width -|= 2 *| view_padding;
                    height -|= 2 *| view_padding;

                    switch (output.main_location) {
                        .left => layout.pushViewDimensions(
                            x +| outer_padding,
                            y +| outer_padding,
                            width,
                            height,
                            ev.serial,
                        ),
                        .right => layout.pushViewDimensions(
                            usable_width - width - x +| outer_padding,
                            y +| outer_padding,
                            width,
                            height,
                            ev.serial,
                        ),
                        .top => layout.pushViewDimensions(
                            y +| outer_padding,
                            x +| outer_padding,
                            height,
                            width,
                            ev.serial,
                        ),
                        .bottom => layout.pushViewDimensions(
                            y +| outer_padding,
                            usable_width - width - x +| outer_padding,
                            height,
                            width,
                            ev.serial,
                        ),
                    }
                }

                switch (output.main_location) {
                    .left => layout.commit("forestile - left", ev.serial),
                    .right => layout.commit("forestile - right", ev.serial),
                    .top => layout.commit("forestile - top", ev.serial),
                    .bottom => layout.commit("forestile - bottom", ev.serial),
                }
            },
        }
    }
};

pub fn main() !void {
    // https://github.com/ziglang/zig/issues/7807
    const argv: [][*:0]const u8 = os.argv;
    const result = flags.parse(argv[1..], &[_]flags.Flag{
        .{ .name = "-h", .kind = .boolean },
        .{ .name = "-version", .kind = .boolean },
        .{ .name = "-view-padding", .kind = .arg },
        .{ .name = "-outer-padding", .kind = .arg },
        .{ .name = "-main-location", .kind = .arg },
        .{ .name = "-main-count", .kind = .arg },
        .{ .name = "-main-ratio", .kind = .arg },
    }) catch {
        try std.io.getStdErr().writeAll(usage);
        os.exit(1);
    };
    if (result.boolFlag("-h")) {
        try std.io.getStdOut().writeAll(usage);
        os.exit(0);
    }
    if (result.args.len != 0) fatalPrintUsage("unknown option '{s}'", .{result.args[0]});

    if (result.boolFlag("-version")) {
        try std.io.getStdOut().writeAll(@import("build_options").version ++ "\n");
        os.exit(0);
    }
    if (result.argFlag("-view-padding")) |raw| {
        view_padding = fmt.parseUnsigned(u31, raw, 10) catch
            fatalPrintUsage("invalid value '{s}' provided to -view-padding", .{raw});
    }
    if (result.argFlag("-outer-padding")) |raw| {
        outer_padding = fmt.parseUnsigned(u31, raw, 10) catch
            fatalPrintUsage("invalid value '{s}' provided to -outer-padding", .{raw});
    }
    if (result.argFlag("-main-location")) |raw| {
        default_main_location = std.meta.stringToEnum(Location, raw) orelse
            fatalPrintUsage("invalid value '{s}' provided to -main-location", .{raw});
    }
    if (result.argFlag("-main-count")) |raw| {
        default_main_count = fmt.parseUnsigned(u31, raw, 10) catch
            fatalPrintUsage("invalid value '{s}' provided to -main-count", .{raw});
    }
    if (result.argFlag("-main-ratio")) |raw| {
        default_main_ratio = fmt.parseFloat(f64, raw) catch {
            fatalPrintUsage("invalid value '{s}' provided to -main-ratio", .{raw});
        };
        if (default_main_ratio < 0.1 or default_main_ratio > 0.9) {
            fatalPrintUsage("invalid value '{s}' provided to -main-ratio", .{raw});
        }
    }

    const display = wl.Display.connect(null) catch {
        std.debug.print("Unable to connect to Wayland server.\n", .{});
        os.exit(1);
    };
    defer display.disconnect();

    var context: Context = .{};

    const registry = try display.getRegistry();
    registry.setListener(*Context, registryListener, &context);
    if (display.roundtrip() != .SUCCESS) fatal("initial roundtrip failed", .{});

    if (context.layout_manager == null) {
        fatal("wayland compositor does not support river-layout-v3.\n", .{});
    }

    context.initialized = true;

    var it = context.outputs.first;
    while (it) |node| : (it = node.next) {
        const output = &node.data;
        try output.getLayout(&context);
    }

    while (true) {
        if (display.dispatch() != .SUCCESS) fatal("failed to dispatch wayland events", .{});
    }
}

fn registryListener(registry: *wl.Registry, event: wl.Registry.Event, context: *Context) void {
    switch (event) {
        .global => |global| {
            if (std.cstr.cmp(global.interface, river.LayoutManagerV3.getInterface().name) == 0) {
                context.layout_manager = registry.bind(global.name, river.LayoutManagerV3, 1) catch return;
            } else if (std.cstr.cmp(global.interface, wl.Output.getInterface().name) == 0) {
                context.addOutput(registry, global.name) catch |err| fatal("failed to bind output: {}", .{err});
            }
        },
        .global_remove => |ev| {
            var it = context.outputs.first;
            while (it) |node| : (it = node.next) {
                const output = &node.data;
                if (output.name == ev.name) {
                    context.outputs.remove(node);
                    output.deinit();
                    gpa.destroy(node);
                    break;
                }
            }
        },
    }
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.log.err(format, args);
    os.exit(1);
}

fn fatalPrintUsage(comptime format: []const u8, args: anytype) noreturn {
    std.log.err(format, args);
    std.io.getStdErr().writeAll(usage) catch {};
    os.exit(1);
}
