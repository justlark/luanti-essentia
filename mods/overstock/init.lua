local impl = dofile(core.get_modpath("overstock") .. "/impl.lua")

core.register_node("overstock:crate", {
  description = "Storage Crate",
  tiles = {
    "overstock_crate_top.png",
    "overstock_crate_bottom.png",
    "overstock_crate_side.png",
    "overstock_crate_side.png",
    "overstock_crate_side.png",
    "overstock_crate_front.png",
  },
  paramtype2 = "4dir",
  _mcl_hardness = 2,
  groups = {
    handy = 1,
    axey = 1,
    material_wood = 1,
    container = 2,
  },
  on_construct = function(pos)
    local meta = core.get_meta(pos)
    local inventory = meta:get_inventory()
    inventory:set_size(impl.INVENTORY_LISTNAME, impl.CRATE_CAPACITY_STACKS)
  end,

  on_rightclick = function(pos, node, _, itemstack)
    impl.put_stack(pos, node, itemstack)
  end,

  on_punch = function(pos, node, puncher, _)
    impl.take_stack(pos, node, puncher)
  end,

  on_destruct = function(pos)
    impl.drop_inventory(pos)
  end,

  after_destruct = function(pos, node)
    impl.destroy_label(pos, node)
  end,
})

core.register_craft({
  type = "shaped",
  output = "overstock:crate 1",
  recipe = {
    { "group:tree",          "group:wood_slab",  "group:tree" },
    { "mcl_core:iron_ingot", "mcl_chests:chest", "mcl_core:iron_ingot" },
    { "group:tree",          "group:tree",       "group:tree" },
  },
})

core.register_entity("overstock:crate_item_label", {
  initial_properties = {
    pointable = false,
    visual = "wielditem",
    physical = false,
    collide_with_objects = false,
    -- We *could* save these entities with the world and just destroy them with
    -- the node, but if destroying the entity ever failed for any reason (a
    -- bug, etc.), then the player would be left with floating labels that are
    -- impossible to get rid of. Instead, we just regenerate the labels when
    -- the node load, using an LBM.
    static_save = false,
  },

  on_activate = function(self, static_data)
    if not static_data or static_data == "" then
      return
    end

    local item_name = static_data
    if item_name then
      local itemstack = ItemStack(item_name)
      local item_def = itemstack:get_definition()
      local wield_scale = item_def.wield_scale
      self.object:set_properties({
        wield_item = item_name,
        visual_size = {
          x = impl.BASE_LABEL_SIZE.x / wield_scale.x,
          y = impl.BASE_LABEL_SIZE.y / wield_scale.y,
        },
      })
    end
  end,
})

core.register_entity("overstock:crate_count_label", {
  initial_properties = {
    pointable = false,
    visual = "upright_sprite",
    physical = false,
    collide_with_objects = false,
    static_save = false,
  },

  on_activate = function(self, static_data)
    local texture = impl.generate_count_texture()

    self.object:set_properties({
      textures = { texture },
    })
  end,
})

-- Spawn the crate labels when the node loads, since they don't get
-- persistently saved with the world.
core.register_lbm({
  name = "overstock:respawn_crate_labels",
  nodenames = { "overstock:crate" },
  run_at_every_load = true,
  action = function(pos, node)
    local meta = core.get_meta(pos)
    local item_name = meta:get_string("overstock:item")
    if item_name and item_name ~= "" then
      if not impl.label_exists(pos, node) then
        impl.add_item_label_entity(pos, node, item_name)
        -- TODO: Implement
        impl.add_count_label_entity(pos, node, 0)
      end
    end
  end,
})
