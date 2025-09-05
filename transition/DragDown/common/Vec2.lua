-- Vec2.lua
---@class Vec2
----@field class Vec2
local Vec2 = {}
Vec2.class = Vec2
Vec2.__index = Vec2

---@param a Vec2
---@return Vec2
function Vec2.copy (a)
    return Vec2(a.x, a.y)
end

---@param a Vec2
---@return number, number
function Vec2.unpack (a)
    return a.x, a.y
end

---@param a Vec2
---@return number
function Vec2.area (a)
    return a.x * a.y
end

---@param a Vec2
---@return number
function Vec2.length (a)
    return math.sqrt(a.x * a.x + a.y * a.y)
end

---@param a Vec2
---@return number
function Vec2.length2 (a)
    return a.x * a.x + a.y * a.y
end

---@param a Vec2
---@param b Vec2
---@return number
function Vec2.distance (a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

---@param a Vec2
---@param b Vec2
---@return number
function Vec2.distance2 (a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return dx * dx + dy * dy
end

---@param a Vec2
---@return number
function Vec2.radian (a)
    return math.atan2(a.y, a.x)
end

---@param a Vec2
---@return number
function Vec2.degree (a)
    return math.deg(math.atan2(a.y, a.x))
end

---@param a Vec2
---@return number
function Vec2.normalize (a)
    local l = a:length()
    a.x = a.x / l
    a.y = a.y / l
    return l
end

---@param a Vec2
---@return Vec2
function Vec2.normalized (a)
    local l = a:length()
    return Vec2(a.x / l, a.y / l)
end

---@param s Vec2
---@param min number|Vec2
---@param max number|Vec2
---@param update nil|boolean
---@return Vec2
function Vec2.clamp (s, min, max, update)
    local d = update and s or Vec2()
    local x, y = s:unpack()
    if type(min) == "number" then
        x = math.max(x, min)
        y = math.max(y, min)
    else
        x = math.max(x, min.x)
        y = math.max(y, min.y)
    end
    if type(max) == "number" then
        x = math.min(x, max)
        y = math.min(y, max)
    else
        x = math.min(x, max.x)
        y = math.min(y, max.y)
    end
    d.x = x
    d.y = y
    return d
end

---@param a Vec2
---@param b Vec2
---@return number
function Vec2.dot (a, b)
    return a.x * b.x + a.y * b.y
end

---@param a Vec2
---@param b Vec2
---@return number
function Vec2.cross (a, b)
    return a.x * b.y - a.y * b.x
end

---@param a Vec2
---@param b Vec2
---@param t number
---@return Vec2
function Vec2.lerp (a, b, t)
    return a + (b - a) * t
end

---@param a Vec2
---@param b Vec2
---@param t number
---@param ccw nil|boolean
---@return Vec2
function Vec2.slerp (a--[[normalized]], b--[[normalized]], t, ccw)
    local sinR = Vec2.cross(a, b)
    local R = math.asin(sinR)
    if ccw ~= nil then
        local Pi2 = math.pi + math.pi
        R = ccw and (R <= 0 and R + Pi2 or R) or (R >= 0 and R - Pi2 or R)
    end
    local R1 = R * t
    local R2 = R - R1
    local p = math.sin(R2) / sinR
    local q = math.sin(R1) / sinR
    return p * a + q * b
end

---@param a Vec2
---@param n Vec2
---@return Vec2
function Vec2.reflect (n--[[normalized]], a)
    local l = n:dot(a)
    return a - n * (l + l)
end

---@param a Vec2
---@param n Vec2
---@param r number
---@return Vec2
function Vec2.refract (a--[[normalized]], n--[[normalized]], r)
    local cosA = a:dot(n)
    local sinA2 = 1 - cosA * cosA
    local vf = math.sqrt(1 - sinA2 * r * r)
    local v = n * vf
    local h = (a + Vec2(cosA) * n) * r
    return h - v
end

function Vec2.__add (a, b)
    return Vec2(a.x + b.x, a.y + b.y)
end

function Vec2.__sub (a, b)
    return Vec2(a.x - b.x, a.y - b.y)
end

function Vec2.__mul (a, b)
    if type(a) == "number" then
        return Vec2(a * b.x, a * b.y)
    elseif type(b) == "number" then
        return Vec2(a.x * b, a.y * b)
    else
        return Vec2(a.x * b.x, a.y * b.y)
    end
end

function Vec2.__div (a, b)
    if type(b) == "number" then
        return Vec2(a.x / b, a.y / b)
    else
        return Vec2(a.x / b.x, a.y / b.y)
    end
end

function Vec2.__unm (a)
    return Vec2(-a.x, -a.y)
end

function Vec2.__eq (a, b)
    return a.x == b.x and a.y == b.y
end

function Vec2.__tostring (a)
    return string.format("[%f, %f]", a.x, a.y)
end

Vec2 = setmetatable(Vec2, {
    ---@param class Vec2
    ---@param x number
    ---@param y number|nil
    ---@return Vec2
    __call = function (class, x, y)
        return setmetatable({x = x, y = y or x}, class)
    end
})

return Vec2