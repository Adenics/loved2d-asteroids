local UFO = {}

local helpers = require("utils.helpers")

local UFO_SPEED = 110 
local UFO_FIRE_RATE = 1.4 
local UFO_BULLET_SPEED = 270
local UFO_POINTS = 200
local UFO_MIN_LIFETIME = 8 
local UFO_MAX_LIFETIME = 15 
local UFO_DIRECTION_CHANGE_INTERVAL = 2.0 
local UFO_LEAVING_SPEED_MULTIPLIER = 3.0 

local gameWidth, gameHeight
local sounds
local ufo = nil
local ufoBullets = {}
local ufoActive = false
local ufoFireTimer = 0
local ufoDirectionChangeTimer = 0

function UFO.init(soundsTable, width, height)
    sounds = soundsTable
    gameWidth = width
    gameHeight = height
    UFO.clear()
end

function UFO.clear()
    ufo = nil
    ufoBullets = {}
    ufoActive = false
    ufoFireTimer = 0
    ufoDirectionChangeTimer = 0
end

function UFO.spawn()
    if ufoActive then return false end

    local side = love.math.random(2)
    local x, y, dx, dy
    local buffer = 20 

    y = love.math.random(gameHeight * 0.2, gameHeight * 0.8)
    if side == 1 then 
        x, dx = -buffer, UFO_SPEED
    else 
        x, dx = gameWidth + buffer, -UFO_SPEED
    end
    dy = 0 

    ufo = {
        x = x, y = y, dx = dx, dy = dy,
        radius = 15,
        shape = {
            -15, 0, -10, -5, 10, -5, 15, 0, 10, 5, -10, 5, -15, 0,
            -10, -5, -5, -10, 5, -10, 10, -5,
            5, -10, 0, -13, -5, -10
        },
        visible = true, leaving = false,
        lifetime = love.math.random(UFO_MIN_LIFETIME, UFO_MAX_LIFETIME)
    }

    ufoActive = true
    ufoFireTimer = UFO_FIRE_RATE / 2
    ufoDirectionChangeTimer = UFO_DIRECTION_CHANGE_INTERVAL * love.math.random(0.5, 1.0)

    if sounds.ufo_spawn then sounds.ufo_spawn:play() end
    if sounds.ufo_flying then
        sounds.ufo_flying:setLooping(true)
        sounds.ufo_flying:play()
    end
    print("UFO Spawned. Lifetime: " .. ufo.lifetime)
    return true
end

function UFO.update(dt, PlayerObject)
    if not ufoActive or not ufo then return end

    local playerIsEffectivelyGone = false
    if PlayerObject then 
        if not PlayerObject.isFullyAlive() then
            playerIsEffectivelyGone = true
        end
    else 
        playerIsEffectivelyGone = true
    end

    if playerIsEffectivelyGone and not ufo.leaving then
        print("UFO: Player is no longer active or game is over. UFO initiating leave sequence.")
        ufo.leaving = true

        if ufo.x < gameWidth / 2 then
            ufo.dx = -UFO_SPEED 
        else
            ufo.dx = UFO_SPEED  
        end
        ufo.dy = 0 
        if sounds.ufo_flying and sounds.ufo_flying:isPlaying() then
            sounds.ufo_flying:stop()
        end
    end

    if ufo.leaving then
        local despawn_buffer = ufo.radius + 10 
        local leave_dx_direction = ufo.dx >= 0 and 1 or -1 

        if ufo.dx == 0 then
            leave_dx_direction = (ufo.x > gameWidth / 2) and -1 or 1
             print("UFO: dx was 0 while leaving, re-established direction: " .. leave_dx_direction)
        end

        ufo.dx = leave_dx_direction * UFO_SPEED * UFO_LEAVING_SPEED_MULTIPLIER
        ufo.dy = 0 
        ufo.x = ufo.x + ufo.dx * dt
        ufo.y = ufo.y + ufo.dy * dt 

        if (ufo.dx > 0 and ufo.x > gameWidth + despawn_buffer) or
           (ufo.dx < 0 and ufo.x < -despawn_buffer) then
            print("UFO has left the screen.")
            UFO.destroy(false) 
        end
        return 
    end

    ufo.lifetime = ufo.lifetime - dt
    if ufo.lifetime <= 0 then
        print("UFO lifetime expired. Setting to leave.")
        ufo.leaving = true
        if sounds.ufo_flying and sounds.ufo_flying:isPlaying() then
            sounds.ufo_flying:stop()
        end

        if ufo.dx == 0 then 
            ufo.dx = (ufo.x < gameWidth / 2) and -UFO_SPEED or UFO_SPEED
        end
        return 
    end

    ufo.x = ufo.x + ufo.dx * dt
    ufo.y = ufo.y + ufo.dy * dt

    ufoDirectionChangeTimer = ufoDirectionChangeTimer - dt
    if ufoDirectionChangeTimer <= 0 then
        local changeType = love.math.random(3)
        if changeType == 1 then
            ufo.dy = (love.math.random(3) - 2) * UFO_SPEED * love.math.random(0.4, 0.9)
        elseif changeType == 2 and ufo.dy ~= 0 then
            ufo.dx = (love.math.random(3) - 2) * UFO_SPEED * love.math.random(0.4, 0.9)
        elseif changeType == 3 and PlayerObject and PlayerObject.isFullyAlive() then
            local _, playerY = PlayerObject.getPosition()
            local targetY = playerY + love.math.random(-gameHeight * 0.25, gameHeight * 0.25)
            targetY = math.max(ufo.radius, math.min(gameHeight - ufo.radius, targetY))
            ufo.dy = (targetY > ufo.y and 1 or -1) * UFO_SPEED * love.math.random(0.3, 0.7)
        end

        if ufo.dx == 0 then ufo.dx = (ufo.x < gameWidth / 2) and UFO_SPEED * 0.5 or -UFO_SPEED * 0.5 end
        if ufo.dx ~= 0 then ufo.dx = (ufo.dx > 0 and 1 or -1) * UFO_SPEED end
        ufoDirectionChangeTimer = UFO_DIRECTION_CHANGE_INTERVAL * love.math.random(0.4, 1.0)
    end

    if PlayerObject and PlayerObject.isFullyAlive() and not ufo.leaving then
        ufoFireTimer = ufoFireTimer - dt
        if ufoFireTimer <= 0 then
            UFO.fireBullet(PlayerObject)
            ufoFireTimer = UFO_FIRE_RATE * love.math.random(0.8, 1.2)
        end
    end

    local onScreenBuffer = ufo.radius
    if not ufo.leaving and ufo.x > onScreenBuffer and ufo.x < gameWidth - onScreenBuffer then
        ufo.y = helpers.wrap(ufo.y, 0, gameHeight)
    else
        ufo.y = math.max(ufo.radius, math.min(gameHeight - ufo.radius, ufo.y)) 
    end

    if not ufo.leaving then
        if (ufo.dx > 0 and ufo.x >= gameWidth - ufo.radius) or (ufo.dx < 0 and ufo.x <= ufo.radius) then
            print("UFO reached edge naturally. Setting to leave.")
            ufo.leaving = true
            if sounds.ufo_flying and sounds.ufo_flying:isPlaying() then
                sounds.ufo_flying:stop()
            end
        end
    end

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

