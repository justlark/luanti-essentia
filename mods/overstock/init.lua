local label_faces = {
  -- +Z
  [0] = { offset = vector.new(0, 0.0, -0.501), yaw = 0 },
  -- -X
  [1] = { offset = vector.new(-0.501, 0.0, 0), yaw = -math.pi / 2 },
  -- -Z
  [2] = { offset = vector.new(0, 0.0, 0.501), yaw = math.pi },
  -- +X
  [3] = { offset = vector.new(0.501, 0.0, 0), yaw = math.pi / 2 },
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
  groups = {
    axey = 1,
    material_wood = 1,
  },
  on_rightclick = function(pos, node, _, itemstack)
    local item_name = itemstack:get_name()
    if item_name == "" then
      return itemstack
    end

    local meta = core.get_meta(pos)
    meta:set_string("display_item", item_name)

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
    visual = "upright_sprite",
    physical = false,
    collide_with_objects = false,
    visual_size = { x = 0.45, y = 0.45 },
  },

  on_activate = function(self, staticdata)
    if not staticdata or staticdata == "" then
      return
    end

    local item_name = staticdata
    local item_def = core.registered_items[item_name]
    local node_def = core.registered_nodes[item_name]
    local texture = (item_def and item_def.inventory_image)
      or (node_def and (node_def.inventory_image or (node_def.tiles and node_def.tiles[6])))
      or nil

    if texture then
      self.object:set_properties({ textures = { texture } })
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
