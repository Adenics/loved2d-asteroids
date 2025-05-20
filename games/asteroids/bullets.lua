local Bullets = {}

local helpers = require("utils.helpers")

local BULLET_SPEED = 450
local BULLET_LIFETIME = 1.2 
local MAX_BULLETS = 4 

local gameWidth, gameHeight
local sounds
local bullets = {}

function Bullets.init(soundsTable, width, height)
    sounds = soundsTable
    gameWidth = width
    gameHeight = height
    bullets = {}
    print("Bullets.init: gameWidth=" .. (gameWidth or "nil") .. ", gameHeight=" .. (gameHeight or "nil"))
end

function Bullets.clear()
    bullets = {}
end

function Bullets.fire(player_object)

    if not player_object or not player_object.isFullyAlive() then
        print("Bullets.fire: Attempted to fire when player object is invalid or not fully alive.")
        return false
    end

    if #bullets >= MAX_BULLETS then return false end

    local pX, pY = player_object.getPosition()
    local pAngle = player_object.getAngle()
    local pDX, pDY = player_object.getVelocity()

    print(string.format("Bullets.fire: Player State - X: %.2f, Y: %.2f, Angle: %.2f, VelX: %.2f, VelY: %.2f",
                        pX or -999, pY or -999, pAngle or -999, pDX or -999, pDY or -999))

    if type(pX) ~= "number" or type(pY) ~= "number" or type(pAngle) ~= "number" then
        print("Bullets.fire: ERROR - Player position or angle is not a number!")
        return false
    end

    local noseX = 12 
    local noseY = 0
    local cosA = math.cos(pAngle)
    local sinA = math.sin(pAngle)

    local startX = pX + cosA * noseX - sinA * noseY
    local startY = pY + sinA * noseX + cosA * noseY

    local newBullet = {
        x = startX,
        y = startY,
        dx = cosA * BULLET_SPEED + (pDX or 0), 
        dy = sinA * BULLET_SPEED + (pDY or 0), 
        lifetime = BULLET_LIFETIME,
        radius = 2
    }
    table.insert(bullets, newBullet)

    print(string.format("Bullets.fire: Spawned Bullet at X: %.2f, Y: %.2f, DX: %.2f, DY: %.2f",
                        newBullet.x, newBullet.y, newBullet.dx, newBullet.dy))

    if sounds and sounds.shoot then
        local s = sounds.shoot:clone()
        if s then s:play() end
    end

    return true
end

function Bullets.update(dt)
    local i = #bullets
    while i >= 1 do
        local b = bullets[i]
        local removeBullet = false

        if not b then
            removeBullet = true
        else

            b.x = helpers.wrap(b.x + b.dx * dt, 0, gameWidth)
            b.y = helpers.wrap(b.y + b.dy * dt, 0, gameHeight)

            b.lifetime = b.lifetime - dt

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

function Bullets.draw()
    love.graphics.setColor(1, 1, 1, 1)
    for _, b in ipairs(bullets) do
        if b and type(b.x) == "number" and type(b.y) == "number" then
            love.graphics.circle("fill", b.x, b.y, b.radius or 2)
        end
    end
end

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

function Bullets.getCount()
    return #bullets
end

function Bullets.getBullets()
    return bullets
end

return Bullets