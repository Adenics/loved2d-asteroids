-- Helper utility functions
local helpers = {}

-- Wraps a value around a given range (toroidal coordinates)
function helpers.wrap(value, min_val, max_val)
    local range = max_val - min_val
    if range == 0 then return min_val end
    -- The double modulo handles negative values correctly
    return ((value - min_val) % range + range) % range + min_val
end

-- Calculates distance between two points
function helpers.distance(x1, y1, x2, y2)
    -- Guard against nil inputs which cause errors
    if x1 == nil or y1 == nil or x2 == nil or y2 == nil then return math.huge end
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

-- Function to check if a point (px, py) is inside a polygon
function helpers.pointInPolygon(poly, px, py)
    local crossings = 0
    local n = #poly
    if n < 3 then return false end -- Need at least 3 vertices

    for i = 1, n do
        local p1 = poly[i]
        local p2 = poly[i % n + 1] -- Next vertex, wraps around

        -- Check if point lies exactly on a vertex
        if px == p1.x and py == p1.y then
            return true
        end

        -- Check if the point's y is between the edge's y-coordinates
        local y_between = (p1.y <= py and py < p2.y) or (p2.y <= py and py < p1.y)

        if y_between then
            -- Calculate the edge's x-intercept at the point's y level
            if p2.y - p1.y ~= 0 then
                 -- Calculate intersection X coordinate using linear interpolation formula
                 local intersectX = (py - p1.y) * (p2.x - p1.x) / (p2.y - p1.y) + p1.x

                 -- If the point is to the left of the intersection, increment crossings
                 if px < intersectX then
                     crossings = crossings + 1
                 -- Check if the point lies exactly on a non-horizontal edge segment
                 elseif px == intersectX then
                    return true
                 end
            end
        -- Handle point lying on a horizontal edge segment
        elseif py == p1.y and py == p2.y then
            if px >= math.min(p1.x, p2.x) and px <= math.max(p1.x, p2.x) then
                return true -- Point is on a horizontal edge
            end
        end
    end
    -- Odd number of crossings means the point is inside
    return crossings % 2 == 1
end

-- Function to transform local polygon vertices to world coordinates
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

-- Smoothstep interpolation
function helpers.smoothstep(edge0, edge1, x)
    local t = math.max(0, math.min(1, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)
end

return helpers