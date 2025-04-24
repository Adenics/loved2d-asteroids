-- UFO module for Asteroids
local UFO = {}

-- Import dependencies
local helpers = require("utils.helpers")

-- Constants
local UFO_SPEED = 110 -- Base horizontal speed
local UFO_FIRE_RATE = 1.4 -- Seconds between shots
local UFO_BULLET_SPEED = 270
local UFO_POINTS = 200
local UFO_MIN_LIFETIME = 8 -- Min seconds UFO stays on screen
local UFO_MAX_LIFETIME = 15 -- Max seconds UFO stays on screen
local UFO_DIRECTION_CHANGE_INTERVAL = 2.0 -- Seconds between potential direction changes
local UFO_LEAVING_SPEED_MULTIPLIER = 3.0 -- How much faster it moves when leaving

-- Module variables
local gameWidth, gameHeight
local sounds
local ufo = nil
local ufoBullets = {}
local ufoActive = false
local ufoFireTimer = 0
local ufoDirectionChangeTimer = 0

-- Initialize module
function UFO.init(soundsTable, width, height)
    sounds = soundsTable
    gameWidth = width
    gameHeight = height
    UFO.clear()
end

-- Clear UFO state
function UFO.clear()
    ufo = nil
    ufoBullets = {}
    ufoActive = false
    ufoFireTimer = 0
    ufoDirectionChangeTimer = 0
end

-- Spawn UFO
function UFO.spawn()
    if ufoActive then return false end
    
    local side = love.math.random(2)
    local x, y, dx, dy
    local buffer = 20
    
    -- Choose vertical position and starting side
    y = love.math.random(gameHeight * 0.2, gameHeight * 0.8)
    if side == 1 then
        x, dx, dy = -buffer, UFO_SPEED, 0
    else
        x, dx, dy = gameWidth + buffer, -UFO_SPEED, 0
    end
    
    -- Create UFO object
    ufo = {
        x = x,
        y = y,
        dx = dx,
        dy = dy,
        radius = 15,
        shape = {
            -15, 0, -10, -5, 10, -5, 15, 0, 10, 5, -10, 5, -15, 0, -- Main body
            -10, -5, -5, -10, 5, -10, 10, -5, -- Top saucer part
            5, -10, 0, -13, -5, -10 -- Antenna
        },
        visible = true,
        leaving = false,
        lifetime = love.math.random(UFO_MIN_LIFETIME, UFO_MAX_LIFETIME)
    }
    
    ufoActive = true
    ufoFireTimer = UFO_FIRE_RATE / 2 -- Start with shorter delay for first shot
    ufoDirectionChangeTimer = UFO_DIRECTION_CHANGE_INTERVAL * love.math.random(0.5, 1.0)
    
    -- Play sounds
    if sounds.ufo_spawn then sounds.ufo_spawn:play() end
    if sounds.ufo_flying then 
        sounds.ufo_flying:setLooping(true)
        sounds.ufo_flying:play()
    end
    
    print("UFO Spawned with lifetime: " .. ufo.lifetime)
    return true
end

