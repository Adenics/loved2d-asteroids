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
    print("Bullets.init: gameWidth=" .. (gameWidth or "nil") .. ", gameHeight=" .. (gameHeight or "nil"))
end

-- Clear all bullets
function Bullets.clear()
    bullets = {}
end

-- Fire a bullet
-- Changed to accept the player object directly to ensure freshest data
function Bullets.fire(player_object)
    -- Safety check: ensure player_object is valid and alive
    -- Note: Player.isFullyAlive() is a function of the Player module, not a method of a player instance here.
    -- We assume player_object refers to the Player module itself.
    -- The original call in game.lua was Player.isFullyAlive(), which is correct.
    -- For this new structure, we'd need player_object to have these methods or be the Player module.
    -- Assuming player_object is the Player module:
    if not player_object or not player_object.isFullyAlive() then
        print("Bullets.fire: Attempted to fire when player object is invalid or not fully alive.")
        return false
    end

    -- Check if we can fire (max bullets)
    if #bullets >= MAX_BULLETS then return false end

    local pX, pY = player_object.getPosition()
    local pAngle = player_object.getAngle()
    local pDX, pDY = player_object.getVelocity()

    -- Debug: Print player state at the moment of firing
    print(string.format("Bullets.fire: Player State - X: %.2f, Y: %.2f, Angle: %.2f, VelX: %.2f, VelY: %.2f",
                        pX or -999, pY or -999, pAngle or -999, pDX or -999, pDY or -999))

    -- Ensure player data is valid before proceeding
    if type(pX) ~= "number" or type(pY) ~= "number" or type(pAngle) ~= "number" then
        print("Bullets.fire: ERROR - Player position or angle is not a number!")
        return false
    end

    -- Calculate bullet starting position (tip of the ship)
    local noseX = 12 -- Assuming ship shape nose is at (12, 0) in local player coordinates
    local noseY = 0
    local cosA = math.cos(pAngle)
    local sinA = math.sin(pAngle)

    local startX = pX + cosA * noseX - sinA * noseY
    local startY = pY + sinA * noseX + cosA * noseY

    -- Create bullet
    local newBullet = {
        x = startX,
        y = startY,
        dx = cosA * BULLET_SPEED + (pDX or 0), -- Add player's velocity to bullet
        dy = sinA * BULLET_SPEED + (pDY or 0), -- Add player's velocity to bullet
        lifetime = BULLET_LIFETIME,
        radius = 2
    }
    table.insert(bullets, newBullet)

    -- Debug: Print bullet spawn details
    print(string.format("Bullets.fire: Spawned Bullet at X: %.2f, Y: %.2f, DX: %.2f, DY: %.2f",
                        newBullet.x, newBullet.y, newBullet.dx, newBullet.dy))

    -- Play sound
    if sounds and sounds.shoot then
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
            bulletIndex = math.min(bulletIndex, #bullets) -- Ensure index is valid after removal
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