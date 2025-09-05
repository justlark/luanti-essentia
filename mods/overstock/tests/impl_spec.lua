package.path = "../?.lua;" .. package.path

local impl = require("impl")

describe("put stack", function()
  it("does nothing if the itemstack has no name", function()
    local itemstack = {}

    function itemstack:get_name()
      return ""
    end

    local new_itemstack = impl.put_stack({ x = 0, y = 0, z = 0 }, {}, itemstack)

    assert.equals(new_itemstack, itemstack)
  end)

  it("does nothing if a different item is already in the barrel", function()
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

    local new_itemstack = impl.put_stack({ x = 0, y = 0, z = 0 }, {}, itemstack)

    assert.equals(new_itemstack, itemstack)
  end)

  it("stores the item name", function()
    local itemstack = {}

    function itemstack:get_name()
      return "test:item"
    end

    _G.core = {
      get_meta = function(_)
        return {
          get_string = function(_)
            return "test:item"
          end,
          set_string = function(self, key, value)
            assert.equals("overstock:item", key)
            assert.equals("test:item", value)
          end,
        }
      end,
    }

    impl.put_stack({ x = 0, y = 0, z = 0 }, {}, itemstack)
  end)
end)
