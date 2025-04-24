-- Asteroids module
local Asteroids = {}

-- Import dependencies
local helpers = require("utils.helpers")

-- Constants
local ASTEROID_SPEED_MIN = 30
local ASTEROID_SPEED_MAX = 90
local ASTEROID_POINTS = { [3] = 20, [2] = 50, [1] = 100 } -- Points per size
local ASTEROID_SIZES = { large = 35, medium = 20, small = 10 } -- Radii
local ASTEROID_SIZE_MAP = { [3] = ASTEROID_SIZES.large, [2] = ASTEROID_SIZES.medium, [1] = ASTEROID_SIZES.small }
local ASTEROID_IRREGULARITY = 0.6 -- How much vertex distance varies (0=circle, 1=very jagged)

-- Module variables
local gameWidth, gameHeight
local sounds
local asteroids = {}
local PLAYER_SPAWN_SAFE_ZONE_RADIUS

-- Initialize module
function Asteroids.init(soundsTable, width, height, safeZoneRadius)
    sounds = soundsTable
    gameWidth = width
    gameHeight = height
    PLAYER_SPAWN_SAFE_ZONE_RADIUS = safeZoneRadius or 150
    asteroids = {}
end

-- Clear all asteroids
function Asteroids.clear()
    asteroids = {}
end

-- Create a new asteroid
function Asteroids.create(x, y, size)
    size = size or 3 -- Default to large size
    
    -- Spawn randomly outside safe zone if x,y not provided
    if not x or not y then
        local safeRadius = PLAYER_SPAWN_SAFE_ZONE_RADIUS
        local checkX, checkY
        local dist = 0
        
        repeat
            x = love.math.random(0, gameWidth)
            y = love.math.random(0, gameHeight)
            
            -- Determine center point for safe zone check
            local Player = require("games.asteroids.player")
            if Player.isFullyAlive() then
                checkX, checkY = Player.getPosition()
            else
                checkX, checkY = gameWidth / 2, gameHeight / 2
            end
            
            dist = helpers.distance(x, y, checkX, checkY)
            
        until dist >= safeRadius
        
        print(string.format("Spawned asteroid at %.1f, %.1f (Dist: %.1f)", x, y, dist))
    end
    
    -- Validate size
    if not ASTEROID_SIZE_MAP[size] then size = 3 end
    local radius = ASTEROID_SIZE_MAP[size]
    local pointsValue = ASTEROID_POINTS[size]
    
    -- Calculate speed (smaller asteroids are faster)
    local speedMultiplier = 1.5 - (size * 0.3)
    local speed = love.math.random(ASTEROID_SPEED_MIN, ASTEROID_SPEED_MAX) * speedMultiplier
    local angle = love.math.random() * math.pi * 2
    
    -- Create asteroid
    local asteroid = {
        x = x,
        y = y,
        size = size,
        radius = radius,
        dx = math.cos(angle) * speed,
        dy = math.sin(angle) * speed,
        angle = 0,
        spin = (love.math.random() - 0.5) * 2,
        points = pointsValue,
        shape = {}
    }
    
    -- Generate irregular shape
    local numPoints = math.random(8, 12)
    local baseRadius = asteroid.radius
    for i = 1, numPoints do
        local pointAngle = (i - 1) * (2 * math.pi / numPoints)
        local variation = love.math.random() * ASTEROID_IRREGULARITY * 2 + (1.0 - ASTEROID_IRREGULARITY)
        local r = baseRadius * variation
        asteroid.shape[i] = { x = math.cos(pointAngle) * r, y = math.sin(pointAngle) * r }
    end
    
    table.insert(asteroids, asteroid)
    return #asteroids -- Return the index of the new asteroid
end

-- Spawn initial asteroids for a wave
function Asteroids.spawnInitial(num)
    Asteroids.clear()
    for _ = 1, num do Asteroids.create() end
end

