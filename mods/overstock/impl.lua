local impl = {}

impl.inventory_listname = "main"
impl.barrel_capacity_stacks = 64

local function label_face(face)
  local faces = {
    -- +Z
    [0] = { offset = vector.new(0, 0.0, -0.5), yaw = 0 },
    -- -X
    [1] = { offset = vector.new(-0.5, 0.0, 0), yaw = -math.pi / 2 },
    -- -Z
    [2] = { offset = vector.new(0, 0.0, 0.5), yaw = math.pi },
    -- +X
    [3] = { offset = vector.new(0.5, 0.0, 0), yaw = math.pi / 2 },
  }

  return faces[face]
end

function impl.label_offset(node)
  local facedir = node.param2 % 4
  return label_face(facedir).offset
end

function impl.label_yaw(node)
  local facedir = node.param2 % 4
  return label_face(facedir).yaw
end

function impl.find_label_entity(pos, node, entity_name)
  local target = vector.add(pos, impl.label_offset(node))
  for _, obj in pairs(core.get_objects_inside_radius(target, 0.1)) do
    local entity = obj:get_luaentity()
    if entity and entity.name == entity_name then
      return obj
    end
  end
end

function impl.remove_label_entity(pos, node, entity_name)
  local entity = impl.find_label_entity(pos, node, entity_name)
  if entity then
    entity:remove()
  end
end

function impl.add_item_label_entity(pos, node, item_name)
  local offset = impl.label_offset(node)
  local obj = core.add_entity(vector.add(pos, offset), "overstock:barrel_item_label", item_name)
  if obj then
    obj:set_yaw(impl.label_yaw(node))
  end
end

impl.base_label_size = { x = 0.25, y = 0.25 }

function impl.take_stack(pos, node, puncher)
  local meta = core.get_meta(pos)
  local item_name = meta:get_string("overstock:item")

  if not item_name or item_name == "" then
    -- The barrel is empty.
    return
  end

  local barrel_inventory = core.get_inventory({ type = "node", pos = pos })
  local barrel_itemstack = ItemStack(item_name)

  if not barrel_inventory:contains_item(impl.inventory_listname, barrel_itemstack) then
    -- The barrel is empty.
    return
  end

  -- Get a full stack, or as much as it contains.
  barrel_itemstack:set_count(barrel_itemstack:get_stack_max() or 1)

  local player_inventory = puncher:get_inventory()
  local wielded_itemstack = player_inventory:get_stack(impl.inventory_listname, puncher:get_wield_index())
  local taken_itemstack = barrel_inventory:remove_item(impl.inventory_listname, barrel_itemstack)

  -- If the player is wielding a stack of the type in the barrel, add the taken
  -- items to that stack. Otherwise, add the taken items to the player's
  -- inventory.
  if wielded_itemstack:is_empty() then
    player_inventory:set_stack(impl.inventory_listname, puncher:get_wield_index(), taken_itemstack)
  else
    player_inventory:add_item(impl.inventory_listname, taken_itemstack)
  end

  if not barrel_inventory:contains_item(impl.inventory_listname, ItemStack(item_name)) then
    -- We've taken the last item from the barrel, so remove the label.
    meta:set_string("overstock:item", "")
    impl.remove_label_entity(pos, node, "overstock:barrel_item_label")
  end
end

function impl.put_stack(pos, node, itemstack)
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

  impl.remove_label_entity(pos, node, "overstock:barrel_item_label")
  impl.add_item_label_entity(pos, node, item_name)

  local barrel_inventory = core.get_inventory({ type = "node", pos = pos })
  barrel_inventory:add_item(impl.inventory_listname, itemstack)
  itemstack:clear()

  return itemstack
end

function impl.drop_inventory(pos)
  local meta = core.get_meta(pos)
  local inventory = meta and meta:get_inventory()

  if inventory then
    local list = inventory:get_list(impl.inventory_listname) or {}
    for _, stack in ipairs(list) do
      if stack and not stack:is_empty() then
        core.add_item(pos, stack)
      end
    end
  end
end

return impl
