const std = @import("std");
const TSNode = @import("tree-sitter").TSNode;
const Context = @import("Context.zig");
const utils = @import("utils.zig");
const enums = @import("enums.zig");

pub fn extends_statement(node: TSNode, writer: anytype, context: Context) anyerror!void {
    _ = context;

    try writer.print("{s}\n\n", .{node.text()});
}

pub fn variable_statement(node: TSNode, writer: anytype, context: Context) anyerror!void {
    _ = context;

    for (0..node.childCount()) |i| {
        const prev_child = if (i > 0) node.child(@intCast(i - 1)) else null;
        _ = prev_child;
        const child = node.child(@intCast(i));
        const next_child = node.child(@intCast(i + 1));

        if (child) |c| {
            const nt = (try c.getTypeAsEnum(enums.GdNodeType)).?;

            switch (nt) {
                .annotations => {
                    try writer.print("{s} ", .{c.text()});
                },
                .@"var" => {
                    try writer.print("{s} ", .{c.text()});
                },
                .identifier => {
                    try writer.print("{s} ", .{c.text()});
                },
                .name => {
                    const next_child_is_type = blk: {
                        if (next_child) |nc| {
                            const nc_type = (try nc.getTypeAsEnum(enums.GdNodeType)).?;

                            if (nc_type == .@":") {
                                break :blk true;
                            }
                        }

                        break :blk false;
                    };

                    if (next_child_is_type) {
                        try writer.writeAll(c.text());
                    } else {
                        try writer.print("{s} ", .{c.text()});
                    }
                },
                .type => {
                    try writer.print("{s} ", .{c.text()});
                },
                .@"=" => try writer.print("{s} ", .{c.text()}),
                .inferred_type => try writer.print("{s} ", .{c.text()}),
                .get_node => try writer.print("{s} ", .{c.text()}),
                .attribute => try writer.print("{s} ", .{c.text()}),
                else => try writer.print("{s} ", .{c.text()}),
            }
        }
    }

    _ = try writer.write("\n");
}
