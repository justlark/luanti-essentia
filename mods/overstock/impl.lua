local impl = {}

-- We don't use the typical default inventory name "main" because crates have
-- special rules they need to enforce, such as only allowing one type of item
-- in the crate at a time, and making sure the label is updated with the
-- current item type and count.
--
-- Other mods that try to interact with crates like chests will not be aware of
-- these rules and break them. There's no easy way for us to enforce these
-- rules when other mods are directly manipulating the inventory, because
-- callbacks like `allow_metadata_inventory_*` and `on_metadata_inventory_*`
-- are not triggered when other mods directly manipulate the inventory.
--
-- Unless we find a better solution, we'll have to manually implement support
-- for mods that interact with inventories.
local CRATE_INVENTORY_LISTNAME = "crate"

local CRATE_CAPACITY_STACKS = 64

local COUNT_LABEL_HEIGHT = 0.15
local COUNT_LABEL_CHAR_WIDTH = 0.045
local COUNT_LABEL_COLOR = "#000000"
local COUNT_LABEL_OPACITY = "255"
local COUNT_LABEL_KNOWN_CHARS = {
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

local CHAR_SIZE = { x = 5, y = 12 }

impl.BASE_ITEM_LABEL_SIZE = { x = 0.25, y = 0.25 }

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

function impl.initialize_inventory(pos)
  local meta = core.get_meta(pos)
  local inventory = meta:get_inventory()
  inventory:set_size(CRATE_INVENTORY_LISTNAME, CRATE_CAPACITY_STACKS)
end

local function char_texture(char)
  if COUNT_LABEL_KNOWN_CHARS[char] then
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

function impl.update_label(pos, node)
  impl.destroy_label(pos, node)
  impl.spawn_label(pos, node)
end

local function get_total_item_count(inventory, listname)
  local total = 0
  local size = inventory:get_size(listname)

  for i = 1, size do
    local stack = inventory:get_stack(listname, i)
    total = total + stack:get_count()
  end

  return total
end

local function get_free_space_for_item(inventory, listname, item_name)
  if not inventory then
    return 0
  end

  local stack = ItemStack(item_name)
  local stack_max = stack:get_stack_max()
  local free = 0

  local list = inventory:get_list(listname) or {}
  for _, slot in ipairs(list) do
    if slot:is_empty() then
      -- The full stack size is available.
      free = free + stack_max
    elseif slot:get_name() == item_name then
      -- Count the remaining space in this stack.
      free = free + (stack_max - slot:get_count())
    end
  end

  return free
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
  local crate_inventory = core.get_inventory({ type = "node", pos = pos })
  local item_count = get_total_item_count(crate_inventory, CRATE_INVENTORY_LISTNAME)

  -- No need to add a label if the crate contains to items. Otherwise we would
  -- get a label that says "0", which we don't want.
  if item_count == 0 then
    return
  end

  local offset = count_label_offset(node)
  local obj = core.add_entity(vector.add(pos, offset), "overstock:crate_count_label")

  if obj then
    local meta = core.get_meta(pos)
    local itemstack = ItemStack(meta:get_string("overstock:item"))
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

  if not crate_inventory:contains_item(CRATE_INVENTORY_LISTNAME, crate_itemstack) then
    -- The crate is empty.
    return
  end

  local requested_take_quantity

  if quantity == impl.TakeQuantity.ITEM then
    requested_take_quantity = 1
  elseif quantity == impl.TakeQuantity.STACK then
    requested_take_quantity = crate_itemstack:get_stack_max()
  else
    requested_take_quantity = 0
  end

  local player_inventory = puncher:get_inventory()
  local free_space_for_item = get_free_space_for_item(player_inventory, "main", item_name)

  -- Account for the fact that the player may not have enough space in their
  -- inventory to take a full stack or even a single item.
  local actual_take_quantity = math.min(requested_take_quantity, free_space_for_item)

  if actual_take_quantity == 0 then
    -- The player has no space in their inventory. No sense continuing.
    return
  end

  crate_itemstack:set_count(actual_take_quantity)

  local wielded_itemstack = player_inventory:get_stack("main", puncher:get_wield_index())
  local taken_itemstack = crate_inventory:remove_item(CRATE_INVENTORY_LISTNAME, crate_itemstack)

  if wielded_itemstack:get_name() == item_name or wielded_itemstack:is_empty() then
    -- The player is either holding a stack of this item or is empty-handed.
    -- Let's try to fill that inventory slot first.
    local remaining = wielded_itemstack:add_item(taken_itemstack)
    player_inventory:set_stack("main", puncher:get_wield_index(), wielded_itemstack)

    if not remaining:is_empty() then
      player_inventory:add_item("main", remaining)
    end
  else
    player_inventory:add_item("main", taken_itemstack)
  end

  core.sound_play("item_take", {
    pos = pos,
    gain = 0.3,
    max_hear_distance = 16,
    pitch = math.random(70, 110) / 100,
  }, true)

  -- Refresh the item count on the label.
  destroy_count_label(pos, node)
  add_count_label_entity(pos, node)

  if not crate_inventory:contains_item(CRATE_INVENTORY_LISTNAME, ItemStack(item_name)) then
    -- We've taken the last item from the crate, so remove the label.
    meta:set_string("overstock:item", "")
    impl.destroy_label(pos, node)
  end
end

function impl.put_item_stack(pos, node, itemstack)
  local item_name = itemstack:get_name()
  if item_name == "" then
    return itemstack
  end

  local crate_inventory = core.get_inventory({ type = "node", pos = pos })

  if
    not crate_inventory:is_empty(CRATE_INVENTORY_LISTNAME)
    and not crate_inventory:contains_item(CRATE_INVENTORY_LISTNAME, ItemStack(item_name), true)
  then
    -- There is already an item of a different type in the crate.
    return itemstack
  end

  local meta = core.get_meta(pos)
  meta:set_string("overstock:item", item_name)

  local remaining_items = crate_inventory:add_item(CRATE_INVENTORY_LISTNAME, itemstack)
  itemstack:set_count(remaining_items:get_count())

  impl.update_label(pos, node)

  return itemstack
end

function impl.put_all_items(pos, node, item_name, player)
  if item_name == "" then
    return
  end

  local crate_inventory = core.get_inventory({ type = "node", pos = pos })

  if
    not crate_inventory:is_empty(CRATE_INVENTORY_LISTNAME)
    and not crate_inventory:contains_item(CRATE_INVENTORY_LISTNAME, ItemStack(item_name), true)
  then
    -- There is already an item of a different type in the crate.
    return
  end

  local meta = core.get_meta(pos)
  meta:set_string("overstock:item", item_name)

  local player_inventory = player:get_inventory()
  local itemstacks = player_inventory:get_list("main")

  for i, stack in ipairs(itemstacks) do
    if stack:get_name() == item_name then
      local remaining_items = crate_inventory:add_item(CRATE_INVENTORY_LISTNAME, stack)
      player_inventory:set_stack("main", i, remaining_items)

      if not remaining_items:is_empty() then
        break
      end
    end
  end

  impl.update_label(pos, node)

  return itemstack
end

function impl.drop_inventory(pos)
  local meta = core.get_meta(pos)
  local crate_inventory = meta and meta:get_inventory()

  if crate_inventory then
    local list = crate_inventory:get_list(CRATE_INVENTORY_LISTNAME) or {}
    for _, stack in ipairs(list) do
      if stack and not stack:is_empty() then
        core.add_item(pos, stack)
      end
    end
  end
end

function impl.protection_check_move(pos, count, player)
  local name = player:get_player_name()
  if core.is_protected(pos, name) then
    core.record_protection_violation(pos, name)
    return 0
  else
    return count
  end
end

function impl.protection_check_put_take(pos, stack, player)
  local name = player:get_player_name()
  if core.is_protected(pos, name) then
    core.record_protection_violation(pos, name)
    return 0
  else
    return stack:get_count()
  end
end

return impl
