local Player = {}

local helpers = require("utils.helpers")

local ROTATION_SPEED = 4.5 
local THRUST = 375 
local FRICTION = 0.985 
local MAX_SPEED = 580 
local GUN_COOLDOWN = 0.2 
local INVULNERABILITY_TIME = 2.0 
local HYPERSPACE_COOLDOWN = 5.0 
local DEATH_ANIM_DURATION = 2.0 
local RESPAWN_ANIM_DURATION = 1.0 
local SEGMENT_MAX_SPEED = 150 
local SEGMENT_MAX_SPIN = 3.0 
local GAME_OVER_FADE_DURATION = 1.5 

local gameWidth, gameHeight
local sounds
local player = {}
local gunTimer = 0 
local invulnerableTimer = 0 
local hyperspaceTimer = 0

function Player.init(soundsTable, width, height)
    sounds = soundsTable
    gameWidth = width
    gameHeight = height
    Player.resetState()
end

function Player.resetState()
    player = {
        x = gameWidth / 2,
        y = gameHeight / 2,
        dx = 0,
        dy = 0,
        angle = -math.pi / 2, 
        radius = 10, 
        thrusting = false,
        visible = false, 
        alive = false, 
        isDying = false, 
        isRespawning = false, 
        deathAnimProgress = 0,
        respawnAnimProgress = 0,
        deathX = nil, 
        deathY = nil,
        deathAngle = nil,
        deathSegments = nil, 
        gameOverFadeTimer = nil, 
        shape = { 
            { x = 12, y = 0 },  
            { x = -8, y = -7 }, 
            { x = -8, y = 7 }   
        }
    }
    gunTimer = 0
    invulnerableTimer = 0 
    hyperspaceTimer = 0
end

function Player.update(dt)

    if not player or not player.alive or player.isDying or player.isRespawning then

        invulnerableTimer = math.max(0, invulnerableTimer - dt)
        hyperspaceTimer = math.max(0, hyperspaceTimer - dt)
        gunTimer = math.max(0, gunTimer - dt)
        return
    end

    gunTimer = math.max(0, gunTimer - dt)
    invulnerableTimer = math.max(0, invulnerableTimer - dt) 
    hyperspaceTimer = math.max(0, hyperspaceTimer - dt)

    if love.keyboard.isDown("left") then player.angle = player.angle - ROTATION_SPEED * dt end
    if love.keyboard.isDown("right") then player.angle = player.angle + ROTATION_SPEED * dt end

    player.thrusting = false
    if love.keyboard.isDown("up") then
        player.thrusting = true
        player.dx = player.dx + math.cos(player.angle) * THRUST * dt
        player.dy = player.dy + math.sin(player.angle) * THRUST * dt
    end

    player.dx = player.dx * FRICTION
    player.dy = player.dy * FRICTION

    local speedSq = player.dx^2 + player.dy^2
    if speedSq > MAX_SPEED^2 then
        local speed = math.sqrt(speedSq)
        player.dx = (player.dx / speed) * MAX_SPEED
        player.dy = (player.dy / speed) * MAX_SPEED
    end

    player.x = helpers.wrap(player.x + player.dx * dt, 0, gameWidth)
    player.y = helpers.wrap(player.y + player.dy * dt, 0, gameHeight)

    if love.keyboard.isDown("h") and hyperspaceTimer <= 0 then
        player.x = love.math.random(gameWidth)
        player.y = love.math.random(gameHeight)
        player.dx = 0 
        player.dy = 0
        hyperspaceTimer = HYPERSPACE_COOLDOWN
        invulnerableTimer = INVULNERABILITY_TIME 
        if sounds.hyperspace then sounds.hyperspace:play() end
    end
end

