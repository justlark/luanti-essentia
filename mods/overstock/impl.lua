local impl = {}

impl.INVENTORY_LISTNAME = "main"
impl.CRATE_CAPACITY_STACKS = 64
impl.BASE_LABEL_SIZE = { x = 0.25, y = 0.25 }

local CHAR_SIZE = { x = 5, y = 12 }

local function label_face(face)
  local faces = {
    -- +Z
    [0] = {
      item_offset = vector.new(0, 0.0, -0.5),
      count_offset = vector.new(0, 0.3, -0.501),
      yaw = 0,
    },
    -- -X
    [1] = {
      item_offset = vector.new(-0.5, 0.0, 0),
      count_offset = vector.new(-0.501, 0.3, 0),
      yaw = -math.pi / 2,
    },
    -- -Z
    [2] = {
      item_offset = vector.new(0, 0.0, 0.5),
      count_offset = vector.new(0, 0.3, 0.501),
      yaw = math.pi,
    },
    -- +X
    [3] = {
      item_offset = vector.new(0.5, 0.0, 0),
      count_offset = vector.new(0.501, 0.3, 0),
      yaw = math.pi / 2,
    },
  }

  return faces[face]
end

local function face_dir(node)
  return node.param2 % 4
end

local function item_label_offset(node)
  return label_face(face_dir(node)).item_offset
end

local function count_label_offset(node)
  return label_face(face_dir(node)).count_offset
end

local function label_yaw(node)
  return label_face(face_dir(node)).yaw
end

local function char_texture(char)
  return "overstock_char_" .. char .. ".png"
end

local function generate_number_texture(digits)
  local parts = {}

  for i = 1, #digits do
    local digit = digits:sub(i, i)
    local texture = char_texture(digit)
    local x = (i - 1) * CHAR_SIZE.x
    table.insert(parts, string.format("%d,0=%s", x, texture))
  end

  local total_w = #digits * CHAR_SIZE.x
  return string.format("[combine:%dx%d:%s", total_w, CHAR_SIZE.y, table.concat(parts, ":"))
end

function impl.generate_count_texture(count)
  -- TODO: Implement
  return generate_number_texture("123")
end

local function find_label_entity(pos, node, entity_name)
  local target = vector.add(pos, item_label_offset(node))
  for _, obj in pairs(core.get_objects_inside_radius(target, 0.1)) do
    local entity = obj:get_luaentity()
    if entity and entity.name == entity_name then
      return obj
    end
  end
end

function impl.label_exists(pos, node)
  return find_label_entity(pos, node, "overstock:crate_item_label") ~= nil
      or find_label_entity(pos, node, "overstock:crate_count_label") ~= nil
end

local function remove_label_entity(pos, node, entity_name)
  local entity = find_label_entity(pos, node, entity_name)
  if entity then
    entity:remove()
  end
end

function impl.destroy_label(pos, node)
  remove_label_entity(pos, node, "overstock:crate_item_label")
  remove_label_entity(pos, node, "overstock:crate_count_label")
end

function impl.add_item_label_entity(pos, node, item_name)
  local offset = item_label_offset(node)
  local obj = core.add_entity(vector.add(pos, offset), "overstock:crate_item_label", item_name)
  if obj then
    obj:set_yaw(label_yaw(node))
  end
end

function impl.add_count_label_entity(pos, node, count)
  local offset = item_label_offset(node)
  local obj = core.add_entity(vector.add(pos, offset), "overstock:crate_count_label", count)
  if obj then
    obj:set_yaw(label_yaw(node))
  end
end

function impl.take_stack(pos, node, puncher)
  local meta = core.get_meta(pos)
  local item_name = meta:get_string("overstock:item")

  if not item_name or item_name == "" then
    -- The crate is empty.
    return
  end

  local crate_inventory = core.get_inventory({ type = "node", pos = pos })
  local crate_itemstack = ItemStack(item_name)

  if not crate_inventory:contains_item(impl.INVENTORY_LISTNAME, crate_itemstack) then
    -- The crate is empty.
    return
  end

  -- Get a full stack, or as much as it contains.
  crate_itemstack:set_count(crate_itemstack:get_stack_max() or 1)

  local player_inventory = puncher:get_inventory()
  local wielded_itemstack = player_inventory:get_stack(impl.INVENTORY_LISTNAME, puncher:get_wield_index())
  local taken_itemstack = crate_inventory:remove_item(impl.INVENTORY_LISTNAME, crate_itemstack)

  -- If the player is wielding a stack of the type in the crate, add the taken
  -- items to that stack. Otherwise, add the taken items to the player's
  -- inventory.
  if wielded_itemstack:is_empty() then
    player_inventory:set_stack(impl.INVENTORY_LISTNAME, puncher:get_wield_index(), taken_itemstack)
  else
    player_inventory:add_item(impl.INVENTORY_LISTNAME, taken_itemstack)
  end

  if not crate_inventory:contains_item(impl.INVENTORY_LISTNAME, ItemStack(item_name)) then
    -- We've taken the last item from the crate, so remove the label.
    meta:set_string("overstock:item", "")
    impl.destroy_label(pos, node)
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
    -- There is already an item of a different type in the crate.
    return itemstack
  end

  meta:set_string("overstock:item", item_name)

  impl.destroy_label(pos, node)
  impl.add_item_label_entity(pos, node, item_name)
  -- TODO: Implement
  impl.add_count_label_entity(pos, node, 0)

  local crate_inventory = core.get_inventory({ type = "node", pos = pos })
  local remaining_items = crate_inventory:add_item(impl.INVENTORY_LISTNAME, itemstack)

  if remaining_items and remaining_items:is_empty() then
    itemstack:clear()
  end

  return itemstack
end

function impl.drop_inventory(pos)
  local meta = core.get_meta(pos)
  local inventory = meta and meta:get_inventory()

  if inventory then
    local list = inventory:get_list(impl.INVENTORY_LISTNAME) or {}
    for _, stack in ipairs(list) do
      if stack and not stack:is_empty() then
        core.add_item(pos, stack)
      end
    end
  end
end

return impl
