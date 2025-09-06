local impl = dofile(core.get_modpath("overstock") .. "/impl.lua")

local DOUBLE_CLICK_THRESHOLD_US = 300000 -- 300ms

-- The item name and click time indexed by player name.
local last_crate_rightclick = {}

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
  _doc_items_longdesc = "Store large quantities of a single item.",
  _doc_items_usagehelp = "Right-click to add a stack. Double right-click to add all. Punch to take a stack. Sneak-punch to take a single item.",
  sounds = mcl_sounds.node_sound_wood_defaults(),
  groups = {
    handy = 1,
    axey = 1,
    material_wood = 1,
    container = 2,
  },
  on_construct = function(pos)
    local meta = core.get_meta(pos)
    local inventory = meta:get_inventory()
    inventory:set_size(impl.CRATE_INVENTORY_LISTNAME, impl.CRATE_CAPACITY_STACKS)
  end,

  on_rightclick = function(pos, node, player, itemstack, _)
    local player_name = player:get_player_name()
    local now = core.get_us_time()
    local last = last_crate_rightclick[player_name] or {
      time = 0,
      item = "",
    }

    -- Treat a delay of < 300ms as a double right-click.
    if now - last.time < DOUBLE_CLICK_THRESHOLD_US then
      -- Double right click.
      local dummy_itemstack = ItemStack(last.item)
      impl.put_items(pos, node, dummy_itemstack, player, impl.PutQuantity.ALL)
      last_crate_rightclick[player_name] = { time = 0, item = "" }
    else
      -- Single right click.
      local item_name = itemstack:get_name()
      impl.put_items(pos, node, itemstack, player, impl.PutQuantity.STACK)
      last_crate_rightclick[player_name] = { time = now, item = item_name }
    end
  end,

  on_punch = function(pos, node, puncher, _)
    local controls = puncher:get_player_control()

    if controls.sneak then
      impl.take_items(pos, node, puncher, impl.TakeQuantity.ITEM)
    else
      impl.take_items(pos, node, puncher, impl.TakeQuantity.STACK)
    end
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
    { "group:tree", "group:wood_slab", "group:tree" },
    { "mcl_core:iron_ingot", "mcl_chests:chest", "mcl_core:iron_ingot" },
    { "group:tree", "group:tree", "group:tree" },
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
          x = impl.BASE_ITEM_LABEL_SIZE.x / wield_scale.x,
          y = impl.BASE_ITEM_LABEL_SIZE.y / wield_scale.y,
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
})

-- Spawn the crate labels when the node loads, since they don't get
-- persistently saved with the world.
core.register_lbm({
  name = "overstock:respawn_crate_labels",
  nodenames = { "overstock:crate" },
  run_at_every_load = true,
  action = function(pos, node)
    impl.spawn_label(pos, node)
  end,
})
