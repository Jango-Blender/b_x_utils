const py = @import("python");
const pyb = @import("py_bindings.zig");
const pyo = pyb.object_types;
const structs = @import("structs.zig");

pub fn vector3df_to_py(vector: structs.Vector3df) !pyo.TupleObject {
    const result: pyo.TupleObject = try .initPlaceholders(3);
    result.setUnchecked(0, try pyb.float(vector.x));
    result.setUnchecked(1, try pyb.float(vector.z));
    result.setUnchecked(2, try pyb.float(vector.y));
    return result;
}

pub fn vector3df_slice_to_python(vectors: []const structs.Vector3df) !pyo.ListObject {
    const result: pyo.ListObject = try .initPlaceholders(vectors.len);
    for (vectors, 0..) |vertex, i| {
        result.setUnchecked(i, try vector3df_to_py(vertex));
    }
    return result;
}

pub fn vector2df_to_py(vector: structs.Vector2df) !pyo.TupleObject {
    const result: pyo.TupleObject = try .initPlaceholders(2);
    result.setUnchecked(0, try pyb.float(vector.x));
    result.setUnchecked(1, try pyb.float(vector.y));
    return result;
}