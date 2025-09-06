local impl = {}

impl.INVENTORY_LISTNAME = "main"
impl.CRATE_CAPACITY_STACKS = 64
impl.BASE_ITEM_LABEL_SIZE = { x = 0.25, y = 0.25 }

local COUNT_LABEL_HEIGHT = 0.15
local COUNT_LABEL_CHAR_WIDTH = 0.045
local COUNT_LABEL_COLOR = "#000000"
local COUNT_LABEL_OPACITY = "255"
local CHAR_SIZE = { x = 5, y = 12 }

local function label_face(face)
  local faces = {
    -- +Z
    [0] = {
      item_offset = vector.new(0, -0.125, -0.5),
      count_offset = vector.new(0, 0.2, -0.51),
      yaw = 0,
    },
    -- -X
    [1] = {
      item_offset = vector.new(-0.5, -0.125, 0),
      count_offset = vector.new(-0.51, 0.2, 0),
      yaw = -math.pi / 2,
    },
    -- -Z
    [2] = {
      item_offset = vector.new(0, -0.125, 0.5),
      count_offset = vector.new(0, 0.2, 0.51),
      yaw = math.pi,
    },
    -- +X
    [3] = {
      item_offset = vector.new(0.5, -0.125, 0),
      count_offset = vector.new(0.51, 0.2, 0),
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

  local total_width = #chars * CHAR_SIZE.x
  local texture = string.format("[combine:%dx%d:%s", total_width, CHAR_SIZE.y, table.concat(parts, ":"))
  texture = texture .. string.format("^[colorize:%s:%s", COUNT_LABEL_COLOR, COUNT_LABEL_OPACITY)

  local visual_width = #chars * COUNT_LABEL_CHAR_WIDTH

  return texture, visual_width
end

local function int_to_chars(int)
  local array = {}
  local str = string.format("%d", int)

  for i = 1, #str do
    array[i] = str:sub(i, i)
  end

  return array
end

local function generate_count_texture(item_count, stack_size)
  if not item_count or not stack_size then
    return
  end

  local stacks = math.floor(item_count / stack_size)
  local remainder = item_count % stack_size

  local chars = {}

  if stack_size == 1 then
    for _, char in ipairs(int_to_chars(stacks)) do
      table.insert(chars, char)
    end
  elseif stacks == 0 then
    for _, char in ipairs(int_to_chars(remainder)) do
      table.insert(chars, char)
    end
  else
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

local function destroy_item_label(pos, node)
  local entity = find_item_label_entity(pos, node)
  if entity then
    entity:remove()
  end
end

local function destroy_count_label(pos, node)
  local entity = find_count_label_entity(pos, node)
  if entity then
    entity:remove()
  end
end

function impl.destroy_label(pos, node)
  destroy_item_label(pos, node)
  destroy_count_label(pos, node)
end

local function get_total_item_count(inventory)
  local total = 0
  local size = inventory:get_size(impl.INVENTORY_LISTNAME)

  for i = 1, size do
    local stack = inventory:get_stack(impl.INVENTORY_LISTNAME, i)
    total = total + stack:get_count()
  end

  return total
end

local function add_item_label_entity(pos, node)
  local meta = core.get_meta(pos)
  local item_name = meta:get_string("overstock:item")

  if not item_name or item_name == "" then
    return
  end

  local offset = item_label_offset(node)
  local obj = core.add_entity(vector.add(pos, offset), "overstock:crate_item_label", item_name)
  if obj then
    obj:set_yaw(label_yaw(node))
  end
end

local function add_count_label_entity(pos, node)
  local offset = count_label_offset(node)
  local obj = core.add_entity(vector.add(pos, offset), "overstock:crate_count_label")

  if obj then
    local crate_inventory = core.get_inventory({ type = "node", pos = pos })
    local meta = core.get_meta(pos)
    local itemstack = ItemStack(meta:get_string("overstock:item"))
    local item_count = get_total_item_count(crate_inventory)
    local stack_size = itemstack:get_stack_max()

    local texture, width = generate_count_texture(item_count, stack_size)

    obj:set_yaw(label_yaw(node))
    obj:set_properties({
      textures = { texture },
      visual_size = {
        x = width,
        y = COUNT_LABEL_HEIGHT,
      },
    })
  end
end

function impl.spawn_label(pos, node)
  if not find_item_label_entity(pos, node) then
    add_item_label_entity(pos, node)
  end

  if not find_count_label_entity(pos, node) then
    add_count_label_entity(pos, node)
  end
end

impl.TakeQuantity = {
  STACK = "stack",
  ITEM = "item",
}

function impl.take_items(pos, node, puncher, quantity)
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
  if quantity == impl.TakeQuantity.ITEM then
    crate_itemstack:set_count(1)
  elseif quantity == impl.TakeQuantity.STACK then
    crate_itemstack:set_count(crate_itemstack:get_stack_max())
  else
    crate_itemstack:set_count(0)
  end

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

  -- Refresh the item count on the label.
  destroy_count_label(pos, node)
  add_count_label_entity(pos, node)

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

  local crate_inventory = core.get_inventory({ type = "node", pos = pos })
  local remaining_items = crate_inventory:add_item(impl.INVENTORY_LISTNAME, itemstack)

  if remaining_items and remaining_items:is_empty() then
    itemstack:clear()
  end

  impl.destroy_label(pos, node)
  add_item_label_entity(pos, node)
  add_count_label_entity(pos, node)

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