-- Update UFO
function UFO.update(dt, Player)
    if not ufoActive or not ufo then return end
    
    local despawn_buffer = 30
    
    -- Handle leaving state
    if ufo.leaving then
        local direction = (ufo.dx > 0 and 1 or -1)
        if ufo.dx == 0 then 
            ufo.dx = (ufo.x > gameWidth / 2) and -UFO_SPEED or UFO_SPEED
        end
        ufo.dx = (ufo.dx > 0 and 1 or -1) * UFO_SPEED * UFO_LEAVING_SPEED_MULTIPLIER
        ufo.dy = 0
        ufo.x = ufo.x + ufo.dx * dt
        
        -- Check if off-screen
        if (ufo.dx > 0 and ufo.x > gameWidth + despawn_buffer) or
           (ufo.dx < 0 and ufo.x < -despawn_buffer) then
            UFO.destroy(false) -- Despawn without score
        end
        return
    end
    
    -- Update lifetime
    ufo.lifetime = ufo.lifetime - dt
    if ufo.lifetime <= 0 then
        print("UFO lifetime expired. Setting to leave.")
        ufo.leaving = true
        if sounds.ufo_flying and sounds.ufo_flying:isPlaying() then 
            sounds.ufo_flying:stop()
        end
        return
    end
    
    -- Normal movement
    ufo.x = ufo.x + ufo.dx * dt
    ufo.y = ufo.y + ufo.dy * dt
    
    -- Direction changes
    ufoDirectionChangeTimer = ufoDirectionChangeTimer - dt
    if ufoDirectionChangeTimer <= 0 then
        local changeType = love.math.random(3)
        
        if changeType == 1 then
            -- Change vertical direction
            ufo.dy = (love.math.random(3) - 2) * UFO_SPEED * love.math.random(0.4, 0.9)
        elseif changeType == 2 and ufo.dy ~= 0 then
            -- Change horizontal direction
            ufo.dx = (love.math.random(3) - 2) * UFO_SPEED * love.math.random(0.4, 0.9)
        elseif changeType == 3 and Player and Player.isFullyAlive() then
            -- Target player's general Y area
            local playerX, playerY = Player.getPosition()
            local targetY = playerY + love.math.random(-gameHeight * 0.25, gameHeight * 0.25)
            ufo.dy = (targetY > ufo.y and 1 or -1) * UFO_SPEED * love.math.random(0.3, 0.7)
        end
        
        -- Ensure horizontal movement
        if ufo.dx == 0 then
            ufo.dx = (ufo.x < gameWidth / 2) and UFO_SPEED * 0.5 or -UFO_SPEED * 0.5
        end
        
        -- Reset horizontal speed to base
        if ufo.dx ~= 0 then
            ufo.dx = (ufo.dx > 0) and UFO_SPEED or -UFO_SPEED
        end
        
        ufoDirectionChangeTimer = UFO_DIRECTION_CHANGE_INTERVAL * love.math.random(0.4, 1.0)
    end
    
    -- Shooting (only if player is alive)
    if Player and Player.isFullyAlive() then
        ufoFireTimer = ufoFireTimer - dt
        if ufoFireTimer <= 0 then
            UFO.fireBullet(Player)
            ufoFireTimer = UFO_FIRE_RATE * love.math.random(0.8, 1.2)
        end
    end
    
    -- Conditional vertical wrapping
    local onScreenBuffer = 5
    if not ufo.leaving and ufo.x > onScreenBuffer and ufo.x < gameWidth - onScreenBuffer then
        ufo.y = helpers.wrap(ufo.y, 0, gameHeight)
    end
    
    -- Leave if reached edge naturally
    if not ufo.leaving then
        if (ufo.dx > 0 and ufo.x >= gameWidth) or (ufo.dx < 0 and ufo.x <= 0) then
            print("UFO reached edge naturally. Setting to leave.")
            ufo.leaving = true
            if sounds.ufo_flying and sounds.ufo_flying:isPlaying() then
                sounds.ufo_flying:stop()
            end
        end
    end
    
    -- Update UFO bullets
    for i = #ufoBullets, 1, -1 do
        local b = ufoBullets[i]
        if b then
            b.x = helpers.wrap(b.x + b.dx * dt, 0, gameWidth)
            b.y = helpers.wrap(b.y + b.dy * dt, 0, gameHeight)
            b.lifetime = b.lifetime - dt
            if b.lifetime <= 0 then table.remove(ufoBullets, i) end
        else
            table.remove(ufoBullets, i)
        end
    end
end