function UFO.draw()
    if not ufoActive or not ufo or not ufo.visible then return end
    if type(ufo.x) ~= "number" or type(ufo.y) ~= "number" or not ufo.shape then return end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.push()
    love.graphics.translate(ufo.x, ufo.y)
    if #ufo.shape >= 6 then love.graphics.polygon("line", ufo.shape) end
    love.graphics.pop()

    if not ufo.leaving then
        love.graphics.setColor(1, 0.3, 0.3, 1)
        for _, b in ipairs(ufoBullets) do
            if b and type(b.x) == "number" and type(b.y) == "number" then
                love.graphics.circle("fill", b.x, b.y, b.radius or 3)
            end
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function UFO.fireBullet(PlayerObject)
    if not ufo or not PlayerObject or not PlayerObject.isFullyAlive() or ufo.leaving then
        return false
    end
    local playerX, playerY = PlayerObject.getPosition()
    local angleToPlayer = math.atan2(playerY - ufo.y, playerX - ufo.x)
    angleToPlayer = angleToPlayer + (love.math.random() - 0.5) * 0.3

    table.insert(ufoBullets, {
        x = ufo.x, y = ufo.y,
        dx = math.cos(angleToPlayer) * UFO_BULLET_SPEED,
        dy = math.sin(angleToPlayer) * UFO_BULLET_SPEED,
        lifetime = 2.0, radius = 3
    })
    if sounds.ufo_shoot then
        local s = sounds.ufo_shoot:clone()
        if s then s:play() end
    end
    return true
end

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

    if sounds.ufo_flying and sounds.ufo_flying:isPlaying() then
        sounds.ufo_flying:stop()
    end

    print("Destroying UFO. Active: false. Hit by player: " .. tostring(hitByPlayer))
    ufo = nil
    ufoActive = false
    ufoBullets = {}
    return true
end

function UFO.checkBulletCollision(bullet)
    if not ufoActive or not ufo or ufo.leaving then return false end
    if not bullet or type(bullet.x) ~= "number" or type(bullet.y) ~= "number" then return false end
    local dx_val = bullet.x - ufo.x
    local dy_val = bullet.y - ufo.y
    local distSq = dx_val * dx_val + dy_val * dy_val
    local radiusSum = (bullet.radius or 2) + ufo.radius
    return distSq < (radiusSum * radiusSum)
end

function UFO.checkPlayerCollision(PlayerObject)
    if not ufoActive or not ufo or ufo.leaving or not PlayerObject.canBeHit() then
        return false
    end
    local playerX, playerY = PlayerObject.getPosition()
    local playerRadius = PlayerObject.getRadius()

    local dx_val = playerX - ufo.x
    local dy_val = playerY - ufo.y
    local distSq = dx_val * dx_val + dy_val * dy_val
    local radiusSum = playerRadius + ufo.radius
    if distSq < (radiusSum * radiusSum) then
        print("Collision: Player ship vs UFO body")
        return true
    end

    for i = #ufoBullets, 1, -1 do
        local b = ufoBullets[i]
        if b then
            dx_val = playerX - b.x
            dy_val = playerY - b.y
            distSq = dx_val * dx_val + dy_val * dy_val
            radiusSum = playerRadius + (b.radius or 3)
            if distSq < (radiusSum * radiusSum) then
                print("Collision: Player ship vs UFO bullet")
                table.remove(ufoBullets, i)
                return true
            end
        end
    end
    return false
end

function UFO.isActive() return ufoActive end
function UFO.isLeaving() return ufo and ufo.leaving end
function UFO.getPoints() return UFO_POINTS end

return UFO