-- Update asteroids
function Asteroids.update(dt)
    for i = #asteroids, 1, -1 do
        local a = asteroids[i]
        if a then
            -- Update position with wrapping
            a.x = helpers.wrap(a.x + a.dx * dt, 0, gameWidth)
            a.y = helpers.wrap(a.y + a.dy * dt, 0, gameHeight)
            -- Update rotation
            a.angle = a.angle + a.spin * dt
        else
            table.remove(asteroids, i)
        end
    end
end

-- Draw asteroids
function Asteroids.draw()
    love.graphics.setColor(1, 1, 1, 1)
    for _, asteroid in ipairs(asteroids) do
        -- Basic validation
        if asteroid and asteroid.shape and #asteroid.shape >= 3 then
            if type(asteroid.x) == "number" and type(asteroid.y) == "number" then
                love.graphics.push()
                love.graphics.translate(asteroid.x, asteroid.y)
                love.graphics.rotate(asteroid.angle)
                
                -- Draw outline
                local vertices = {}
                for _, point in ipairs(asteroid.shape) do
                    table.insert(vertices, point.x)
                    table.insert(vertices, point.y)
                end
                love.graphics.polygon("line", vertices)
                
                love.graphics.pop()
            end
        end
    end
end

-- Break an asteroid (when hit by bullet)
function Asteroids.breakAsteroid(index)
    if index < 1 or index > #asteroids or not asteroids[index] then return 0 end
    
    local oldAsteroid = asteroids[index]
    local score = oldAsteroid.points or 0
    
    -- Play explosion sound and create particles
    if sounds.explosion then 
        local s = sounds.explosion:clone()
        if s then s:play() end
    end
    
    local Particles = require("games.asteroids.particles")
    Particles.createExplosion(oldAsteroid.x, oldAsteroid.y, 10)
    
    -- Spawn smaller asteroids if it wasn't a small one
    if oldAsteroid.size > 1 then
        local newSize = oldAsteroid.size - 1
        -- Create two smaller ones
        Asteroids.create(oldAsteroid.x + love.math.random(-5, 5), 
                         oldAsteroid.y + love.math.random(-5, 5), 
                         newSize)
        Asteroids.create(oldAsteroid.x + love.math.random(-5, 5),
                         oldAsteroid.y + love.math.random(-5, 5),
                         newSize)
    end
    
    table.remove(asteroids, index)
    return score
end

-- Check collision with a bullet
function Asteroids.checkBulletCollision(bullet)
    for i = #asteroids, 1, -1 do
        local a = asteroids[i]
        if a and a.shape then
            local worldPoly = helpers.transformVertices(a.shape, a.x, a.y, a.angle)
            if helpers.pointInPolygon(worldPoly, bullet.x, bullet.y) then
                return i
            end
        end
    end
    return 0 -- No collision
end

-- Check collision with player
function Asteroids.checkPlayerCollision(Player)
    if not Player.canBeHit() then return false end
    
    local playerX, playerY = Player.getPosition()
    local playerAngle = Player.getAngle()
    local playerShape = Player.getShape()
    
    local playerWorldPoly = helpers.transformVertices(playerShape, playerX, playerY, playerAngle)
    
    for i = #asteroids, 1, -1 do
        local a = asteroids[i]
        if a and a.shape then
            local asteroidWorldPoly = helpers.transformVertices(a.shape, a.x, a.y, a.angle)
            local collisionDetected = false
            
            -- Check if any player vertex is inside asteroid
            if playerWorldPoly then
                for _, pVertex in ipairs(playerWorldPoly) do
                    if helpers.pointInPolygon(asteroidWorldPoly, pVertex.x, pVertex.y) then
                        collisionDetected = true
                        break
                    end
                end
            end
            
            -- Check if any asteroid vertex is inside player
            if not collisionDetected and playerWorldPoly then
                for _, aVertex in ipairs(asteroidWorldPoly) do
                    if helpers.pointInPolygon(playerWorldPoly, aVertex.x, aVertex.y) then
                        collisionDetected = true
                        break
                    end
                end
            end
            
            if collisionDetected then
                return true
            end
        end
    end
    
    return false
end

-- Get asteroid count
function Asteroids.getCount()
    return #asteroids
end

-- Get asteroid data for external use
function Asteroids.getAsteroids()
    return asteroids
end

return Asteroids