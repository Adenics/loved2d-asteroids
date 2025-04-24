-- Player module for Asteroids
local Player = {}

-- Import dependencies
local helpers = require("utils.helpers")

-- Constants
local ROTATION_SPEED = 4.5 -- Radians per second
local THRUST = 375 -- Acceleration units
local FRICTION = 0.985 -- Multiplier applied each frame to velocity
local MAX_SPEED = 580 -- Maximum velocity
local GUN_COOLDOWN = 0.2 -- Seconds between shots
local INVULNERABILITY_TIME = 2.0 -- Seconds after respawn
local HYPERSPACE_COOLDOWN = 5.0 -- Seconds between hyperspace jumps
local DEATH_ANIM_DURATION = 2.0 -- Seconds for death animation
local RESPAWN_ANIM_DURATION = 1.0 -- Seconds for respawn animation
local SEGMENT_MAX_SPEED = 150 -- Max speed for flying segments during death
local SEGMENT_MAX_SPIN = 3.0 -- Max rotation speed for flying segments
local GAME_OVER_FADE_DURATION = 1.5 -- Seconds for segments to fade out

-- Module variables
local gameWidth, gameHeight
local sounds
local player = {}
local gunTimer = 0
local invulnerableTimer = 0
local hyperspaceTimer = 0

-- Initialize module
function Player.init(soundsTable, width, height)
    sounds = soundsTable
    gameWidth = width
    gameHeight = height
    Player.resetState()
end

-- Reset player state
function Player.resetState()
    player = {
        x = gameWidth / 2,
        y = gameHeight / 2,
        dx = 0,
        dy = 0,
        angle = -math.pi / 2, -- Pointing up
        radius = 10, -- Collision radius
        thrusting = false,
        visible = false, -- Start invisible
        alive = false, -- Start not alive
        isDying = false,
        isRespawning = false,
        deathAnimProgress = 0,
        respawnAnimProgress = 0,
        deathX = nil,
        deathY = nil,
        deathAngle = nil,
        deathSegments = nil,
        gameOverFadeTimer = nil,
        shape = { -- Ship shape relative to center
            { x = 12, y = 0 }, -- Nose
            { x = -8, y = -7 }, -- Left wing back
            { x = -8, y = 7 } -- Right wing back
        }
    }
    gunTimer = 0
    invulnerableTimer = 0
    hyperspaceTimer = 0
    print("Player State Reset")
end

-- Update player logic
function Player.update(dt)
    -- Don't update if not alive or during animations
    if not player or not player.alive or player.isDying or player.isRespawning then return end
    
    -- Update timers
    gunTimer = math.max(0, gunTimer - dt)
    invulnerableTimer = math.max(0, invulnerableTimer - dt)
    hyperspaceTimer = math.max(0, hyperspaceTimer - dt)
    
    -- Rotation
    if love.keyboard.isDown("left") then player.angle = player.angle - ROTATION_SPEED * dt end
    if love.keyboard.isDown("right") then player.angle = player.angle + ROTATION_SPEED * dt end
    
    -- Thrusting
    player.thrusting = false
    if love.keyboard.isDown("up") then
        player.thrusting = true
        -- Apply thrust in the direction the ship is facing
        player.dx = player.dx + math.cos(player.angle) * THRUST * dt
        player.dy = player.dy + math.sin(player.angle) * THRUST * dt
    end
    
    -- Apply friction
    player.dx = player.dx * FRICTION
    player.dy = player.dy * FRICTION
    
    -- Clamp speed to maximum
    local speedSq = player.dx^2 + player.dy^2
    if speedSq > MAX_SPEED^2 then
        local speed = math.sqrt(speedSq)
        player.dx = (player.dx / speed) * MAX_SPEED
        player.dy = (player.dy / speed) * MAX_SPEED
    end
    
    -- Update position and wrap around screen edges
    player.x = helpers.wrap(player.x + player.dx * dt, 0, gameWidth)
    player.y = helpers.wrap(player.y + player.dy * dt, 0, gameHeight)
    
    -- Hyperspace
    if love.keyboard.isDown("h") and hyperspaceTimer <= 0 then
        player.x = love.math.random(gameWidth)
        player.y = love.math.random(gameHeight)
        player.dx = 0
        player.dy = 0
        hyperspaceTimer = HYPERSPACE_COOLDOWN
        invulnerableTimer = 1.0 -- Brief invulnerability after jump
        if sounds.hyperspace then sounds.hyperspace:play() end
    end
