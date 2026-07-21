local tcx, Bastion = ...
local TCX = (type(Bastion) == 'table' and Bastion.TCX) or tcx

---@class ClassMagic
local ClassMagic = {}
ClassMagic.__index = ClassMagic

---@param Class table
---@param key string
---@param instance? table
---@return any
function ClassMagic:Resolve(Class, key, instance)
    if Class[key] or Class[key] == false then
        return Class[key]
    end

    local obj = instance or (self ~= ClassMagic and self) or Class

    local getMethod = 'Get' .. key:sub(1, 1):upper() .. key:sub(2)
    if Class[getMethod] then
        local func = Class[getMethod]

        -- Call the function and return the result if there's more than one return value return it as a table
        local result = { func(obj) }
        if #result > 1 then
            return result
        end

        return result[1]
    end


    local getUpperMethod = 'Get' .. key:upper()
    if Class[getUpperMethod] then
        local func = Class[getUpperMethod]

        -- Call the function and return the result if there's more than one return value return it as a table
        local result = { func(obj) }
        if #result > 1 then
            return result
        end

        return result[1]
    end

    local isUpperMethod = 'Is' .. key:upper()
    if Class[isUpperMethod] then
        local func = Class[isUpperMethod]

        -- Call the function and return the result if there's more than one return value return it as a table
        local result = { func(obj) }
        if #result > 1 then
            return result
        end

        return result[1]
    end

    return Class[key]
end

Bastion.ClassMagic = ClassMagic
return ClassMagic
