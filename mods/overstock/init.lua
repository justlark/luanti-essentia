local label_faces = {
  -- +Z
  [0] = { offset = vector.new(0, 0.0, -0.5), yaw = 0 },
  -- -X
  [1] = { offset = vector.new(-0.5, 0.0, 0), yaw = -math.pi / 2 },
  -- -Z
  [2] = { offset = vector.new(0, 0.0, 0.5), yaw = math.pi },
  -- +X
  [3] = { offset = vector.new(0.5, 0.0, 0), yaw = math.pi / 2 },
}

local barrel_capacity_stacks = 64

local function label_offset(node)
  local facedir = node.param2 % 4
  return label_faces[facedir].offset
end

local function label_yaw(node)
  local facedir = node.param2 % 4
  return label_faces[facedir].yaw
end

local function find_label_entity(pos, node, entity_name)
  local target = vector.add(pos, label_offset(node))
  for _, obj in pairs(core.get_objects_inside_radius(target, 0.1)) do
    local entity = obj:get_luaentity()
    if entity and entity.name == entity_name then
      return obj
    end
  end
end

local function remove_label_entity(pos, node, entity_name)
  local entity = find_label_entity(pos, node, entity_name)
  if entity then
    entity:remove()
  end
end

local function add_item_label_entity(pos, node, item_name)
  local offset = label_offset(node)
  local obj = core.add_entity(vector.add(pos, offset), "overstock:barrel_item_label", item_name)
  if obj then
    obj:set_yaw(label_yaw(node))
  end
end

local base_label_size = { x = 0.25, y = 0.25 }

local function take_stack(pos, node, puncher)
  local meta = core.get_meta(pos)
  local item_name = meta:get_string("overstock:item")

  if not item_name or item_name == "" then
    -- The barrel is empty.
    return
  end

  local barrel_inventory = core.get_inventory({ type = "node", pos = pos })
  local barrel_itemstack = ItemStack(item_name)

  if not barrel_inventory:contains_item("main", barrel_itemstack) then
    -- The barrel is empty.
    return
  end

  -- Get a full stack, or as much as it contains.
  barrel_itemstack:set_count(barrel_itemstack:get_stack_max() or 1)

  local player_inventory = puncher:get_inventory()
  local wielded_itemstack = player_inventory:get_stack("main", puncher:get_wield_index())
  local taken_itemstack = barrel_inventory:remove_item("main", barrel_itemstack)

  -- If the player is wielding a stack of the type in the barrel, add the taken
  -- items to that stack. Otherwise, add the taken items to the player's
  -- inventory.
  if wielded_itemstack:is_empty() then
    player_inventory:set_stack("main", puncher:get_wield_index(), taken_itemstack)
  else
    player_inventory:add_item("main", taken_itemstack)
  end

  if not barrel_inventory:contains_item("main", ItemStack(item_name)) then
    -- We've taken the last item from the barrel, so remove the label.
    meta:set_string("overstock:item", "")
    remove_label_entity(pos, node, "overstock:barrel_item_label")
  end
end

local function put_stack(pos, node, itemstack)
  local item_name = itemstack:get_name()
  if item_name == "" then
    return itemstack
  end

  local meta = core.get_meta(pos)
  local existing_item_name = meta:get_string("overstock:item")

  if existing_item_name ~= "" and existing_item_name ~= item_name then
    -- There is already an item of a different type in the barrel.
    return itemstack
  end

  meta:set_string("overstock:item", item_name)

  remove_label_entity(pos, node, "overstock:barrel_item_label")
  add_item_label_entity(pos, node, item_name)

  local barrel_inventory = core.get_inventory({ type = "node", pos = pos })
  barrel_inventory:add_item("main", itemstack)
  itemstack:clear()

  return itemstack
end

core.register_node("overstock:barrel", {
  description = "Barrel",
  tiles = {
    "overstock_barrel_top.png",
    "overstock_barrel_bottom.png",
    "overstock_barrel_side.png",
    "overstock_barrel_side.png",
    "overstock_barrel_side.png",
    "overstock_barrel_front.png",
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
    inventory:set_size("main", barrel_capacity_stacks)
  end,

  on_rightclick = function(pos, node, _, itemstack)
    put_stack(pos, node, itemstack)
  end,

  on_punch = function(pos, node, puncher, _)
    take_stack(pos, node, puncher)
  end,

  after_destruct = function(pos, node)
    remove_label_entity(pos, node, "overstock:barrel_item_label")
  end,
})

core.register_craft({
  type = "shaped",
  output = "overstock:barrel 1",
  recipe = {
    { "group:tree", "group:wood_slab", "group:tree" },
    { "group:tree", "mcl_chests:chest", "group:tree" },
    { "group:tree", "group:tree", "group:tree" },
  },
})

core.register_entity("overstock:barrel_item_label", {
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
          x = base_label_size.x / wield_scale.x,
          y = base_label_size.y / wield_scale.y,
        },
      })
    end
  end,
})

core.register_entity("overstock:barrel_count_label", {
  initial_properties = {
    pointable = false,
    visual = "upright_sprite",
    physical = false,
    collide_with_objects = false,
  },
})

-- Spawn the barrel labels when the node loads, since they don't get
-- persistently saved with the world.
core.register_lbm({
  name = "overstock:respawn_barrel_labels",
  nodenames = { "overstock:barrel" },
  run_at_every_load = true,
  action = function(pos, node)
    local meta = core.get_meta(pos)
    local item_name = meta:get_string("overstock:item")
    if item_name and item_name ~= "" then
      local existing = find_label_entity(pos, node, "overstock:barrel_item_label")
      if not existing then
        add_item_label_entity(pos, node, item_name)
      end
    end
  end,
})
