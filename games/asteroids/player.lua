-- Player module for Asteroids
local Player = {}

-- Import dependencies
local helpers = require("utils.helpers")

-- Constants
local ROTATION_SPEED = 4.5 -- Radians per second
local THRUST = 375 -- Acceleration units
local FRICTION = 0.985 -- Multiplier applied each frame to velocity
local MAX_SPEED = 580 -- Maximum velocity
local GUN_COOLDOWN = 0.2 -- Seconds between shots (handled by Player module)
local INVULNERABILITY_TIME = 2.0 -- Seconds after respawn or hyperspace (visual only now)
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
local gunTimer = 0 -- Timer for player's own gun cooldown
local invulnerableTimer = 0 -- Timer for visual invulnerability (blinking)
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
        radius = 10, -- Collision radius (approximate)
        thrusting = false,
        visible = false, -- Start invisible until first spawn/respawn animation completes
        alive = false, -- Start not alive
        isDying = false, -- True during death animation
        isRespawning = false, -- True during respawn animation
        deathAnimProgress = 0,
        respawnAnimProgress = 0,
        deathX = nil, -- Stores position at point of death for animation
        deathY = nil,
        deathAngle = nil,
        deathSegments = nil, -- Stores ship segments for explosion animation
        gameOverFadeTimer = nil, -- Timer for fading out segments on game over screen
        shape = { -- Ship shape vertices relative to player's center (x, y)
            { x = 12, y = 0 },  -- Nose
            { x = -8, y = -7 }, -- Left wing back
            { x = -8, y = 7 }   -- Right wing back
        }
    }
    gunTimer = 0
    invulnerableTimer = 0 -- Reset visual invulnerability timer
    hyperspaceTimer = 0
    print("Player State Reset")
end

-- Update player logic
function Player.update(dt)
    -- Don't update controllable actions if not alive or during animations
    if not player or not player.alive or player.isDying or player.isRespawning then
        -- Still update timers even if not controllable
        invulnerableTimer = math.max(0, invulnerableTimer - dt)
        hyperspaceTimer = math.max(0, hyperspaceTimer - dt)
        gunTimer = math.max(0, gunTimer - dt)
        return
    end

    -- Update timers
    gunTimer = math.max(0, gunTimer - dt)
    invulnerableTimer = math.max(0, invulnerableTimer - dt) -- This timer now only controls blinking
    hyperspaceTimer = math.max(0, hyperspaceTimer - dt)

    -- Rotation
    if love.keyboard.isDown("left") then player.angle = player.angle - ROTATION_SPEED * dt end
    if love.keyboard.isDown("right") then player.angle = player.angle + ROTATION_SPEED * dt end

    -- Thrusting
    player.thrusting = false
    if love.keyboard.isDown("up") then
        player.thrusting = true
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
        player.dx = 0 -- Stop movement after hyperspace
        player.dy = 0
        hyperspaceTimer = HYPERSPACE_COOLDOWN
        invulnerableTimer = INVULNERABILITY_TIME -- Grant visual invulnerability after jump
        if sounds.hyperspace then sounds.hyperspace:play() end
        print("Player hyperspaced. Visual invulnerability granted.")
    end
end

-- Handle player hit
function Player.hit()
    -- MODIFIED: Removed 'invulnerableTimer > 0' check.
    -- Player can now be hit even if the invulnerableTimer is active (i.e., blinking).
    -- Hits are ignored only if not alive, already dying, or currently respawning.
    if not player or not player.alive or player.isDying or player.isRespawning then
        if player and invulnerableTimer > 0 then
             print("Player.hit: Hit occurred during visual invulnerability, but damage is applied.")
        end
        return -- No effect if not in a hittable state
    end

    print("Player.hit: Player has been hit!")
    -- Play explosion sound
    if sounds.player_explode then sounds.player_explode:play() end

    -- Create particles at player position
    local Particles = require("games.asteroids.particles") -- Local require to avoid load-time circular deps
    Particles.createExplosion(player.x, player.y, 20)

    player.alive = false -- No longer controllable
    player.thrusting = false -- Stop thrusting visually and audibly
    player.isDying = true -- Start the death animation sequence
    player.deathAnimProgress = 0
    player.visible = false -- Hide the main ship sprite during death animation

    -- Store death location and angle for the segment animation
    player.deathX = player.x
    player.deathY = player.y
    player.deathAngle = player.angle

    -- Create segment data for death animation (ship breaking apart)
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
                startX = 0, startY = 0, startAngle = 0 -- For respawn animation
            })
        end
    end
    return true -- Hit was processed
end

