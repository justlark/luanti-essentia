local impl = dofile(core.get_modpath("overstock") .. "/impl.lua")

local DOUBLE_CLICK_THRESHOLD_US = 300000 -- 300ms

local function crate_sounds()
  if core.get_modpath("mcl_sounds") then
    return mcl_sounds.node_sound_wood_defaults()
  elseif core.get_modpath("default") then
    return default.node_sound_wood_defaults()
  else
    return nil
  end
end

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
  _mcl_hardness = 2.5,
  _mcl_blast_resistance = 2.5,
  _doc_items_longdesc = "Store large quantities of a single item.",
  _doc_items_usagehelp = "Right-click to add a stack. Double right-click to add all. Punch to take a stack. Sneak-punch to take a single item.",
  sounds = crate_sounds(),
  groups = {
    handy = 1,
    axey = 1,
    material_wood = 1,
    -- TODO: Add support for VoxeLibre hoppers by setting this to `group = 2`
    -- and implementing the `_mcl_hoppers_on_*` callbacks. We can't rely on
    -- hoppers' default behavior for nodes. For more info, find the comment
    -- explaining why we named the inventory list "crate" instead of "main".
    container = 1,
    deco_block = 1,

    -- For Minetest Game support.
    choppy = 1,
    oddly_breakable_by_hand = 1,
  },

  on_construct = function(pos)
    impl.initialize_inventory(pos)
  end,

  on_rightclick = function(pos, node, player, itemstack, _)
    local item_name = itemstack:get_name()
    local player_name = player:get_player_name()
    local now = core.get_us_time()
    local last = last_crate_rightclick[player_name] or {
      pos = nil,
      time = 0,
      item = "",
    }

    -- Treat a delay of < 300ms as a double right-click.
    if pos == last.pos and now - last.time < DOUBLE_CLICK_THRESHOLD_US then
      -- Double right click.
      if itemstack:get_name() == last.item then
        -- Typically, you would expect the player's hand to be empty at this
        -- point, since the first click would have already been captured by
        -- this handler. However, if they pick up a stack of the same item
        -- between the first and second clicks, we'll need to make sure we're
        -- putting that item into the crate as well.
        impl.put_all_items(pos, node, itemstack, last.item, player)
      else
        -- The player's hand is empty or contains a stack of a different item.
        -- You can't get the item name from an empty itemstack, so we also need
        -- to pass the item name.
        impl.put_all_items(pos, node, ItemStack(), last.item, player)
      end
    else
      -- Single right click.
      impl.put_item_stack(pos, node, itemstack)
    end

    last_crate_rightclick[player_name] = { time = now, item = item_name, pos = pos }

    player:get_inventory():set_stack("main", player:get_wield_index(), itemstack)
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

  allow_metadata_inventory_move = function(pos, _, _, _, _, count, player)
    return impl.protection_check_move(pos, count, player)
  end,

  allow_metadata_inventory_take = function(pos, _, _, stack, player)
    return impl.protection_check_put_take(pos, stack, player)
  end,

  allow_metadata_inventory_put = function(pos, _, _, stack, player)
    return impl.protection_check_put_take(pos, stack, player)
  end,
})

if core.get_modpath("mcl_core") and core.get_modpath("mcl_chests") then
  core.register_craft({
    type = "shaped",
    output = "overstock:crate 1",
    recipe = {
      { "group:tree", "group:wood_slab", "group:tree" },
      { "mcl_core:iron_ingot", "mcl_chests:chest", "mcl_core:iron_ingot" },
      { "group:tree", "group:tree", "group:tree" },
    },
  })
elseif core.get_modpath("default") then
  core.register_craft({
    type = "shaped",
    output = "overstock:crate 1",
    recipe = {
      { "group:tree", "group:wood", "group:tree" },
      { "default:steel_ingot", "default:chest", "default:steel_ingot" },
      { "group:tree", "group:tree", "group:tree" },
    },
  })
end

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

-- Prevent crates from being pushed by VoxeLibre pistons.
if core.get_modpath("mesecons_mvps") then
  mesecon.register_mvps_stopper("overstock:crate")
  mesecon.register_mvps_unmov("overstock:crate_count_label")
  mesecon.register_mvps_unmov("overstock:crate_item_label")
end