function Player.hit()

    if not player or not player.alive or player.isDying or player.isRespawning then
        if player and invulnerableTimer > 0 then
        end
        return 
    end


    if sounds.player_explode then sounds.player_explode:play() end

    local Particles = require("games.asteroids.particles") 
    Particles.createExplosion(player.x, player.y, 20)

    player.alive = false 
    player.thrusting = false 
    player.isDying = true 
    player.deathAnimProgress = 0
    player.visible = false 

    player.deathX = player.x
    player.deathY = player.y
    player.deathAngle = player.angle

    player.deathSegments = {}
    if player.shape and #player.shape >= 3 then
        for i = 1, #player.shape do
            local p1_idx = i
            local p2_idx = (i % #player.shape) + 1

            local p1_rel = { x = player.shape[p1_idx].x, y = player.shape[p1_idx].y }
            local p2_rel = { x = player.shape[p2_idx].x, y = player.shape[p2_idx].y }

            local angle = love.math.random() * 2 * math.pi
            local speed = love.math.random(SEGMENT_MAX_SPEED * 0.5, SEGMENT_MAX_SPEED)
            local vx = math.cos(angle) * speed
            local vy = math.sin(angle) * speed
            local spin = (love.math.random() - 0.5) * 2 * SEGMENT_MAX_SPIN

            table.insert(player.deathSegments, {
                p1 = p1_rel, p2 = p2_rel,
                x = 0, y = 0, angle = player.deathAngle,
                vx = vx, vy = vy, spin = spin,
                startX = 0, startY = 0, startAngle = 0 
            })
        end
    end
    return true 
end

function Player.updateDeathAnimation(dt, onComplete)
    if not player or not player.deathSegments then return end

    if player.isDying or player.gameOverFadeTimer then
        for _, seg in ipairs(player.deathSegments) do
            seg.x = seg.x + seg.vx * dt
            seg.y = seg.y + seg.vy * dt
            seg.angle = seg.angle + seg.spin * dt

            local worldX1 = (player.deathX or 0) + seg.x
            local worldY1 = (player.deathY or 0) + seg.y
            if worldX1 < 0 or worldX1 > gameWidth then seg.vx = seg.vx * 0.95 end
            if worldY1 < 0 or worldY1 > gameHeight then seg.vy = seg.vy * 0.95 end
            seg.vx = seg.vx * 0.995 
            seg.vy = seg.vy * 0.995
        end
    end

    if player.isDying then
        player.deathAnimProgress = math.min(1, player.deathAnimProgress + dt / DEATH_ANIM_DURATION)
        if player.deathAnimProgress >= 1 then
            player.isDying = false
            if onComplete then onComplete() end
        end
    elseif player.gameOverFadeTimer ~= nil then
        player.gameOverFadeTimer = player.gameOverFadeTimer + dt
        if player.gameOverFadeTimer > GAME_OVER_FADE_DURATION then
            player.deathSegments = nil
            player.gameOverFadeTimer = nil
        end
    end
end

function Player.startRespawnAnimation()
    local respawnX = gameWidth / 2
    local respawnY = gameHeight / 2
    player.x = respawnX
    player.y = respawnY
    player.dx = 0
    player.dy = 0
    player.angle = -math.pi / 2 
    player.visible = false 
    player.alive = false   
    player.isRespawning = true
    player.respawnAnimProgress = 0

    if player.deathSegments then
        for _, seg in ipairs(player.deathSegments) do

            local currentSegWorldX = (player.deathX or respawnX) + seg.x
            local currentSegWorldY = (player.deathY or respawnY) + seg.y

            seg.startX = currentSegWorldX - respawnX
            seg.startY = currentSegWorldY - respawnY
            seg.startAngle = seg.angle
        end
    else

    end

    if sounds.player_spawn then sounds.player_spawn:play() end
end

function Player.updateRespawnAnimation(dt)
    if not player or not player.isRespawning then return end

    player.respawnAnimProgress = math.min(1, player.respawnAnimProgress + dt / RESPAWN_ANIM_DURATION)
    local progress = helpers.smoothstep(0, 1, player.respawnAnimProgress)

    if player.deathSegments then
        for _, seg in ipairs(player.deathSegments) do
            local targetX, targetY, targetAngle = 0, 0, player.angle 
            seg.x = seg.startX + (targetX - seg.startX) * progress
            seg.y = seg.startY + (targetY - seg.startY) * progress
            local angleDiff = targetAngle - seg.startAngle
            angleDiff = (angleDiff + math.pi) % (2 * math.pi) - math.pi 
            seg.angle = seg.startAngle + angleDiff * progress
        end
    end

    if player.respawnAnimProgress >= 1 then
        player.isRespawning = false
        player.visible = true
        player.alive = true
        invulnerableTimer = INVULNERABILITY_TIME 
        player.deathSegments = nil 
    end
end

function Player.draw(offsets)
    if not player then return end

    local shouldDrawSegments = player.deathSegments and (player.isDying or player.isRespawning or player.gameOverFadeTimer ~= nil)

    if shouldDrawSegments then
        local drawX = player.isRespawning and player.x or (player.deathX or player.x)
        local drawY = player.isRespawning and player.y or (player.deathY or player.y)
        local alpha = 1
        if player.gameOverFadeTimer then
            alpha = math.max(0, 1 - (player.gameOverFadeTimer / GAME_OVER_FADE_DURATION))
        end

        love.graphics.push()
        love.graphics.translate(drawX, drawY)
        love.graphics.setColor(1, 1, 1, alpha)
        for _, seg in ipairs(player.deathSegments) do
            if seg and seg.p1 and seg.p2 then
                love.graphics.push()
                love.graphics.translate(seg.x, seg.y)
                love.graphics.rotate(seg.angle)
                love.graphics.line(seg.p1.x, seg.p1.y, seg.p2.x, seg.p2.y)
                love.graphics.pop()
            end
        end
        love.graphics.pop()
        love.graphics.setColor(1, 1, 1, 1)

    elseif player.visible then
        for _, offset in ipairs(offsets) do
            love.graphics.push()
            love.graphics.translate(offset[1] + player.x, offset[2] + player.y)

            if invulnerableTimer > 0 then
                if math.floor(invulnerableTimer * 10) % 2 == 0 then 
                    love.graphics.pop()
                    goto continue_draw_loop 
                end
            end

            love.graphics.rotate(player.angle)
            love.graphics.setColor(1, 1, 1, 1)
            local vertices = {}
            for _, p in ipairs(player.shape) do table.insert(vertices, p.x) table.insert(vertices, p.y) end
            if #vertices >= 6 then love.graphics.polygon("line", vertices) end

            if player.thrusting then
                love.graphics.setColor(1, 0.7, 0.2, 1)
                local flameLength = -13 - love.math.random(4)
                love.graphics.line(-8, -4, flameLength, 0, -8, 4)
                if love.math.random() > 0.5 then
                    love.graphics.setColor(1, 1, 0.5, 0.8)
                    local innerFlame = -10 - love.math.random(3)
                    love.graphics.line(-8, -2, innerFlame, 0, -8, 2)
                end
            end
            love.graphics.pop()
            ::continue_draw_loop::
        end
    end
end

function Player.getPosition() return player.x, player.y end
function Player.getAngle() return player.angle end
function Player.getVelocity() return player.dx, player.dy end
function Player.getRadius() return player.radius end
function Player.getShape() return player.shape end
function Player.isThrusting() return player.thrusting end

function Player.isFullyAlive()
    return player.alive and not player.isDying and not player.isRespawning
end

function Player.canBeHit()
    return player.alive and not player.isDying and not player.isRespawning
end

function Player.setVisible(visible) player.visible = visible end
function Player.setAlive(alive) player.alive = alive end

function Player.setInvulnerable(invulnerable)
    if invulnerable then
        invulnerableTimer = INVULNERABILITY_TIME
    else
        invulnerableTimer = 0
    end
end

function Player.getGunCooldown() return gunTimer end
function Player.setGunCooldown(time) gunTimer = time end 
function Player.resetGunCooldown() gunTimer = GUN_COOLDOWN end 

return Player