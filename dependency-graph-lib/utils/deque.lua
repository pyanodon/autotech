-- Severely adapted from https://stackoverflow.com/a/18844036

--- @class deque
--- @field private first integer
--- @field private last integer
--- @field private __index deque
local deque = {}
deque.__index = deque

---comment
---@return deque
function deque.new()
    local r = {}
    setmetatable(r, deque)

    r.first = 0
    r.last = -1
    return r
end

function deque:push_left(value)
    local first = self.first - 1
    self.first = first
    self[first] = value
end

function deque:push_right(value)
    local last = self.last + 1
    self.last = last
    self[last] = value
end

function deque:pop_left()
    local first = self.first
    if first > self.last then error("deque is empty") end
    local value = self[first]
    self[first] = nil
    self.first = first + 1
    return value
end

function deque:pop_right()
    local last = self.last
    if self.first > last then error("deque is empty") end
    local value = self[last]
    self[last] = nil
    self.last = last - 1
    return value
end

function deque:is_empty()
    return self.last + 1 == self.first
end

return deque
