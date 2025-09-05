package.path = "../?.lua;" .. package.path

local impl = require("impl")

describe("put stack", function()
  it("does nothing if the itemstack has no name", function()
    local itemstack = {}

    function itemstack:get_name()
      return ""
    end

    local new_itemstack = impl.put_stack({}, {}, itemstack)

    assert.equals(itemstack, new_itemstack)
  end)

  it("does nothing if a different item is already in the crate", function()
    local itemstack = {}

    function itemstack:get_name()
      return "test:item"
    end

    _G.core = {
      get_meta = function(_)
        return {
          get_string = function(_)
            return "test:other_item"
          end,
        }
      end,
    }

    local new_itemstack = impl.put_stack({}, {}, itemstack)

    assert.equals(itemstack, new_itemstack)
  end)

  it("stores the item name", function()
    local itemstack = {
      clear = function() end,
    }

    local item_name = "test:item"

    function itemstack:get_name()
      return item_name
    end

    _G.core = {
      get_meta = function(_)
        return {
          get_string = function(_, _)
            return item_name
          end,
          set_string = function(_, key, value)
            assert.equals("overstock:item", key)
            assert.equals(item_name, value)
          end,
        }
      end,
      get_inventory = function(_)
        return {
          add_item = function(_, _) end,
        }
      end,
    }

    impl.remove_label_entity = function(_, _, _) end
    impl.add_item_label_entity = function(_, _, _) end

    impl.put_stack({}, {}, itemstack)
  end)

  it("replaces the item label", function()
    local itemstack = {
      clear = function() end,
    }
    local pos = {}
    local node = {}
    local item_name = "test:item"

    function itemstack:get_name()
      return item_name
    end

    _G.core = {
      get_meta = function(_)
        return {
          get_string = function(_, _)
            return item_name
          end,
          set_string = function(_, _, _) end,
        }
      end,
      get_inventory = function(_)
        return {
          add_item = function(_, _) end,
        }
      end,
    }

    impl.remove_label_entity = function(this_pos, this_node, this_entity_name)
      assert.equals(pos, this_pos)
      assert.equals(node, this_node)
      assert.equals("overstock:crate_item_label", this_entity_name)
    end

    impl.add_item_label_entity = function(this_pos, this_node, this_item_name)
      assert.equals(pos, this_pos)
      assert.equals(node, this_node)
      assert.equals(item_name, this_item_name)
    end

    impl.put_stack(pos, node, itemstack)
  end)

  it("moves the itemstack from the player's hand to the crate's inventory", function()
    local was_cleared = false

    local itemstack = {
      clear = function()
        was_cleared = true
      end,
    }
    local pos = {}
    local node = {}
    local item_name = "test:item"

    function itemstack:get_name()
      return item_name
    end

    _G.core = {
      get_meta = function(_)
        return {
          get_string = function(_, _)
            return ""
          end,
          set_string = function(_, _, _) end,
        }
      end,
      get_inventory = function(_)
        return {
          add_item = function(_, inventory_name, added_itemstack)
            assert.equals("main", inventory_name)
            assert.equals(itemstack, added_itemstack)

            return {
              is_empty = function()
                return true
              end,
            }
          end,
        }
      end,
    }

    impl.remove_label_entity = function(_, _, _) end
    impl.add_item_label_entity = function(_, _, _) end

    impl.put_stack(pos, node, itemstack)

    assert(was_cleared, "Expected itemstack to be cleared after being added to crate inventory")
  end)

  it("does not accept more items once full", function()
    local was_cleared = false

    local itemstack = {
      clear = function()
        was_cleared = true
      end,
    }
    local pos = {}
    local node = {}
    local item_name = "test:item"

    function itemstack:get_name()
      return item_name
    end

    _G.core = {
      get_meta = function(_)
        return {
          get_string = function(_, _)
            return ""
          end,
          set_string = function(_, _, _) end,
        }
      end,
      get_inventory = function(_)
        return {
          add_item = function(_, _, _)
            return {
              is_empty = function()
                return false
              end,
            }
          end,
        }
      end,
    }

    impl.remove_label_entity = function(_, _, _) end
    impl.add_item_label_entity = function(_, _, _) end

    impl.put_stack(pos, node, itemstack)

    assert(not was_cleared, "Expected itemstack to not be cleared once crate inventory is full")
  end)
end)
