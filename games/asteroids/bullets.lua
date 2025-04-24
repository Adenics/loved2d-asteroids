-- Bullets module for Asteroids
local Bullets = {}

-- Import dependencies
local helpers = require("utils.helpers")

-- Constants
local BULLET_SPEED = 450
local BULLET_LIFETIME = 1.2 -- Seconds
local MAX_BULLETS = 4 -- Max bullets on screen

-- Module variables
local gameWidth, gameHeight
local sounds
local bullets = {}

-- Initialize module
function Bullets.init(soundsTable, width, height)
    sounds = soundsTable
    gameWidth = width
    gameHeight = height
    bullets = {}
end

-- Clear all bullets
function Bullets.clear()
    bullets = {}
end

-- Fire a bullet
function Bullets.fire(playerX, playerY, playerAngle, playerDX, playerDY)
    -- Check if we can fire (max bullets)
    if #bullets >= MAX_BULLETS then return false end
    
    -- Calculate bullet starting position (tip of the ship)
    local noseX = 12 -- Assuming ship shape nose is at (12, 0)
    local noseY = 0
    local cosA = math.cos(playerAngle)
    local sinA = math.sin(playerAngle)
    local startX = playerX + cosA * noseX - sinA * noseY
    local startY = playerY + sinA * noseX + cosA * noseY
    
    -- Create bullet
    table.insert(bullets, {
        x = startX,
        y = startY,
        dx = cosA * BULLET_SPEED + (playerDX or 0),
        dy = sinA * BULLET_SPEED + (playerDY or 0),
        lifetime = BULLET_LIFETIME,
        radius = 2
    })
    
    -- Play sound
    if sounds.shoot then
        local s = sounds.shoot:clone()
        if s then s:play() end
    end
    
    return true
end

-- Update bullets
function Bullets.update(dt)
    local i = #bullets
    while i >= 1 do
        local b = bullets[i]
        local removeBullet = false
        
        if not b then
            removeBullet = true
        else
            -- Update position with wrapping
            b.x = helpers.wrap(b.x + b.dx * dt, 0, gameWidth)
            b.y = helpers.wrap(b.y + b.dy * dt, 0, gameHeight)
            
            -- Decrease lifetime
            b.lifetime = b.lifetime - dt
            
            -- Remove if expired
            if b.lifetime <= 0 then
                removeBullet = true
            end
        end
        
        if removeBullet then
            table.remove(bullets, i)
        end
        i = i - 1
    end
end

-- Draw bullets
function Bullets.draw()
    love.graphics.setColor(1, 1, 1, 1)
    for _, b in ipairs(bullets) do
        if b and type(b.x) == "number" and type(b.y) == "number" then
            love.graphics.circle("fill", b.x, b.y, b.radius or 2)
        end
    end
end

-- Check collision with UFO
function Bullets.checkUFOCollision(UFO)
    if not UFO.isActive() or UFO.isLeaving() then return false end
    
    local bulletIndex = #bullets
    while bulletIndex >= 1 do
        local b = bullets[bulletIndex]
        if b and UFO.checkBulletCollision(b) then
            table.remove(bullets, bulletIndex)
            return true
        end
        bulletIndex = bulletIndex - 1
    end
    
    return false
end

-- Check collision with asteroids
function Bullets.checkAsteroidCollisions(Asteroids, onHit)
    local bulletIndex = #bullets
    while bulletIndex >= 1 do
        local b = bullets[bulletIndex]
        local bulletRemoved = false
        
        if not b then
            table.remove(bullets, bulletIndex)
            bulletRemoved = true
        else
            local asteroidIndex = Asteroids.checkBulletCollision(b)
            if asteroidIndex > 0 then
                table.remove(bullets, bulletIndex)
                bulletRemoved = true
                
                if onHit then onHit(asteroidIndex) end
            end
        end
        
        if not bulletRemoved then
            bulletIndex = bulletIndex - 1
        else 
            bulletIndex = math.min(bulletIndex, #bullets)
        end
    end
end

-- Get the bullet count
function Bullets.getCount()
    return #bullets
end

-- Get bullet array for external use
function Bullets.getBullets()
    return bullets
end

return Bullets