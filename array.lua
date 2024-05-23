local Array = {}

function Array:new(b)
    local base = ((type(b) == "table") and b) or {}
    setmetatable(base, self)
    self.__index = self
    return base
end

function Array:for_each(callbackFn)
    for i, v in ipairs(self) do
        callbackFn(v, i)
    end
end

function Array:map(callbackFn)
    local newArr = Array:new({})
    for i, v in ipairs(self) do
        local newValue = callbackFn(v, i)
        newArr[i] = newValue
    end
    return newArr
end

function Array:filter(filterFn)
    local newArr = Array:new({})
    for i, v in ipairs(self) do
        local pass = filterFn(v, i)
        if pass then
            table.insert(newArr, v)
        end
    end
    return newArr
end

function Array:join(sep) 
    sep = tostring(sep) or ","
    local str = ""
    self:forEach(function(v, i) 
        if (#self - i) > 0 then 
            str = str .. tostring(v) .. sep
        else
            str = str .. tostring(v)
        end
    end)
    return str
end

function Array:pop() 
    local item = self[#self];
    table.remove(self, #self);
    return item
end

function Array:shift() 
    local item = self[1];
    table.remove(self, 1);
    return item
end

function Array:push(value) 
    table.insert(self, value)
end

function Array:random_element() 
    local randomIndex = math.random(1, #self);
    return self[randomIndex]
end

function Array:push_array(value) 
    for _, item in ipairs(value) do 
        self:push(item)
    end
end

return Array
