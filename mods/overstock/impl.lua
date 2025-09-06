local impl = {}

impl.INVENTORY_LISTNAME = "main"
impl.CRATE_CAPACITY_STACKS = 64
impl.BASE_ITEM_LABEL_SIZE = { x = 0.25, y = 0.25 }
impl.BASE_COUNT_LABEL_SIZE = { x = 0.15, y = 0.15 }

local COUNT_LABEL_COLOR = "#000000"
local COUNT_LABEL_OPACITY = "255"
local CHAR_SIZE = { x = 5, y = 12 }

local function label_face(face)
  local faces = {
    -- +Z
    [0] = {
      item_offset = vector.new(0, 0.0, -0.5),
      count_offset = vector.new(0, -0.35, -0.51),
      yaw = 0,
    },
    -- -X
    [1] = {
      item_offset = vector.new(-0.5, 0.0, 0),
      count_offset = vector.new(-0.51, -0.35, 0),
      yaw = -math.pi / 2,
    },
    -- -Z
    [2] = {
      item_offset = vector.new(0, 0.0, 0.5),
      count_offset = vector.new(0, -0.35, 0.51),
      yaw = math.pi,
    },
    -- +X
    [3] = {
      item_offset = vector.new(0.5, 0.0, 0),
      count_offset = vector.new(0.51, -0.35, 0),
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

local KNOWN_CHARS = {
  ["0"] = true,
  ["1"] = true,
  ["2"] = true,
  ["3"] = true,
  ["4"] = true,
  ["5"] = true,
  ["6"] = true,
  ["7"] = true,
  ["8"] = true,
  ["9"] = true,
  ["plus"] = true,
  ["times"] = true,
}

local function char_texture(char)
  if KNOWN_CHARS[char] then
    return "overstock_char_" .. char .. ".png"
  end
end

local function generate_text_label(chars)
  local parts = {}

  for i = 1, #chars do
    local char = chars[i]
    local texture = char_texture(char)

    -- If there's no texture for this character, skip it and leave a space.
    -- We'll make use of this to add literal spaces in the generated string.
    if texture then
      local x = (i - 1) * CHAR_SIZE.x
      table.insert(parts, string.format("%d,0=%s", x, texture))
    end
  end

  local total_w = #chars * CHAR_SIZE.x
  local texture = string.format("[combine:%dx%d:%s", total_w, CHAR_SIZE.y, table.concat(parts, ":"))
  texture = texture .. string.format("^[colorize:%s:%s", COUNT_LABEL_COLOR, COUNT_LABEL_OPACITY)

  return texture
end

local function int_to_chars(int)
  local array = {}
  local str = string.format("%d", int)

  for i = 1, #str do
    array[i] = str:sub(i, i)
  end

  return array
end

function impl.generate_count_texture(count)
  local items = count.items
  local stack_size = count.stack_size

  if not items or not stack_size then
    return
  end

  local stacks = math.floor(items / stack_size)
  local remainder = items % stack_size

  local chars = {}

  for _, char in ipairs(int_to_chars(stacks)) do
    table.insert(chars, char)
  end

  table.insert(chars, " ")
  table.insert(chars, "times")
  table.insert(chars, " ")

  for _, char in ipairs(int_to_chars(stack_size)) do
    table.insert(chars, char)
  end

  if remainder > 0 then
    table.insert(chars, " ")
    table.insert(chars, "plus")
    table.insert(chars, " ")
    for _, char in ipairs(int_to_chars(remainder)) do
      table.insert(chars, char)
    end
  end

  return generate_text_label(chars)
end

local function find_label_entity(pos, offset, entity_name)
  local target = vector.add(pos, offset)
  for _, obj in pairs(core.get_objects_inside_radius(target, 0.1)) do
    local entity = obj:get_luaentity()
    if entity and entity.name == entity_name then
      return obj
    end
  end
end

local function find_item_label_entity(pos, node)
  return find_label_entity(pos, item_label_offset(node), "overstock:crate_item_label")
end

local function find_count_label_entity(pos, node)
  return find_label_entity(pos, count_label_offset(node), "overstock:crate_count_label")
end

function impl.label_exists(pos, node)
  return find_item_label_entity(pos, node) ~= nil or find_count_label_entity(pos, node) ~= nil
end

function impl.destroy_label(pos, node)
  local item_label = find_item_label_entity(pos, node)
  if item_label then
    item_label:remove()
  end

  local count_label = find_count_label_entity(pos, node)
  if count_label then
    count_label:remove()
  end
end

function impl.add_item_label_entity(pos, node, item_name)
  local offset = item_label_offset(node)
  local obj = core.add_entity(vector.add(pos, offset), "overstock:crate_item_label", item_name)
  if obj then
    obj:set_yaw(label_yaw(node))
  end
end

function impl.add_count_label_entity(pos, node, count)
  local offset = count_label_offset(node)
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
