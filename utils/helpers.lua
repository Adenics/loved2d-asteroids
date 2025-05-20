local helpers = {}

function helpers.wrap(value, min_val, max_val)
    local range = max_val - min_val
    if range == 0 then return min_val end

    return ((value - min_val) % range + range) % range + min_val
end

function helpers.distance(x1, y1, x2, y2)

    if x1 == nil or y1 == nil or x2 == nil or y2 == nil then return math.huge end
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

function helpers.pointInPolygon(poly, px, py)
    local crossings = 0
    local n = #poly
    if n < 3 then return false end 

    for i = 1, n do
        local p1 = poly[i]
        local p2 = poly[i % n + 1] 

        if px == p1.x and py == p1.y then
            return true
        end

        local y_between = (p1.y <= py and py < p2.y) or (p2.y <= py and py < p1.y)

        if y_between then

            if p2.y - p1.y ~= 0 then

                 local intersectX = (py - p1.y) * (p2.x - p1.x) / (p2.y - p1.y) + p1.x

                 if px < intersectX then
                     crossings = crossings + 1

                 elseif px == intersectX then
                    return true
                 end
            end

        elseif py == p1.y and py == p2.y then
            if px >= math.min(p1.x, p2.x) and px <= math.max(p1.x, p2.x) then
                return true 
            end
        end
    end

    return crossings % 2 == 1
end

function helpers.transformVertices(localVertices, objX, objY, objAngle)
    local worldVertices = {}
    local cosA = math.cos(objAngle)
    local sinA = math.sin(objAngle)
    for i, p in ipairs(localVertices) do
        local rotatedX = cosA * p.x - sinA * p.y
        local rotatedY = sinA * p.x + cosA * p.y
        table.insert(worldVertices, { x = objX + rotatedX, y = objY + rotatedY })
    end
    return worldVertices
end

function helpers.smoothstep(edge0, edge1, x)
    local t = math.max(0, math.min(1, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)
end

return helpers