end

-- Handle player hit
function Player.hit()
    -- Ignore hits if already dying, respawning, or invulnerable
    if not player or not player.alive or player.isDying or player.isRespawning or invulnerableTimer > 0 then return end
    
    -- Play explosion sound
    if sounds.player_explode then sounds.player_explode:play() end
    
    -- Create particles at player position
    local Particles = require("games.asteroids.particles")
    Particles.createExplosion(player.x, player.y, 20)
    
    player.alive = false -- No longer controllable
    player.thrusting = false -- Stop thrusting visually
    player.isDying = true -- Start the death animation
    player.deathAnimProgress = 0
    player.visible = false -- Hide the main ship
    
    -- Store death location and angle
    player.deathX = player.x
    player.deathY = player.y
    player.deathAngle = player.angle
    
    -- Create segment data for death animation
    player.deathSegments = {}
    if player.shape and #player.shape >= 3 then
        for i = 1, #player.shape do
            local p1_idx = i
            local p2_idx = (i % #player.shape) + 1
            
            -- Get segment endpoints
            local p1_rel = { x = player.shape[p1_idx].x, y = player.shape[p1_idx].y }
            local p2_rel = { x = player.shape[p2_idx].x, y = player.shape[p2_idx].y }
            
            -- Random velocity and spin
            local angle = love.math.random() * 2 * math.pi
            local speed = love.math.random(SEGMENT_MAX_SPEED * 0.5, SEGMENT_MAX_SPEED)
            local vx = math.cos(angle) * speed
            local vy = math.sin(angle) * speed
            local spin = (love.math.random() - 0.5) * 2 * SEGMENT_MAX_SPIN
            
            table.insert(player.deathSegments, {
                p1 = p1_rel,
                p2 = p2_rel,
                x = 0, -- Initial offset from death point
                y = 0,
                angle = player.deathAngle,
                vx = vx,
                vy = vy,
                spin = spin,
                startX = 0, -- Will be set before respawn
                startY = 0,
                startAngle = 0
            })
        end
    end
    
    return true -- Return hit confirmed
end

-- Update death animation
function Player.updateDeathAnimation(dt, onComplete)
    -- Allow updates if segments exist
    if not player or not player.deathSegments then return end
    
    -- Update segment physics
    if player.isDying or player.gameOverFadeTimer then
        for i, seg in ipairs(player.deathSegments) do
            -- Update position
            seg.x = seg.x + seg.vx * dt
            seg.y = seg.y + seg.vy * dt
            -- Update rotation
            seg.angle = seg.angle + seg.spin * dt
            
            -- Boundary collision check (bounce)
            local cosA = math.cos(seg.angle)
            local sinA = math.sin(seg.angle)
            local deathX = player.deathX or 0
            local deathY = player.deathY or 0
            local worldX1 = deathX + seg.x + cosA * seg.p1.x - sinA * seg.p1.y
            local worldY1 = deathY + seg.y + sinA * seg.p1.x + cosA * seg.p1.y
            local worldX2 = deathX + seg.x + cosA * seg.p2.x - sinA * seg.p2.y
            local worldY2 = deathY + seg.y + sinA * seg.p2.x + cosA * seg.p2.y
            
            local bounced = false
            if (worldX1 < 0 and seg.vx < 0) or (worldX2 < 0 and seg.vx < 0) or 
               (worldX1 > gameWidth and seg.vx > 0) or (worldX2 > gameWidth and seg.vx > 0) then
                seg.vx = -seg.vx * 0.8
                seg.x = seg.x + seg.vx * dt
                bounced = true
            end
            if (worldY1 < 0 and seg.vy < 0) or (worldY2 < 0 and seg.vy < 0) or 
               (worldY1 > gameHeight and seg.vy > 0) or (worldY2 > gameHeight and seg.vy > 0) then
                seg.vy = -seg.vy * 0.8
                seg.y = seg.y + seg.vy * dt
                bounced = true
            end
            if bounced then
                seg.spin = seg.spin + (love.math.random() - 0.5) * 1.0
                seg.spin = math.max(-SEGMENT_MAX_SPIN, math.min(SEGMENT_MAX_SPIN, seg.spin))
            end
            seg.vx = seg.vx * 0.995
            seg.vy = seg.vy * 0.995
        end
    end
    
    -- Update death animation progress
    if player.isDying then
        player.deathAnimProgress = math.min(1, player.deathAnimProgress + dt / DEATH_ANIM_DURATION)
        
        -- Check if death animation finished
        if player.deathAnimProgress >= 1 then
            player.isDying = false
            print("Death Animation Finished.")
            
            -- Call the completion callback
            if onComplete then onComplete() end
        end
    -- Update game over fade timer
    elseif player.gameOverFadeTimer ~= nil then
        player.gameOverFadeTimer = player.gameOverFadeTimer + dt
        
        -- Remove segments after fade is complete
        if player.gameOverFadeTimer > GAME_OVER_FADE_DURATION then
            print("Game over fade complete. Removing segments.")
            player.deathSegments = nil
            player.gameOverFadeTimer = nil
        end
    end
end

-- Start respawn animation
function Player.startRespawnAnimation()
    print("Starting Respawn Animation...")
    -- Set target position/angle for the new ship
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
    
    -- Store starting positions relative to the respawn point
    if player.deathSegments then
        if type(player.deathX) ~= "number" or type(player.deathY) ~= "number" then
            print("ERROR: Invalid death coordinates during startRespawnAnimation.")
            for i, seg in ipairs(player.deathSegments) do
                seg.startX = seg.x
                seg.startY = seg.y
                seg.startAngle = seg.angle
            end
        else
            for i, seg in ipairs(player.deathSegments) do
                local worldX = player.deathX + seg.x
                local worldY = player.deathY + seg.y
                seg.startX = worldX - respawnX
                seg.startY = worldY - respawnY
                seg.startAngle = seg.angle
            end
        end
    else
        print("Warning: No death segments found during startRespawnAnimation.")
    end
    
    -- Play spawn sound
    if sounds.player_spawn then sounds.player_spawn:play() end
end

-- Update respawn animation
function Player.updateRespawnAnimation(dt)
    if not player or not player.isRespawning or not player.deathSegments then return end
    
    player.respawnAnimProgress = math.min(1, player.respawnAnimProgress + dt / RESPAWN_ANIM_DURATION)
    local progress = helpers.smoothstep(0, 1, player.respawnAnimProgress)
    
    -- Update each segment
    for i, seg in ipairs(player.deathSegments) do
        local targetX = 0
        local targetY = 0
        local targetAngle = player.angle
        
        -- Interpolate position
        seg.x = seg.startX + (targetX - seg.startX) * progress
        seg.y = seg.startY + (targetY - seg.startY) * progress
        
        -- Interpolate angle
        local angleDiff = targetAngle - seg.startAngle
        angleDiff = (angleDiff + math.pi) % (2 * math.pi) - math.pi
        seg.angle = seg.startAngle + angleDiff * progress
    end
    
    -- Check if animation finished
    if player.respawnAnimProgress >= 1 then
        print("Respawn Animation Finished.")
        player.isRespawning = false
        player.visible = true
        player.alive = true
        invulnerableTimer = INVULNERABILITY_TIME
        player.deathSegments = nil
    end
end

-- Draw player
function Player.draw(offsets)
    if not player then return end
    
    -- Check if drawing segments or normal ship
    local shouldDrawSegments = player.deathSegments and (player.isDying or player.isRespawning or player.gameOverFadeTimer ~= nil)
    
    if shouldDrawSegments then
        -- Draw segments (just once, not with offsets)
        local drawX, drawY
        
        if player.isRespawning then
            drawX, drawY = player.x, player.y
        else -- Dying or Game Over
            if type(player.deathX) ~= "number" or type(player.deathY) ~= "number" then
                print("Warning: Invalid death coordinates during draw")
                drawX, drawY = 0, 0
            else
                drawX, drawY = player.deathX, player.deathY
            end
        end
        
        -- Calculate alpha for game over fade
        local alpha = 1
        if player.gameOverFadeTimer then
            alpha = math.max(0, 1 - (player.gameOverFadeTimer / GAME_OVER_FADE_DURATION))
        end
        
        love.graphics.push()
        love.graphics.translate(drawX, drawY)
        love.graphics.setColor(1, 1, 1, alpha)
        
        for i, seg in ipairs(player.deathSegments) do
            if seg and type(seg.x) == "number" and type(seg.y) == "number" and type(seg.angle) == "number" and seg.p1 and seg.p2 then
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
        -- Draw normal ship with wrapping
        for _, offset in ipairs(offsets) do
            love.graphics.push()
            love.graphics.translate(offset[1] + player.x, offset[2] + player.y)
            
            -- Handle invulnerability blink
            if invulnerableTimer > 0 then
                if math.floor(invulnerableTimer * 10) % 2 == 0 then
                    love.graphics.pop()
                    goto continue -- Skip drawing this frame for blink effect
                end
            end
            
            love.graphics.rotate(player.angle)
            
            -- Draw ship outline
            love.graphics.setColor(1, 1, 1, 1)
            local vertices = {}
            for _, p in ipairs(player.shape) do 
                table.insert(vertices, p.x)
                table.insert(vertices, p.y) 
            end
            if #vertices >= 6 then love.graphics.polygon("line", vertices) end
            
            -- Draw thrust flame
            if player.thrusting then
                love.graphics.setColor(1, 0.7, 0.2, 1)
                local mainFlameLength = -13 - love.math.random(4)
                love.graphics.line(-8, -4, mainFlameLength, 0, -8, 4)
                
                if love.math.random() > 0.5 then
                    love.graphics.setColor(1, 1, 0.5, 0.8)
                    local innerFlameLength = -10 - love.math.random(3)
                    love.graphics.line(-8, -2, innerFlameLength, 0, -8, 2)
                end
            end
            
            love.graphics.pop()
            
            ::continue::
        end
    end
end

-- Getters and setters
function Player.getPosition()
    return player.x, player.y
end

function Player.getAngle()
    return player.angle
end

function Player.getVelocity()
    return player.dx, player.dy
end

function Player.getRadius()
    return player.radius
end

function Player.getShape()
    return player.shape
end

function Player.isThrusting()
    return player.thrusting
end

function Player.isFullyAlive()
    return player.alive and not player.isDying and not player.isRespawning
end

function Player.canBeHit()
    return player.alive and not player.isDying and not player.isRespawning and invulnerableTimer <= 0
end

function Player.setVisible(visible)
    player.visible = visible
end

function Player.setAlive(alive)
    player.alive = alive
end

function Player.setInvulnerable(invulnerable)
    if invulnerable then
        invulnerableTimer = INVULNERABILITY_TIME
    else
        invulnerableTimer = 0
    end
end

function Player.getGunCooldown()
    return gunTimer
end

function Player.setGunCooldown(time)
    gunTimer = time
end

function Player.resetGunCooldown()
    gunTimer = GUN_COOLDOWN
end

return Player