-- Update death animation (ship pieces flying apart)
function Player.updateDeathAnimation(dt, onComplete)
    if not player or not player.deathSegments then return end

    if player.isDying or player.gameOverFadeTimer then
        for _, seg in ipairs(player.deathSegments) do
            seg.x = seg.x + seg.vx * dt
            seg.y = seg.y + seg.vy * dt
            seg.angle = seg.angle + seg.spin * dt
            -- Simplified boundary interaction: slow down velocity, no bounce
            local worldX1 = (player.deathX or 0) + seg.x
            local worldY1 = (player.deathY or 0) + seg.y
            if worldX1 < 0 or worldX1 > gameWidth then seg.vx = seg.vx * 0.95 end
            if worldY1 < 0 or worldY1 > gameHeight then seg.vy = seg.vy * 0.95 end
            seg.vx = seg.vx * 0.995 -- Air resistance
            seg.vy = seg.vy * 0.995
        end
    end

    if player.isDying then
        player.deathAnimProgress = math.min(1, player.deathAnimProgress + dt / DEATH_ANIM_DURATION)
        if player.deathAnimProgress >= 1 then
            player.isDying = false
            print("Death Animation Finished.")
            if onComplete then onComplete() end
        end
    elseif player.gameOverFadeTimer ~= nil then
        player.gameOverFadeTimer = player.gameOverFadeTimer + dt
        if player.gameOverFadeTimer > GAME_OVER_FADE_DURATION then
            print("Game over segment fade complete.")
            player.deathSegments = nil
            player.gameOverFadeTimer = nil
        end
    end
end

-- Start respawn animation (ship pieces flying back together)
function Player.startRespawnAnimation()
    print("Starting Respawn Animation...")
    local respawnX = gameWidth / 2
    local respawnY = gameHeight / 2
    player.x = respawnX
    player.y = respawnY
    player.dx = 0
    player.dy = 0
    player.angle = -math.pi / 2 -- Default pointing up
    player.visible = false -- Remains invisible until animation completes
    player.alive = false   -- Not truly alive until animation completes
    player.isRespawning = true
    player.respawnAnimProgress = 0

    if player.deathSegments then
        for _, seg in ipairs(player.deathSegments) do
            -- Calculate current world position of segment relative to death point
            local currentSegWorldX = (player.deathX or respawnX) + seg.x
            local currentSegWorldY = (player.deathY or respawnY) + seg.y
            -- Store start positions relative to the *new* respawn center for interpolation
            seg.startX = currentSegWorldX - respawnX
            seg.startY = currentSegWorldY - respawnY
            seg.startAngle = seg.angle
        end
    else
        print("Warning: No death segments for respawn animation.")
        -- If no segments, player will just pop in after respawn duration
    end

    if sounds.player_spawn then sounds.player_spawn:play() end
end

-- Update respawn animation
function Player.updateRespawnAnimation(dt)
    if not player or not player.isRespawning then return end

    player.respawnAnimProgress = math.min(1, player.respawnAnimProgress + dt / RESPAWN_ANIM_DURATION)
    local progress = helpers.smoothstep(0, 1, player.respawnAnimProgress)

    if player.deathSegments then
        for _, seg in ipairs(player.deathSegments) do
            local targetX, targetY, targetAngle = 0, 0, player.angle -- Target is center of new ship
            seg.x = seg.startX + (targetX - seg.startX) * progress
            seg.y = seg.startY + (targetY - seg.startY) * progress
            local angleDiff = targetAngle - seg.startAngle
            angleDiff = (angleDiff + math.pi) % (2 * math.pi) - math.pi -- Normalize angle difference
            seg.angle = seg.startAngle + angleDiff * progress
        end
    end

    if player.respawnAnimProgress >= 1 then
        print("Respawn Animation Finished.")
        player.isRespawning = false
        player.visible = true
        player.alive = true
        invulnerableTimer = INVULNERABILITY_TIME -- Grant visual invulnerability
        player.deathSegments = nil -- Clear segments as ship is reformed
        print("Player respawned. Visual invulnerability granted.")
    end
end

-- Draw player
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

            -- Handle visual invulnerability blink (timer now only controls this)
            if invulnerableTimer > 0 then
                if math.floor(invulnerableTimer * 10) % 2 == 0 then -- Blink effect
                    love.graphics.pop()
                    goto continue_draw_loop -- Skip drawing this instance for blink
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

-- Getters and setters
function Player.getPosition() return player.x, player.y end
function Player.getAngle() return player.angle end
function Player.getVelocity() return player.dx, player.dy end
function Player.getRadius() return player.radius end
function Player.getShape() return player.shape end
function Player.isThrusting() return player.thrusting end

-- Player is fully alive and controllable
function Player.isFullyAlive()
    return player.alive and not player.isDying and not player.isRespawning
end

-- Player can be hit if alive and not in death/respawn animation.
-- MODIFIED: Removed 'invulnerableTimer <= 0' check.
-- The invulnerableTimer now ONLY controls the blinking visual.
function Player.canBeHit()
    return player.alive and not player.isDying and not player.isRespawning
end

function Player.setVisible(visible) player.visible = visible end
function Player.setAlive(alive) player.alive = alive end

-- Sets the visual invulnerability timer
function Player.setInvulnerable(invulnerable)
    if invulnerable then
        invulnerableTimer = INVULNERABILITY_TIME
        print("Player visual invulnerability set ON. Duration: " .. INVULNERABILITY_TIME)
    else
        invulnerableTimer = 0
        print("Player visual invulnerability set OFF.")
    end
end

function Player.getGunCooldown() return gunTimer end
function Player.setGunCooldown(time) gunTimer = time end -- Not typically set externally
function Player.resetGunCooldown() gunTimer = GUN_COOLDOWN end -- Called by Bullets.fire

return Player