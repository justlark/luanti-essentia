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

local function add_item_label_entity(pos, node, item_name)
  local offset = label_offset(node)
  local obj = core.add_entity(vector.add(pos, offset), "overstock:barrel_item", item_name)
  if obj then
    obj:set_yaw(label_yaw(node))
  end
end

local base_label_size = { x = 0.25, y = 0.25 }

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
  on_rightclick = function(pos, node, _, itemstack)
    local item_name = itemstack:get_name()
    if item_name == "" then
      return itemstack
    end

    local meta = core.get_meta(pos)
    meta:set_string("overstock:item", item_name)

    local entity = find_label_entity(pos, node, "overstock:barrel_item")
    if entity then
      entity:remove()
    end

    add_item_label_entity(pos, node, item_name)

    return itemstack
  end,

  after_destruct = function(pos, node)
    local entity = find_label_entity(pos, node, "overstock:barrel_item")
    if entity then
      entity:remove()
    end
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

core.register_entity("overstock:barrel_item", {
  initial_properties = {
    pointable = false,
    visual = "wielditem",
    physical = false,
    collide_with_objects = false,
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

core.register_entity("overstock:barrel_label", {
  initial_properties = {
    pointable = false,
    visual = "upright_sprite",
    physical = false,
    collide_with_objects = false,
  },
})

core.register_lbm({
  name = "overstock:respawn_barrel_labels",
  nodenames = { "overstock:barrel" },
  run_at_every_load = true,
  action = function(pos, node)
    local meta = core.get_meta(pos)
    local item_name = meta:get_string("overstock:item")
    if item_name and item_name ~= "" then
      local existing = find_label_entity(pos, node, "overstock:barrel_item")
      if not existing then
        add_item_label_entity(pos, node, item_name)
      end
    end
  end,
})
