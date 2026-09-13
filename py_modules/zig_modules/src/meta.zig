const std = @import("std");

/// A wrapper around struct argument T that encourages only being able to set a field once via set(...) and only being able to obtain a field via get(...) if already set.
/// Useful when looping through chunks of unverified data where there may be missing expected chunks or too many of an expected chunk type.
pub fn OnceSetterSafeGetter(T: type) type {
    return struct {
        fields: T = undefined,
        field_states: std.StaticBitSet(@typeInfo(Field).@"enum".fields.len) = .empty,
        
        pub const empty: @This() = .{};
        pub const Field = std.meta.FieldEnum(T);
        pub const AlreadySetError = error {AlreadySet};
        pub const NotSetError     = error {NotSet};
        
        pub fn set(self: *@This(), comptime tag: Field, value: @FieldType(T, @tagName(tag))) AlreadySetError!void {
            if (self.field_states.isSet(@intFromEnum(tag))) return error.AlreadySet;
            @field(self.fields, @tagName(tag)) = value;
        }
        
        pub fn get(self: *const @This(), comptime tag: Field) NotSetError!@FieldType(T, @tagName(tag)) {
            if (!self.field_states.isSet(@intFromEnum(tag))) return error.NotSet;
            return @field(self.fields, @tagName(tag));
        }
    };
}