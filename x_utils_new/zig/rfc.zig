const std = @import("std");
const s = @import("structs.zig");

const xReader = @import("xReader.zig").xReader;
const Allocator = std.mem.Allocator;

const print = std.debug.print;

const RFCError = error{ UnknownRFCChunk, UnknownSubnodeChunk, UnkownPropChunk };

const SectorMap = struct {
    wallsets: []s.Name = &.{},
    floorsets: []s.Name = &.{},
    dim_x: u32 = 0,
    dim_y: u32 = 0,
    reserved: u32 = 0,
    scale: f32 = 20.0,
    comps: [][8]u8 = &.{},
    vars: [][8]u8 = &.{},
    sets: [][8]u8 = &.{},
    pub fn read(r: *xReader, allocator: Allocator) !SectorMap {
        const wallsets = try allocator.alloc(s.Name, try r.take(u32));
        try r.readSlice(s.Name, wallsets);
        const floorsets = try allocator.alloc(s.Name, try r.take(u32));
        try r.readSlice(s.Name, wallsets);
        const dim_x = try r.take(u32);
        const dim_y = try r.take(u32);
        const reserved = try r.take(u32);
        const scale = try r.take(f32);
        const sectors_n = dim_x * dim_y;
        const comps = try allocator.alloc([8]u8, sectors_n);
        try r.readSlice([8]u8, comps);
        const vars = try allocator.alloc([8]u8, sectors_n);
        try r.readSlice([8]u8, vars);
        const sets = try allocator.alloc([8]u8, sectors_n);
        return .{
            .wallsets = wallsets,
            .floorsets = floorsets,
            .dim_x = dim_x,
            .dim_y = dim_y,
            .reserved = reserved,
            .scale = scale,
            .comps = comps,
            .vars = vars,
            .sets = sets,
        };
    }
};

const Material = struct {
    data: []u8 = &.{}, //Populate this later.
    pub fn read(r: *xReader, allocator: Allocator) !Material {
        return .{ .data = try r.read_raw(allocator, try r.take(u32)) };
    }
};

fn read_materials(r: *xReader, allocator: Allocator) ![]Material {
    const mats = try allocator.alloc(Material, try r.take(u32));
    for (mats) |*mat| {
        mat.* = try Material.read(r, allocator);
    }
    return mats;
}

const Mesh = @import("mesh.zig").Mesh;

const LightType = enum {
    POINT,
    SPOT,
};

const Light = struct {
    light_type: LightType = .POINT,
    flag: u32 = 0,
    color: s.Vector3df = .{},
    ignored: u32 = 0,
    alpha: f32 = 1.0,
    brightness: f32 = 1.0,
    distance: f32 = 0.0,
    radius: f32 = 0.0,
    soften: f32 = 0.0,
    spotcot: f32 = 0.0,
    spotsoft: f32 = 0.0,
    unk: []u8 = &.{},
    pub fn read(r: *xReader, allocator: Allocator, objflag: u32, start: u32, length: u32) !Light {
        var l: Light = undefined;
        l.flag = try r.take(u32);
        l.color = try r.take(s.Vector3df);
        l.ignored = try r.take(u32);

        l.alpha = try r.take(f32);
        l.brightness = try r.take(f32);
        l.distance = try r.take(f32);
        l.radius = try r.take(f32);
        l.soften = try r.take(f32);

        l.light_type, l.spotcut, l.spotsoft = if (objflag == 0x140200) blk: {
            const light_type: LightType = .SPOT;
            const spotcut = try r.take(f32);
            const spotsoft = try r.take(f32);
            break :blk .{ light_type, spotcut, spotsoft };
        } else blk: {
            const light_type: LightType = .POINT;
            const spotcut = 0.0;
            const spotsoft = 0.0;
            break :blk .{ light_type, spotcut, spotsoft };
        };

        if (l.flag & 0x30000) l.unk = try r.read_raw(allocator, length - (start - r.tell()));

        return l;
    }
};

const VoxelLight = extern struct {
    unk1: u32 = 0,
    color: s.Vector3df = .{},
    unk2: u32 = 0,
    alpha: f32 = 1.0,
    distance: f32 = 1.0,
    unk3: u32 = 0,
};

