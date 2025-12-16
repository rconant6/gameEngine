const std = @import("std");

// ComponentTypes = .{*ComponentStorage(Transform), *ComponentStorage(Velocity)}
pub fn Query(comptime ComponentTypes: type) type {
    return struct {
        const ComponentPointers = buildComponentPointers(ComponentTypes);

        pub const Entry = struct {
            entity: usize,
            components: ComponentPointers, // Tuple of component pointers

            pub fn get(
                self: Entry,
                comptime index: usize,
            ) std.meta.fields(ComponentPointers)[index].type {
                return @field(self.components, std.fmt.comptimePrint("{d}", .{index}));
            }
        };

        storages: ComponentTypes, // Tuple of storage pointers
        primary_index: usize, // Which storage to interate (smallest?)
        current_index: usize, // Current position in primary storage dense array

        pub fn init(storages: ComponentTypes) @This() {
            return .{
                .storages = storages,
                .primary_index = 0,
                .current_index = 0,
            };
        }

        pub fn next(self: *@This()) ?Entry {
            @setEvalBranchQuota(10000);
            // const num_storages = @typeInfo(ComponentTypes).@"struct".fields.len;
            const num_storages = std.meta.fields(ComponentTypes).len;

            inline for (0..num_storages) |i| {
                if (i == self.primary_index) {
                    const primary_storage = @field(self.storages, std.fmt.comptimePrint("{d}", .{i}));

                    // Keep looking for valid entities
                    while (self.current_index < primary_storage.dense.items.len) {
                        const entity_id = primary_storage.entities.items[self.current_index];
                        self.current_index += 1;

                        // Check if entity exists in ALL storages
                        var valid = true;
                        inline for (std.meta.fields(ComponentTypes), 0..) |field, j| {
                            if (j == i) continue; // Skip primary
                            const store = @field(self.storages, field.name);
                            if (!store.has(entity_id)) {
                                valid = false;
                                break;
                            }
                        }

                        if (!valid) continue;

                        // Build component pointers tuple
                        var component_ptrs: ComponentPointers = undefined;
                        inline for (std.meta.fields(ComponentTypes), 0..) |field, j| {
                            const store = @field(self.storages, field.name);
                            const ptr = store.get(entity_id).?;
                            @field(component_ptrs, std.fmt.comptimePrint("{d}", .{j})) = ptr;
                        }

                        return Entry{
                            .entity = entity_id,
                            .components = component_ptrs,
                        };
                    }
                }
            }

            return null;
        }

        fn findSmallestStorage(self: *const @This()) usize {
            var min: usize = std.math.maxInt(usize);
            var minIndex: usize = 0;

            inline for (std.meta.fields(ComponentTypes), 0..) |field, i| {
                const store = @field(self.storages, field.name);
                const len = store.dense.items.len;
                if (len < min) {
                    min = len;
                    minIndex = i;
                }
            }

            return minIndex;
        }

        fn buildComponentPointers(comptime StorageTypes: type) type {
            const storage_fields = std.meta.fields(StorageTypes);
            var result_fields: [storage_fields.len]std.builtin.Type.StructField = undefined;

            for (storage_fields, 0..) |field, i| {
                const StorageType = std.meta.Child(field.type);
                result_fields[i] = .{
                    .name = std.fmt.comptimePrint("{d}", .{i}),
                    .type = *const StorageType.ComponentType,
                    .default_value_ptr = null,
                    .is_comptime = false,
                    .alignment = @alignOf(*const StorageType.ComponentType),
                };
            }

            return @Type(.{ .@"struct" = .{
                .layout = .auto,
                .fields = &result_fields,
                .decls = &.{},
                .is_tuple = true,
            } });
        }
    };
}