-- Draw UFO
function UFO.draw()
    if not ufoActive or not ufo then return end
    if type(ufo.x) ~= "number" or type(ufo.y) ~= "number" or not ufo.shape then return end
    
    -- Draw UFO body
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.push()
    love.graphics.translate(ufo.x, ufo.y)
    if #ufo.shape >= 6 then love.graphics.polygon("line", ufo.shape) end
    love.graphics.pop()
    
    -- Draw UFO bullets
    if not ufo.leaving then
        love.graphics.setColor(1, 0, 0, 1)
        for _, b in ipairs(ufoBullets) do
            if b and type(b.x) == "number" and type(b.y) == "number" then
                love.graphics.circle("fill", b.x, b.y, b.radius or 3)
            end
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- Fire a bullet from the UFO
function UFO.fireBullet(Player)
    if not ufo or not Player or Player.isDying or Player.isRespawning or ufo.leaving then
        return false
    end
    
    local playerX, playerY = Player.getPosition()
    
    -- Aim towards player with some inaccuracy
    local angleToPlayer = math.atan2(playerY - ufo.y, playerX - ufo.x)
    angleToPlayer = angleToPlayer + (love.math.random() - 0.5) * 0.3
    
    -- Create bullet
    table.insert(ufoBullets, {
        x = ufo.x,
        y = ufo.y,
        dx = math.cos(angleToPlayer) * UFO_BULLET_SPEED,
        dy = math.sin(angleToPlayer) * UFO_BULLET_SPEED,
        lifetime = 2.0,
        radius = 3
    })
    
    -- Play sound
    if sounds.ufo_shoot then
        local s = sounds.ufo_shoot:clone()
        if s then s:play() end
    end
    
    return true
end

-- Destroy the UFO
function UFO.destroy(hitByPlayer)
    if not ufoActive then return false end
    
    if hitByPlayer then
        if sounds.explosion then
            local s = sounds.explosion:clone()
            if s then s:play() end
        end
        
        if ufo then
            local Particles = require("games.asteroids.particles")
            Particles.createExplosion(ufo.x, ufo.y, 15)
        end
    end
    
    -- Stop flying sound
    if sounds.ufo_flying and sounds.ufo_flying:isPlaying() then
        sounds.ufo_flying:stop()
    end
    
    -- Reset UFO state
    print("Destroying UFO. Active: false")
    ufo = nil
    ufoActive = false
    ufoBullets = {}
    
    return true
end

-- Check collision with a player bullet
function UFO.checkBulletCollision(bullet)
    if not ufoActive or not ufo or ufo.leaving then return false end
    
    -- Use circular collision for simplicity
    local dx = bullet.x - ufo.x
    local dy = bullet.y - ufo.y
    local distSq = dx * dx + dy * dy
    local radiusSum = (bullet.radius or 2) + ufo.radius
    
    return distSq < (radiusSum * radiusSum)
end

-- Check collision with player
function UFO.checkPlayerCollision(Player)
    if not ufoActive or not ufo or ufo.leaving or not Player.canBeHit() then
        return false
    end
    
    local playerX, playerY = Player.getPosition()
    local playerRadius = Player.getRadius()
    
    -- Use circular collision for player vs UFO
    local dx = playerX - ufo.x
    local dy = playerY - ufo.y
    local distSq = dx * dx + dy * dy
    local radiusSum = playerRadius + ufo.radius
    
    if distSq < (radiusSum * radiusSum) then
        return true
    end
    
    -- Check player vs UFO bullets
    for i = #ufoBullets, 1, -1 do
        local b = ufoBullets[i]
        if b then
            dx = playerX - b.x
            dy = playerY - b.y
            distSq = dx * dx + dy * dy
            radiusSum = playerRadius + (b.radius or 3)
            
            if distSq < (radiusSum * radiusSum) then
                table.remove(ufoBullets, i)
                return true
            end
        end
    end
    
    return false
end

-- Status checks
function UFO.isActive()
    return ufoActive
end

function UFO.isLeaving()
    return ufo and ufo.leaving
end

function UFO.getPoints()
    return UFO_POINTS
end

return UFO