const Effect = struct {
    effect_type: u32 = 0,
    intensity: f32 = 0.0,
    pub fn read(r: *xReader, flags: u32) !Effect {
        const effect_type, const type_length, const intensity = if (flags == 0x0 or flags == 0x10009) blk: {
            const effect_type = try r.take(u32);
            const type_length = try r.take(u32);
            const intensity = try r.take(f32);
            break :blk .{ effect_type, type_length, intensity };
        } else blk: {
            break :blk .{ 0, 0, 0 };
        };
        _ = type_length;
        return .{ .effect_type = effect_type, .intensity = intensity };
    }
};

const NodeData = union(enum) {
    mesh: Mesh,
    light: Light,
    voxellight: VoxelLight,
    effect: Effect,
};

pub const Node = struct {
    node_type: u32 = 0, //Convert this to an enum
    name: s.Name = .{},
    flags: u32 = 0,
    objflag: u32 = 0,
    suppress: u32 = 0,
    parent: u32 = 0,
    matrix: s.Matrix(4, 4) = .{},
    bbox_scale: s.Vector3df = .{},
    bbox_pos: s.Vector3df = .{},
    objint: u32 = 0,
    float_a: f32 = 0.0,
    data: ?NodeData = null,
    pub fn read(r: *xReader, allocator: Allocator, rfc_signature: u32, is_prop: bool) !Node {
        var n: Node = undefined;
        const start = r.tell();
        n.node_type = try r.take(u32);
        const node_length = try r.take(u32);
        n.name = try r.take(s.Name);
        n.flags = try r.take(u32);
        n.objflag = try r.take(u32);
        n.suppress = try r.take(u32);
        n.parent = try r.take(u32);
        n.matrix = (try r.take(s.xMatrix)).to_4x4();
        n.bbox_scale = try r.take(s.Vector3df);
        n.bbox_pos = try r.take(s.Vector3df);
        n.float_a, n.objint = if (rfc_signature == 0x3D23AFCF) blk: {
            const float_a = try r.take(f32);
            const objint = try r.take(u32);
            break :blk .{ float_a, objint };
        } else blk: {
            const objint = try r.take(u32);
            const float_a: f32 = 0.0;
            break :blk .{ float_a, objint };
        };
        if (n.suppress == 0) {
            n.data = if (n.suppress != 0) blk: {
                try r.seek_to(start + node_length + 4);
                break :blk null;
            } else blk: {
                switch (n.node_type) {
                    0x3D03 => break :blk .{ .mesh = Mesh.read(r, allocator, node_length, start, is_prop) },
                    0x3D06 => break :blk .{ .light = Light.read(r, allocator, n.objflag, start, node_length) },
                    0x3D01 => break :blk .{ .effect = Effect.read(r, n.flags) },
                    0x3D0C => break :blk .{ .voxellight = try r.take(VoxelLight) },
                    else => {
                        r.seek_to(start + node_length + 4); // +4: Compensate for the node type
                        break :blk null;
                    },
                }
            };
        } else {
            r.seek_to(start + node_length + 4); // +4: Compensate for the node type
            n.data = null;
        }
        return n;
    }
};

fn read_nodes(r: *xReader, allocator: Allocator, rfc_sig: u32, is_prop: bool) ![]Node {
    const nodes = try allocator.alloc(Node, try r.take(u32));
    for (nodes) |*node| {
        node.* = try Node.read(r, allocator, rfc_sig, is_prop);
    }
    return nodes;
}

const SubNodeV1 = struct {
    index: u32 = 0,
    name: s.Name = .{},
    reserved: u32 = 0,
    matrix: s.Matrix(4, 4) = .{},
    children: []SubNodeV1 = &.{},
    pub fn read(r: *xReader, allocator: Allocator) !SubNodeV1 {
        var sn: SubNodeV1 = undefined;
        sn.index = try r.take(u32);
        sn.name = try r.take(s.Name);
        sn.reserved = try r.take(u32);
        sn.matrix = (try r.take(s.xMatrix)).to_4x4();
        sn.children = allocator.alloc(SubNodeV1, try r.take(u32));
        for (sn.children) |child| {
            child.* = SubNodeV1.read(r, allocator);
        }
        return sn;
    }
};

