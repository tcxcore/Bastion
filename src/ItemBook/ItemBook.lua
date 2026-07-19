local tcx, Bastion = ...
local TCX = (type(Bastion) == 'table' and Bastion.TCX) or tcx

-- Create a new ItemBook class
---@class ItemBook
local ItemBook = {}
ItemBook.__index = ItemBook

-- Constructor
---@return ItemBook
function ItemBook:New()
    local self = setmetatable({}, ItemBook)
    self.items = {}
    return self
end

-- Get a spell from the ItemBook
---@param id number
---@return Item
function ItemBook:GetItem(id)
    if self.items[id] == nil then
        self.items[id] = Bastion.Item:New(id)
    end

    return self.items[id]
end

Bastion.ItemBook = ItemBook
return ItemBook