const SubNodeV2 = struct {
    name: s.Name = .{},
    flag: u32 = 0,
    matrix: s.Matrix(4, 4) = .{},
    children: []SubNodeV2 = &.{},
    pub fn read(r: *xReader, allocator: Allocator, length: u32) !SubNodeV2 {
        var sn: SubNodeV2 = undefined;
        const start = r.tell();
        sn.name = try r.take(s.Name);
        sn.flag = try r.take(u32);
        sn.matrix = (try r.take(s.xMatrix)).to_4x4();
        var children = std.ArrayList(SubNodeV2).init(allocator);
        while (r.tell() - start < length) {
            const signature = try r.take(u32);
            if (signature != 0x3DE0ECAC) {
                print("Found an unknown SubNodeV2 child signature: 0x{x}", .{signature});
                return RFCError.UnknownSubnodeChunk;
            }
            const c_length = try r.take(u32);
            children.append(SubNodeV2.read(r, allocator, c_length));
        }
        sn.children = children.toOwnedSlice();
        return sn;
    }
};

const SoftBodySubNode = struct {
    name: s.Name = .{},
    flag: u32 = 0,
    vert_coords: []s.Vector3df = &.{},
    pub fn read(r: *xReader, allocator: Allocator) !SoftBodySubNode {
        var sn: SoftBodySubNode = undefined;
        sn.name = try r.take(s.Name);
        sn.flag = try r.take(u32);
        sn.vert_coords = try allocator.alloc(s.Vector3df, try r.take(u32));
        r.readSlice(s.Vector3df, sn.vert_coords);
        return sn;
    }
};

const SubNode = union(enum) {
    subnodev1: SubNodeV1,
    subnodev2: SubNodeV2,
    softbody: SoftBodySubNode,
};

const Prop = struct {
    flag: u32 = 0,
    name: s.Name = .{},
    matrix: s.Matrix(4, 4) = .{},
    subnodes: []SubNode = &.{},
    pub fn read(r: *xReader, allocator: Allocator) !Prop {
        const signature = try r.take(u32);
        if (signature != 0x3DE10100) {
            print("Found an invalid prop signature: 0x{x}", .{signature});
            return RFCError.UnkownPropChunk;
        }
        const length = try r.take(u32);
        const start = r.tell();
        var p: Prop = undefined;
        p.flag = r.take(u32);
        p.name = r.take(s.Name);
        p.matrix = (try r.take(s.xMatrix)).to_4x4();
        var subnodes = std.ArrayList(SubNode).init(allocator);
        var prev_subnode_sig = 0;
        while (r.tell() - start < length) {
            const subnode_sig = try r.take(u32);
            const subnode_length = try r.take(u32);
            switch (subnode_sig) {
                0x3DE0EC00 => subnodes.append(.{ .subnodev1 = SubNodeV1.read(r, allocator) }),
                0x3DE0ECAC => subnodes.append(.{ .subnodev2 = SubNodeV2.read(r, allocator, subnode_length) }),
                0x3DE0ECDB => subnodes.append(.{ .softbody = SoftBodySubNode.read(r, allocator) }),
                else => {
                    print("Found an unknown signature 0x{}. Previous chunk was 0x{x}", .{ subnode_sig, prev_subnode_sig });
                    return RFCError.UnknownSubnodeChunk;
                },
            }
            prev_subnode_sig = subnode_sig;
        }
        return p;
    }
};

fn read_props(r: *xReader, allocator: Allocator) ![]Prop {
    const props = try allocator.alloc(Prop, try r.take(u32));
    for (props) |*prop| {
        prop.* = try Prop.read(r, allocator);
    }
    return props;
}

pub const RFC = struct {
    name: s.Name = .{},
    sectormap: ?SectorMap = null,
    materials: []Material = &.{},
    nodes: []Node = &.{},
    props: []Prop = &.{},
    // itemdb: ?ItemDB = null,
    // chardb: ?CharDB = null,
    // envmap: ?EnvMap = null,
    pub fn read(r: *xReader, allocator: Allocator, length: u32, start: u32, rfc_signature: u32, is_prop: bool) !RFC {
        var rfc: RFC = undefined;
        while (r.tell() - start < length) {
            const chunk_sig = try r.take(u32);
            const chunk_length = try r.take(u32);
            const chunk_start = r.tell();
            switch (chunk_sig) {
                0x00003DED => rfc.sectormap = try SectorMap.read(r, allocator),
                0x0000BA00 => rfc.materials = try read_materials(r, allocator),
                0x3D000000 => rfc.nodes = try read_nodes(r, allocator, rfc_signature, is_prop),
                0x3DE10000 => rfc.props = try read_props(r, allocator),
                else => {
                    print("Found an unknown RFC chunk: 0x{}", .{chunk_sig});
                    r.seek_to(chunk_start + chunk_length);
                },
            }
        }
        return rfc;
    }
};
